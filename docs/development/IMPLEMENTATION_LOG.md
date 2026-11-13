# Bitácora de implementación

> Punto de reanudación entre sesiones. Entrada nueva **arriba**, al cerrar
> cada tarea: qué cambió, por qué, evidencia, tests añadidos, limitaciones y
> siguiente paso. El plan vigente es ITERATION_PLAN.md; el estado por tarea,
> PLANNING.md; las evidencias de CI, `../../PROGRESS.md`.

## Estado actual

- **`main`:** iteraciones 2, 3 y 4 fusionadas por el propietario (PR #1,
  `6bf7cd7`); IPA de esa versión: run 43327489818.
- **En rama `fix/naps-inside-sleep`:** BUG‑N01 y los arreglos de
  portabilidad de tests, **sin evidencia de tests** todavía.
- **Siguiente:** prueba local del propietario (`flutter analyze` y los
  archivos tocados); si sale en verde, fusión a `main` (genera IPA, ≈ 130 min
  facturados; presupuesto de Actions casi agotado hasta el 2026‑12‑01).
- **Iteración 5, go/no‑go (2026‑11‑12):**

  | Funcionalidad | Condición | Veredicto |
  |---|---|---|
  | Laboratorio de periodos | ALG‑T1 en `main` | **No‑go hoy**: ALG‑T1 está en rama, no en `main`. Go en cuanto se fusione |
  | N‑of‑1 | diario en uso | **No‑go**: `journal`, `journal_metric` y `journal_field_def` tienen 0 filas en la exportación del 2026‑11‑12 |
  | Registro de recomendaciones | P‑01 en `main` | **No‑go hoy** (P‑01 en rama) y además requiere tabla nueva: **preguntar al propietario** antes de la migración |
  | Informe semanal | P‑02 y P‑08 en `main` | **No‑go hoy** (P‑08 en rama) |
  | Validación frente a WHOOP | exportación oficial | **No‑go**: no hay ZIP |

  Con todo en ramas, la iteración 5 queda en este documento de go/no‑go, que
  el plan admite como resultado válido, hasta que haya fusión.
- **Abierto con el propietario:** "días anteriores sin esfuerzo" (ver
  DATA_ANALYSIS.md §8): falta pantalla y día.

## 2026-11-13 — BUG‑N01 y portabilidad de tests en Windows

- **Qué:** PROGRESS.md (misma fecha).
- **Por qué así (BUG‑N01):** el fallo no está en el detector sino en que
  nadie retira una propuesta que deja de ofrecerse. Un barrido en el único
  almacén (`ActivityStore`), después de escribir la fila del día, cubre las
  propuestas nuevas y las que ya están en el teléfono sin migración ni
  borrado: la fila pasa a `superseded`, no se elimina.
- **Autoría:** los commits salen con la identidad del propietario (la del
  merge del PR #1), sin autor ni coautor Claude. Los ya publicados no se
  reescriben (sin reset ni force‑push).
- **Limitaciones:** sin evidencia todavía (sin Flutter en la sesión); los
  fallos 1–9 de la suite local no estaban en el log recibido.

## 2026-11-12 — Iteración 4 (Home): escrita, sin validar

- **Qué:** PROGRESS.md (misma fecha) y UI_UX_AUDIT.md §9.
- **Por qué así:** al leer el código, P‑02, P‑04 y los rangos de P‑05 ya
  existían en buena parte; se añadió lo que faltaba en vez de duplicarlo.
- **Riesgos conocidos de escribir sin analizador:** avisos *info* de lints;
  la fila nueva al final de Home y la línea de frescura pueden empujar
  elementos fuera de la vista en tests existentes de pantallas largas
  (agrandar la vista del test, no borrarlo); `LucideIcons`/claves l10n mal
  escritas no compilarían.
- **Limitaciones:** la página "Cómo se calcula" es texto estático; el peso
  levantado va solo en kg; `HomeEvolution` no tiene test de widget propio
  (lee la base; su mitad pura `EvolutionCard` sí).

## 2026-11-12 — DATA‑02 fuera del hilo principal; iteración 3 (cálculo)

- **Qué:** ver PROGRESS.md (misma fecha). `pageDecodedRange` es el bucle de
  páginas de `_loadSubstrateRange` extraído sin cambios y compartido por la
  carga viva y la de archivo; `rehydratedSubstrateOf` corre entero en un
  isolate. `RehydratedSubstrate` (hilo de la base) solo trae bytes;
  `RehydratedRows` (worker) decodifica y sirve filas.
- **Por qué:** invariante 10; "Re‑analyze everything" no tiene tope de días.
- **Limitaciones:** cada día decodifica sus cubos en cada una de sus tres
  cargas de rango (marcado `ponytail:`); la lectura de filas vivas del cubo
  (`_readLivePages`) sigue en el hilo de la base, como en el archivado.
  Refactor de un *hotspot* validado con los goldens y 7 archivos, **no con la
  suite completa**.
- **D‑17:** el IC de la regla de "cambio relevante" es el de la diferencia,
  no el de la pendiente. Revisable.

## 2026-11-12 — Iteración 2: fundamentos

- **Qué:** DATA‑02 (re‑derivar desde `substrate_archive`), regla de "Ya estoy
  despierto" (doc + test), T‑02 (contrato de `payload_json`), `CLAUDE.md`
  alineado, entrada `tz` en `test-files.yml`.
- **Por qué:** sin DATA‑02 cada mejora de algoritmo solo llega a los ~5 días
  con crudo vivo.
- **Cómo quedó DATA‑02:** ALGORITHMS.md §7. Decisiones D‑13 y D‑14.
- **Evidencia:** runs 43255670024 (UTC), 43255676974 (Europe/Madrid, días de
  23 h y 25 h), suite completa 43260273913 + 43260295892. Detalle en
  PROGRESS.md.
- **Tests añadidos:** `archive_rederive_test.dart` (5 casos),
  `awake_tap_provenance_test.dart` (6), `payload_contract_test.dart` (3).
- **Revisión independiente** (subagente de solo lectura): sin P0. Cuatro P1
  corregidos antes de fusionar: (1) el resultado se juzga por la fila
  guardada, no por el booleano (una fila parcial se contaba como "sin
  ganancia"); (2) guarda de zona horaria (viaje pendiente y zona de cada cubo);
  (3) la comprobación de huecos cuenta los minutos como `worn_min`, al 5 %, y
  un día sin esos escalares conserva su versión; (4) con un wearable activo la
  pasada no se ejecuta. P2 corregido: blob desaparecido entre dos lecturas ⇒
  ilegible, no vacío.
- **Limitaciones abiertas (no corregidas, a propósito):**
  - [Hipótesis] Un hueco **dentro de la noche** menor que el tiempo despierto
    pasa la comprobación. Mejora: contrastar cada día UTC de la ventana con
    `device_coverage`. Marcado con `ponytail:`.
  - [Hipótesis] La construcción de páginas de filas desde el archivo ocurre
    en el hilo principal (decodificar y fusionar sí van en `Isolate.run`).
    ~10 s de lectura+preparación por día en el runner de CI; **sin medir en
    el iPhone**. Cada día vuelve a decodificar sus 2–3 cubos.
  - El backfill único `readiness_calibration_v112` puede sellar días
    archivados con una fila completa antes de que esta pasada llegue a ellos
    (solo en una base que venga de < v112).
  - El "esta noche" de un día usa la ventana guardada del día siguiente, aún
    de la versión anterior (orden antiguo→reciente).
  - Los tests usan `gen5`: la rama gen4 de `skin_temp_ambient_r` desde el
    archivo no está cubierta.
  - El test de "baselines como desde cero" compara con una derivación viva
    asentada de los mismos datos, no con una base nueva.
- **Siguiente paso:** iteración 3.

## 2026-11-12 — Iteración 1: auditoría contrastada y plan

- **Qué:** AUDIT_VERIFICATION.md (nuevo), ITERATION_PLAN.md (nuevo), este
  archivo; correcciones en ALGORITHMS.md, ALGORITHM_EVALUATION.md,
  AUDIT_SUMMARY.md, DATA_MODEL.md, DATA_QUALITY.md, DECISIONS.md (D‑05, D‑06,
  D‑09, D‑11 aceptadas; D‑12…D‑16 nuevas), IMPROVEMENT_BACKLOG.md,
  PLANNING.md, README.md, UI_UX_AUDIT.md. **Ningún archivo de código.**
- **Por qué:** la auditoría del 2026‑11‑12 se escribió sobre `kAlgoVersion
  120` y sin ejecutar nada; había que saber qué sigue siendo cierto antes de
  planificar.
- **Hallazgos que cambian el plan:** fases como rango y petición de RPE ya
  existen; `putDayResult` reescribe la misma versión; el contador
  `substrate_archive_failures` gobierna borrados; las tendencias, el CV de
  HRV, la consistencia de horario y el sRPE son fórmulas nuevas; ALG‑L1/C1 se
  fusionaron antes de que acabara la suite completa.
- **Evidencia:** símbolos y archivos citados en AUDIT_VERIFICATION.md;
  `gh run list` para el estado de CI. Sin tests nuevos (solo docs).
- **Limitaciones:** sin exportación de datos en la sesión; sin dispositivo;
  varias afirmaciones de UX quedan como [Hipótesis] hasta leer cada pantalla
  al abrir su tarea.
- **Rama:** `iter1/audit-contrast` (solo docs; no genera IPA).
