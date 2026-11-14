# Deuda técnica

> Fecha: 2026-11-12. Amplía TECHNICAL_AUDIT.md (F‑01…F‑05, 2026‑11‑09) con
> lo encontrado al cruzar código y datos reales. IDs estables; cada uno está en
> IMPROVEMENT_BACKLOG.md.

## 1. Decisiones técnicas acertadas que hay que conservar

| Decisión | Por qué es buena | Dónde |
|---|---|---|
| Separación protocol / analytics / edge | Cada capa testeable y versionable por SHA | AGENTS.md §1, `pubspec.yaml` |
| Commit antes de ACK | Imposible perder datos de la banda por un cierre | `ble_engine.dart` (invariante 1) |
| Derivado inmutable por `kAlgoVersion` | Auditoría y reproducibilidad | `day_result` |
| Política "nunca inventar" con notas legibles por máquina | Confianza y depuración | `Metric`, `need_baseline:` |
| Políticas puras extraídas (`ble_state.dart`, `sync_policy.dart`) | BLE testeable sin hardware | `lib/ble/`, `lib/sync/` |
| Cálculo pesado en `Isolate.run` | Sin ANR | `lib/compute/` |
| Sistema de diseño con tests de contraste, escala de texto y objetivos táctiles | Accesibilidad automática | `test/ui2_*` |
| Tests de regresión con nombre del bug | Memoria del proyecto | `test/readiness_*_test.dart` |
| Algoritmos documentados en la cabecera con su evidencia y lo descartado | Evita repetir errores | `openstrap_analytics` |
| Archivo comprimido del sustrato | Base para re‑derivar | `lib/data/substrate_archive.dart` |

## 2. Deuda detectada

| ID | Tipo | Descripción | Evidencia | Impacto | Esfuerzo |
|---|---|---|---|---|---|
| TD‑01 | Arquitectura | Archivos gigantes: `data/db.dart`, `compute/derivation_engine.dart`, `ble/ble_engine.dart`, `state/app_state.dart` (≈ 48 k líneas) concentran la mayoría de fixes | AGENTS.md §2, TECHNICAL_AUDIT | Riesgo de regresión | L — **no refactorizar en el fork** (conflictos con upstream) |
| TD‑02 | Datos | `samples` duplica `decoded_onehz.hr` (~20 % de la base) | DATABASE_AUDIT DB‑01 | Disco, tiempo de backup | S (upstream) |
| TD‑03 | Datos | `raw_archive_frames` sin poda para v26 | DB‑02 | Crecimiento ~0,4 MB/día | S |
| TD‑04 | Datos | Unidades de tiempo mezcladas s/ms | DB‑03 | Bugs en consultas manuales y en el coach | Documentar (hecho); no migrar |
| TD‑05 | Datos | `metric_method` con nombre engañoso | DB‑04 | Confusión | Documentar |
| TD‑06 | Datos | `payload_json` sin esquema declarado | DB‑05 | Contrato implícito entre pipeline y UI | M: test de contrato que congele las claves leídas por `local_repository_impl.dart` |
| TD‑07 | Algoritmo | Serie de TRIMP densa con 0 para días sin datos | Q‑05 | CTL/ATL engañosos | M (ALG‑L1) |
| TD‑08 | Algoritmo | Sin banda de asentamiento de temperatura para gen5 | Q‑02 | Temperatura nunca en readiness | M (ALG‑R3) |
| TD‑09 | Algoritmo | `glassBoxReadiness` deprecado pero aún calculado y guardado (`crossday.readiness_glassbox`) | `crossday_pipeline.dart` | Coste y confusión | S (upstream) |
| TD‑10 | Re‑derivación | `substrate_archive` solo escribe; ninguna ruta lo lee para derivar | `substrate_archive.dart` cabecera | Cambios de algoritmo no llegan al histórico | M (O‑01) |
| TD‑11 | Docs | `lib/ui2/README.md` dice "cuatro pestañas"; hay cinco | `app_shell.dart` | Menor | S |
| TD‑12 | Docs | Cabecera de `substrate.dart` describe un modelo de día que ya no existe | AGENTS.md cabecera | Menor | S |
| TD‑13 | Operación | Sin toolchain en la sesión de agente; tests solo en el PC del propietario | CLAUDE.md, PROGRESS.md | Ciclo de validación lento | Proceso (TESTING.md) |
| TD‑14 | Escalabilidad | 1 Hz ≈ 15 MB/día en vivo; el archivo indefinido ≈ 0,6 GB/año | `SubstrateArchivePolicy` | Disco del móvil | Aceptable; ofrecer exportar archivo |
| TD‑15 | Dependencias | `flutter pub outdated` y avisos de seguridad sin revisar | PLANNING AUD‑03 | Desconocido | S (en tu PC) |

## 3. Rendimiento

No medido en dispositivo en esta sesión. Señales estáticas:
- Payload por día completo 75–82 KB; la lectura de Home deserializa JSON
  grande en el hilo de UI si la pantalla lo pide entero. Revisar con el
  profiler antes de optimizar.
- Índices de `decoded_onehz` ≈ 9,4 MB para 4 días: proporcionales y razonables.

## 4. Errores potenciales (para revisar, no confirmados)

- Q‑06: `rhr_nocturnal` igual a `rhr` en todas las noches; si la intención era
  medirlo distinto, hay un cableado duplicado.
- `sessions.strain` vacío en la sesión con traza tras 2 días: confirmar que
  `strain_backfill.dart` la rellena cuando el nivel de reposo exista.
- ALG‑C2: RR en 333/2400 ms exactos.

## 5. Revisión de la iteración 6 (2026‑11‑13, estática, sin dispositivo ni profiler)

Alcance real: barridos por patrón de AGENTS §4 sobre `lib/` y lectura del
código del fork. **No** es una auditoría línea a línea de `app_state.dart`,
`ble_engine.dart` ni `db.dart`; lo no mirado se dice abajo.

**Barridos sin hallazgos [Comprobado con grep el 2026‑11‑13]:**
- `metricSeries(limit:)` (§4.2, "los N más antiguos"): ningún llamador.
- Llamadas directas a `NotificationService` fuera de `lib/notify/` (§4.6): ninguna.
- Etiquetas de día en UTC `toUtc()…substring(0,10)` (invariante 7): ninguna.

**Hallazgos:**

| # | Qué | Causa | Propuesta | Impacto estimado | Riesgo | Estado |
|---|---|---|---|---|---|---|
| R6‑1 | La tarjeta "Cómo evolucionas" no se actualizaba tras una noche nueva | Leía solo en `initState`; Home vive en un `IndexedStack` | `RevisionReload` con token de lectura | Corrección, no velocidad | Bajo | **Hecho** |
| R6‑2 | `TrendService.of` lee la serie entera de `metric_series` antes de mirar la caché | La clave de caché necesita la última fecha de la serie | Leer solo `MAX(date)` para la clave y la serie (≤ 125 días) al fallar la caché | [Hipótesis] irrelevante hoy (1 fila/día); medible con años de historia | Bajo | Pendiente, sin evidencia de que haga falta |
| R6‑3 | El barrido de siestas lee hasta 3 `payload_json` (75–82 KB) por siesta pendiente, en el isolate principal, en cada derivación | Reutiliza `overlapsMainSleep` (una sola definición del solape) | Leer las ventanas de sueño de la semana una vez | [Hipótesis] nulo con 0–3 pendientes; marcado `ponytail:` | Bajo | Pendiente |
| R6‑4 | Cinco pestañas vivas releen en cada derivación | `IndexedStack` + `RevisionReload` (marcador `ponytail:` de upstream) | Releer solo la pestaña visible | [Hipótesis] menos consultas tras cada sync; **a medir por el propietario** | Medio (pantallas obsoletas si se hace mal) | Pendiente; es código de upstream |
| R6‑5 | `getToday` deserializa el payload completo en el hilo de UI (§3 de este documento) | Diseño del read seam | Medir con el profiler antes de tocar | Desconocido | Alto (zona caliente, 17 fixes) | Sin tocar |
| R6‑6 | Home crece: 2 puertas más al final (laboratorio, informe) | Iteración 5 | Agrupar las 4 puertas en una sola fila "Más" si la pantalla se alarga | UX | Bajo | A decidir por el propietario |

**No revisado (y por tanto sin opinión):** reconexión y escaneo BLE, latches
booleanos sin `finally` (§4.3) más allá de los ya documentados, uso de
`context` tras `await` (§4.5) fuera del código del fork, listas y gráficos
largos, consumo de batería. Todo ello pide dispositivo o una lectura dedicada.

**Seguridad:** SEC‑01…SEC‑09 de SECURITY.md sin cambios. El informe semanal
añade una salida de datos nueva, solo manual (D‑21); no amplía lo que el
coach envía fuera. **Accesibilidad:** las pantallas nuevas usan `Surface`,
`SubTabs`, `BigButton` y `detailLinkRow` (ya cubiertos por los barridos de
la galería); `PeriodLabScreen` y `WeeklyReportScreen` no están en la galería
y no pasan por el barrido de desbordamiento a 3,1×.

## 6. AUD-02 — barrido de los archivos calientes (2026‑11‑14, sobre la fusión con upstream)

Dos revisiones de solo lectura, sin compilar: `app_state.dart` + `ble_engine.dart`
(+ `sync_controller`, puerta headless) y `db.dart` + `derivation_engine.dart`
(+ capa de lectura). **Sin P0 ni P1.** Comprobado y correcto: commit antes del
ACK, INSERT‑OR‑REPLACE de 1 Hz con sus latidos, poda que respeta días sin
finalizar, migraciones aditivas, serialización headless, opcodes peligrosos,
flags limpiados en `finally`, etiquetas de día locales, cómputo fuera del hilo
de UI. Hallazgos menores:

| # | Qué | Estado |
|---|---|---|
| A2‑1 | `cycle_count` servido como `0` cuando la noche no trae cuenta (§4.1) | **Arreglado** en `fix/aud-02` (null ⇒ "—") |
| A2‑2 | La cuenta "faltan N noches" de la temperatura de piel cuenta días importados o de otra familia que la línea base excluye | Documentado: igualarla exige recorrer los bundles al leer; no afecta a una sola banda gen5 sin importaciones |
| A2‑3 | `total: dayTotal ?? 0` en el detalle de pasos | Documentado: sin camino alcanzable hoy |
| A2‑4 | gen4: un HISTORY_END con déficit de paquetes se confirma (aviso, no puerta) | Concesión deliberada de upstream para gen4; no aplica a la banda del propietario (gen5) |
| A2‑5 | Puerta headless: el techo de 15 min libera la puerta sin parar el motor huérfano | Plausible, sin confirmar; candidato a issue de upstream |
| A2‑6 | Tras sustituir la banda no se entrega un "buzz" de Tasker pendiente (Android) | Confirmado, solo Android; no aplica al propietario |
| A2‑7 | Evento de alarma con `clockRef` nulo usa deriva 0 | Plausible; ventana pequeña (SET_CLOCK precede a INIT). **Pista para BUG‑186** si la alarma vuelve a fallar |

