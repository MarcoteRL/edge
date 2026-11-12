# Plan de iteraciones 2–6

> Fecha: 2026-11-12 · base `main` @ `cb3bbbeb` · `kAlgoVersion 121` ·
> `schemaVersion 58`. Estado: **pendiente de aprobación del propietario**.
> Se apoya en AUDIT_VERIFICATION.md (qué se comprobó) y en
> IMPROVEMENT_BACKLOG.md (especificación de cada ID). Etiquetas:
> **[Comprobado]** · **[Hipótesis]** · **[Recomendación]** · **[Decidido]**.

## 0. Antes de empezar: tres decisiones tuyas

| # | Decisión | Recomendación | Bloquea |
|---|---|---|---|
| Q1 | Fórmulas nuevas de la iteración 3 (ALG‑T1, ALG‑H1, ALG‑S3, ALG‑L2): ¿módulos del fork en `edge` calculados al leer, o repo `MarcoteRL/analytics`? (AUDIT_VERIFICATION §3.2) | En `edge`, al leer, sin persistir; analytics solo cuando una esté validada con ≥ 60 noches | Iteración 3 |
| Q2 | Fallos de re‑derivación: ¿clave propia `archive_rederive_failures` en vez del contador `substrate_archive_failures`? (§3.1) | Clave propia: la existente decide borrados de crudo | DATA‑02, criterio 5 |
| Q3 | ¿Alineo `CLAUDE.md` con CI_RUNBOOK y con el flujo de ramas/commits? (§2.9) | Sí, en el primer commit de la iteración 2 | Nada; evita instrucciones contradictorias |

Y una acción tuya sin código, hoy: **Ajustes → Tus datos → archivo de
sustrato → "Para siempre"** (DATA‑01). El defecto es 90 días y lo que salga
del archivo no se podrá re‑derivar nunca.

## 1. Reglas de ejecución comunes

- Una tarea = una rama `iterN/<id>-<slug>`; commits pequeños; un merge a
  `main` por iteración (por funcionalidad en la 5) para generar un solo IPA.
- Por tarea: `test-files.yml` con los tests afectados y `analyze=true`. Antes
  del merge: suite completa. **[Comprobado]** el job tiene `timeout-minutes:
  90` y la suite ronda 80–90 min: se lanza **partida en dos runs** (mitades
  de `git ls-files 'test/**_test.dart'`) para no perder un run por el límite.
- Coste orientativo por iteración: 3–6 runs parciales (5–10 min de Linux), una
  suite completa (2 × ~45 min de Linux) y un IPA (~25 min de Mac × 10).
- Antes de cada push: comprobación local de las trampas (`grep` de
  `fontSize:`, `Color(0x`, `Duration(`, `BorderRadius.circular` fuera de
  `theme.dart`; claves nuevas en los 8 ARB con `@clave` en `ru`; widgets
  públicos en `gallery.dart`).
- Revisión independiente (subagente de solo lectura) en todo cambio que toque
  `db.dart`, `derivation_engine.dart`, `ble_engine.dart`, `app_state.dart`,
  `local_repository_impl.dart` o un invariante de AGENTS §3.
- Al cerrar cada tarea: PROGRESS.md (id del run), PLANNING.md,
  IMPLEMENTATION_LOG.md y los docs del área.

## 2. Iteración 2 — Fundamentos

Salida: rama en verde, un merge, un IPA. Sin migración de esquema, sin cambio
de pins y **sin subir `kAlgoVersion`** (ninguna salida de un día cambia; solo
cambia qué días pueden recalcularse).

### 2.1 DATA‑02 · Re‑derivar desde `substrate_archive`

**Repo y archivos.** edge.
`lib/data/substrate_archive.dart` (lectura por rango, solo memoria) ·
`lib/data/db.dart` (envoltorio `LocalDb` y cursor; *hotspot*) ·
`lib/compute/derivation_engine.dart` (`_loadSubstrateRange` acepta una fuente
de páginas de archivo; selección de días archivados; *hotspot*) ·
`lib/state/app_state.dart` (enganche en `reanalyzeAll`; *hotspot*, cambio
mínimo) · `lib/ui2/profile/data.dart` (texto de progreso con la grammar que
ya hay).

**Diseño [Recomendación].**
1. `SubstrateArchive.readRange(ex, fromRecTs, toRecTs)` → filas con la misma
   forma que `decodedOneHzBatchByRecTsRange` / `decodedRrByRecTsRange`
   (`ts_ms`, `device_id`, valores, `beat_index`), decodificando cada cubo
   `(device_id, utc_day)` que corte el rango con `SubstrateArchiveCodec.decode`
   en `Isolate.run`. Nunca escribe.
2. `_loadSubstrateRange` recibe esas filas como páginas adicionales para los
   segundos **por debajo** del cursor `decoded_pruned_before`; por encima solo
   lee el vivo. Si un mismo `(device_id, ts_ms)` está en los dos, **gana el
   vivo** (se descarta la fila archivada antes de enviarla al worker). El
   filtro de propiedad (`ownership`) se aplica igual.
3. Selección: días con `day_result` de versión < `kAlgoVersion`, sin fila de
   `kAlgoVersion`, sin crudo vivo, y cuyo archivo cubre la ventana completa
   `[medianoche local − kNocturnalSearchLookbackSec, medianoche local
   siguiente)` (límites por `day_label.dart`, sin asumir 86 400 s). Orden:
   del más antiguo al más reciente.
4. Escritura: la de siempre (`putDayResult`) pero con una guarda nueva en esta
   ruta: si ya existe `(day_id, kAlgoVersion)` no se escribe
   (AUDIT_VERIFICATION §2.2). Las guardas existentes (`windowTruncatedByPrune`,
   "never write nothing over something") no se relajan.
5. Ejecución: lotes de N días (N pequeño y constante), cursor reanudable en
   `compute_freshness` (`archive_rederive_v<kAlgoVersion>`: último día hecho +
   lista de fallidos); cede entre días si hay drain BLE o si
   `HeadlessSyncGate` está ocupado; solo se lanza en primer plano, desde el
   derive `heavy` posterior a un cambio de versión y desde "Re‑analyze
   everything". Flags con `try/finally` (AGENTS §4.3).
6. Fallos: cubo ausente o ilegible ⇒ el día conserva su versión, se apunta
   (Q2) y no se reintenta más de 3 veces. Log local de tiempo por día
   (ms de lectura+decodificación, ms de derivación, filas) para que lo midas.

**Invariantes afectados.** 2 (no se reinserta en `decoded_*`), 3, 4 (sin
bump: se justifica en el changelog como "sin cambio de salida"), 7, 8 (el
archivo se convierte en una segunda *fuente de filas* del único punto de
decodificación, no en un segundo decodificador), 9, 10, 12. AGENTS §4.2
(idempotencia y baselines) y §4.7 (todas las rutas de carga).

**Tests nuevos** (sintéticos, `test/archive_rederive_*_test.dart`):

| Criterio tuyo | Test |
|---|---|
| 1 Ida y vuelta exacta (T‑05) | derivar vivo → archivar y podar → re‑derivar: `payload_json` y `metric_series` idénticos byte a byte. Casos: día normal con RR; día con huecos; día local que cruza dos `utc_day` (Europe/Madrid); cambio de hora de 23 h y de 25 h; `device_id ''` junto a otro dispositivo |
| 2 Decodificación fiel | `readRange` devuelve exactamente las filas originales de `decoded_onehz` y `decoded_rr` (incluido `beat_index`) |
| 3 Solo lectura | tras re‑derivar, `COUNT(*)` de `decoded_onehz`/`decoded_rr` no cambia; día con filas vivas **y** archivadas: gana el vivo y no se duplica ningún segundo |
| 4 Inmutabilidad e idempotencia | no se toca ninguna fila de versión anterior ni una existente de `kAlgoVersion`; dos ejecuciones ⇒ mismas filas en `day_result`, `metric_series`, `baselines`; orden antiguo→reciente; re‑derivar el pasado con la misma versión no cambia el readiness de hoy |
| 5 Fallos honestos | cubo ausente / blob corrupto ⇒ versión anterior intacta, fallo contado, sin bucle |
| 6 Ejecución segura | reanudación desde el cursor tras interrumpir; cede cuando el *gate* está tomado; flag liberado en la ruta de error |

Más los existentes que deben seguir en verde: `substrate_archive_db_test`,
`substrate_archive_codec_test`, `substrate_archive_window_test`,
`reanalyze_outcome_test`, `whoop_freeze_golden_test` (sin diff),
`readiness_*_test`.

**Cambia `kAlgoVersion`:** no. **Migración:** no.
**Aceptación:** tus 7 criterios, cada uno con su test y su run.
**Evidencia de cierre:** ids de run en PROGRESS.md; informe del revisor
independiente en IMPLEMENTATION_LOG.md; DATA_MODEL.md y ALGORITHMS.md §7
actualizados; tiempos y memoria marcados [Hipótesis] hasta tu medición.

**Riesgo principal [Hipótesis].** Los cubos son por día UTC y la ventana de un
día local abarca hasta tres; con archivo empezado tarde, los primeros días
tendrán la víspera incompleta y se quedarán en su versión. Es el
comportamiento correcto, pero el número de días realmente recuperables puede
ser menor del esperado. Se informa el recuento, no se fuerza.

### 2.2 Regla de "Ya estoy despierto"

- **Archivos:** `docs/development/ALGORITHMS.md` §4;
  `test/awake_tap_provenance_test.dart` (nuevo). Sin código de producción.
- **Invariantes:** ninguno. **`kAlgoVersion`:** no.
- **Test:** pulsación real (`markAwakeNow`) ⇒ cumple `source='manual'` y
  `|created_at − offset_ts| ≤ 60`; edición con final en el pasado ⇒ no la
  cumple; y los dos límites de AUDIT_VERIFICATION §2.6 fijados como tales
  (edición posterior pisa la pulsación; edición con final en el minuto en
  curso es indistinguible).
- **Aceptación:** regla y límites escritos; test en verde. **Evidencia:** run.

### 2.3 T‑02 · Contrato de `payload_json`

- **Archivos:** `test/payload_contract_test.dart` y
  `test/fixtures/payload_contract_v<kAlgoVersion>.json` (nuevos).
- **Diseño [Recomendación]:** el fixture lista, para cada ruta de clave que
  lee `local_repository_impl.dart`, su tipo y si admite null. El test (a)
  comprueba el fixture contra los payloads de los *freeze goldens* de WHOOP
  (`test/fixtures/whoop_freeze/`), que ya fijan la salida real del pipeline, y
  (b) falla si el nombre del fixture no coincide con `kAlgoVersion`. Así un
  cambio de forma sin subida de versión rompe por (a) y una subida sin revisar
  el contrato rompe por (b).
- **[Hipótesis]:** la lista de claves leídas se extrae a mano del read seam
  (unas 180 claves distintas entre corchetes); una ruta leída por nombre
  dinámico puede escaparse. Se documenta cómo se generó.
- **Invariantes:** 4. **`kAlgoVersion`:** no. **Evidencia:** run.

## 3. Iteración 3 — Inteligencia (depende de Q1)

Con la opción recomendada de Q1: funciones puras en `lib/compute/fork/`,
calculadas al leer, **sin** `day_result`, **sin** bump y sin tocar goldens.
Ninguna se valida con datos reales todavía: sintéticos y tests.

| Tarea | Archivos | Invariantes | Tests | Bump | Aceptación | Evidencia |
|---|---|---|---|---|---|---|
| **ALG‑T1** tendencias 7/14/30/90 | `lib/compute/fork/trends.dart` (nuevo; usa `ana.theilSen`, `ana.robustBaseline`, `ana.mdc`); lectura en `local_repository_impl.dart` vía `trailingSeriesValues` | 3, 10 (bootstrap en `Isolate.run`), §4.2 (ventana final, nunca `metricSeries(limit:)`) | escalón, rampa, ruido blanco, huecos, cambio de hora, duplicados; semilla fija | No | "Cambio relevante" solo si \|Δ\| > max(MDC, SWC) **y** el IC excluye 0; n mínimo declarado por ventana y variable; FP en ruido blanco < 5 % medido en el test; abstiene con nota bajo n | run + sección en ALGORITHM_EVALUATION.md |
| **ALG‑H1** CV de lnRMSSD 7 d + banda personal | mismo módulo | 3 | constante, ruido, huecos (< 5 de 7 noches ⇒ null) | No | fórmula `SD/media` de lnRMSSD de las noches válidas; solo noches del mismo método (`metric_method`) | run |
| **ALG‑R1** validar FP‑CAL | `docs/development/analysis/fpcal_agreement.py` (nuevo, `?mode=ro`) | privacidad (solo agregados) | prueba con base sintética generada | No | Spearman, MAE y % en la misma banda para noches ≥ 15; con < 15 noches sale "sin datos suficientes" | salida del script sobre la base sintética; **ejecución real pendiente de tu exportación con ≥ 15 noches** |
| **ALG‑L2** sRPE + tonelaje por grupo | `lib/data/strength_summary.dart` (ya agrupa por músculo); lectura de `sessions.rpe` | 3 (sin RPE ⇒ null, nunca un RPE por defecto) | sin RPE; suma semanal; sesión sin series | No | carga muscular **separada** del strain; el RPE ya se pide (`summary.dart`): primero comprobar si las sesiones de Hevy pueden recibirlo | run |
| **ALG‑L3** Edwards / distribución por zonas | lectura de `zone_min_json` | 3 | zonas ausentes ⇒ null | No | solo presentación | run |
| **ALG‑S2** fases como rango | — | — | — | No | **[Comprobado] ya existe** (`sleep_detail.dart`). Queda revisar jerarquía y etiqueta en P‑05 | nota en UI_UX_AUDIT.md |
| **ALG‑S3** consistencia de horario 7 d | `lib/compute/fork/trends.dart` | 3, 7 (hora local de la noche vivida) | < 5 noches ⇒ null; cambio de hora | No | SD circular de acostarse/despertar | run |
| **ALG‑S1** error del final automático | `docs/development/analysis/awake_tap_error.py` | privacidad | base sintética | No | usa la regla de 2.2; informa n | **pendiente de exportación** |
| Noche "sin alarma" | campo de diario en `journal_fields.dart` + `_isFreeDay` | — | — | **Sí** (cambia `sleep_debt`) | **Fuera de esta iteración salvo que lo pidas**: cambia una salida y hoy no hay noches etiquetadas | — |

Pendientes que **no** entran y por qué: `ctlAtlTsb` con nulos (fórmula en
analytics, Q1‑B); ALG‑R3 temperatura gen5 (analytics + ≥ 30 noches); ALG‑R2
(≥ 60 noches); ML (≥ 90 noches).

## 4. Iteración 4 — UX

Cada pantalla tocada lleva tests de widget a 1,0× y 3,1×, con estado vacío,
calibrando y con datos, más contraste y objetivos táctiles (los barridos
`ui2_component_sweep_test`, `ui2_contrast_test`, `ui2_tokens_test` ya lo
exigen para todo componente de la galería). Sin bump: solo lectura.

| Tarea | Archivos | Tests | Aceptación |
|---|---|---|---|
| **P‑04** progreso de calibración | `grammar.dart` (`CalibrationProgress`), `home_screen.dart`, galería, ARB | hoja con 0/14, 5/14, completo | una barra por métrica leída de las notas `need_baseline:have=H,need=N`; explica que el gris parte de una referencia general; desaparece al completarse |
| **P‑02** banda + MDC | `health_screen.dart` (`usualRangeFor` ya dibuja el rango), constantes de Home | dentro de banda, fuera sin superar MDC, fuera superándolo, < 14 días | color solo si sale de la banda **y** supera el MDC; si no, tinta neutra |
| **P‑01** línea de decisión | `grammar.dart` (`DecisionLine`), `home_screen.dart` | payload completo, sin readiness, sin sueño, calibrando | determinista, sin IA; calibrando ⇒ sin recomendación de intensidad; cada frase cita su *driver* |
| **P‑05** jerarquía de sueño | `sleep_detail.dart`, `sleep_tab.dart` | orden de secciones; etiqueta "estimación de muñeca" | duración → horario → deuda → fases; el rango ya existe |
| **P‑07** Workout por carga | `workout_screen.dart` | sin sesiones, solo fuerza, solo cardio | carga cardiovascular y muscular separadas arriba (depende de ALG‑L2) |
| **P‑08** frescura en todas las pestañas | extraer `_syncLine` a un widget de `grammar.dart`; `app_shell.dart` | sincronizando, al día, sin datos desde ayer | mismo texto y fuente que Home en las cinco pestañas |
| **Ficha "Cómo se calcula"** | hoja en `grammar.dart`; contenido desde `algo_version`, notas `need_baseline`, notas de `day_result` | métrica medida, derivada, estimada | tipo, unidad, entradas, ventana, versión, ausentes/atípicos, suficiencia de hoy, límites. **Sin migración** |
| **P‑03** evolución 30 d en Home | `home_screen.dart`, `trend.dart` | estable, cambio relevante, < n | depende de ALG‑T1; texto solo cuando hay cambio relevante |

Riesgo de la iteración **[Comprobado]**: `home_screen.dart` y los ARB son
donde más runs se han perdido (listas largas, cobertura `es`/`ru`/`th`). Se
agrupan los cambios de ARB en un commit por tarea.

## 5. Iteración 5 — Diferenciales

Una rama y un merge por funcionalidad, con go/no‑go previo en
IMPLEMENTATION_LOG.md. Previsión con lo que se sabe hoy:

| Funcionalidad | Condición previa | Previsión |
|---|---|---|
| Laboratorio de periodos | ALG‑T1 en `main` | Go probable; con pocas noches casi todo dirá "sin cambio relevante", que es lo correcto |
| N‑of‑1 | diario en uso + n mínimo por métrica | **[Hipótesis] No‑go** si el diario sigue vacío: se documenta |
| Registro de recomendaciones | P‑01 en `main` | Go; **requiere tabla nueva ⇒ te pregunto antes** (migración aditiva + `schemaVersion`) |
| Informe semanal | P‑02 y P‑08 en `main` | Go; archivo local compartible, sin red |
| Validación frente a WHOOP | exportación oficial | No‑go sin el ZIP |

## 6. Iteración 6 — Pulido

Revisión de código (sin dispositivo) de: bloqueos del hilo principal,
consultas SQLite repetidas, recálculos completos, reconexión/escaneo BLE,
listas y gráficos. Por hallazgo: causa, propuesta, impacto estimado, riesgo.
Seguridad: SEC‑* de SECURITY.md. Accesibilidad: lo que los barridos no cubren.
Toda mejora de velocidad o batería queda **[Hipótesis]** hasta tu medición.
Cierra con `FINAL_PRODUCT_REPORT.md`.

## 7. Dónde me pararé a preguntarte

Además de Q1–Q3: tabla `recommendation_log` (iteración 5); cualquier cambio de
pin; cualquier subida de `kAlgoVersion` no prevista aquí; ampliar lo que el
coach envía; y si la suite completa muestra fallos que no sean de mi cambio.
