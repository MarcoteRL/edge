# Contraste de la auditoría con el código (iteración 1)

> Fecha: 2026-11-12 · `main` @ `cb3bbbeb` · `kAlgoVersion 121` ·
> `schemaVersion 58` · analytics `3a7ca34d` · protocol `b4fde6ab` (leídos de
> `derivation_engine.dart`, `db.dart` y `pubspec.lock`, no de los docs).
> Método: lectura de código de `edge` y de `openstrap_analytics` en su pin,
> y `gh` para el estado de CI. **No se ejecutó ningún test nuevo ni se usó
> ninguna exportación** (no se adjuntó ninguna en esta sesión).
>
> Etiquetas: **[Comprobado]** (archivo o símbolo citado) · **[Hipótesis]** ·
> **[Recomendación]** · **[Decidido]**.

## 1. Lo que la auditoría decía y sigue siendo cierto

| Afirmación | Evidencia |
|---|---|
| `substrate_archive` solo se escribe; nada deriva desde él | **[Comprobado]** cabecera de `lib/data/substrate_archive.dart` ("WRITE SIDE ONLY, FOR NOW"); sus lectores (`readBlob`, `restoreRows`, `copyArchiveInto`, `stats`) son backup/restauración/estadística. `_loadSubstrateRange` (`derivation_engine.dart`) solo pagina `decoded_onehz`/`decoded_rr` |
| Un cubo por `(device_id, utc_day)`, `utc_day = rec_ts ~/ 86400` | **[Comprobado]** misma cabecera. El códec ya sabe decodificar (`SubstrateArchiveCodec.decode`) y hace verificación de ida y vuelta antes de borrar (`encodeMergeVerify`) |
| ALG‑L1 y ALG‑C1 están en el código | **[Comprobado]** `_loadWithCoverage` (`crossday_pipeline.dart`), `irregularRhythmFlag` (`onehz_pipeline.dart`), changelog 121 |
| "Ya estoy despierto" guarda `source='manual'` con `offset_ts` ≈ `created_at` | **[Comprobado]** `AppState.markAwakeNow` → `setSleepOverride(day, onset, now)` → `LocalDb.putSleepOverride` (`created_at = now`). Ver el matiz en §2.6 |
| `ctlAtlTsb` solo acepta `List<double>` | **[Comprobado]** `analytics:clinical/load_trimp.dart`. La serie con nulos sigue siendo una fórmula nueva en analytics |
| `theilSen`, `robustBaseline`, `mdc`, `benjaminiHochberg`, `weekdayEffect`, `illnessCusum`, `multivariateAnomaly`, `journalNumericCorrelations`, `readinessLnRmssd` existen en analytics | **[Comprobado]** `util.dart`, `foundations/baseline.dart`, `human/`, `clinical/`, `wellness/` |
| `sessions.rpe` existe | **[Comprobado]** `db.dart` (`_addColumnIfMissing(... 'rpe' ...)`, `setSessionRpe`) |
| `_isFreeDay` usa sábado/domingo | **[Comprobado]** `crossday_pipeline.dart` |
| El indicador de frescura solo existe en Home | **[Comprobado]** `_syncLine` es privado de `home_screen.dart` |
| `test-files.yml` acepta `files` y `analyze`; `ios-sideload.yml` ignora pushes solo de `.md`/`docs/` y cancela el build anterior | **[Comprobado]** los dos workflows |

## 2. Lo que la auditoría decía y el código contradice o matiza

### 2.1 La suite completa no había terminado cuando se fusionó ALG‑L1/ALG‑C1
**[Comprobado]** `gh run list`: el run **43233915353** (suite completa en
`audit/2026-11-12`) seguía `in_progress` a 1 h 21 min cuando `main` ya estaba
en `cb3bbbeb` con esos cambios. PROGRESS.md decía "result in the next entry" y
esa entrada no existe; PLANNING.md los daba por "done on branch". Los runs
parciales 43231936403 y 43232851823 sí cubren los tests afectados y los
goldens. **Consecuencia:** el estado correcto es "en `main`, suite completa
pendiente de resultado". Se apunta el resultado en PROGRESS.md en cuanto acabe
(tiene un límite de 90 min; si lo agota, hay que partirla en dos runs).

### 2.2 `day_result` no es inmutable frente a una re‑derivación de la misma versión
**[Comprobado]** `LocalDb.putDayResult` inserta en `day_result`,
`metric_series`, `metric_method` y `metric_series_version` con
`ConflictAlgorithm.replace`. "Inmutable por versión" significa que una versión
nueva no pisa a la anterior; **la misma versión sí se reescribe** (así
funciona el re‑análisis y el día en curso). El propio motor lo sabe: el bloque
"NEVER WRITE NOTHING OVER SOMETHING" de `_derivePreparedDay` existe porque un
re‑análisis de un día sin crudo pisaba un resultado bueno con uno vacío.
**Consecuencia para DATA‑02:** el criterio "nunca sobrescribe una versión
existente" hay que **imponerlo en la ruta de archivo** (saltar el día si ya
hay fila de `kAlgoVersion`); el esquema no lo garantiza.

### 2.3 Las fases de sueño ya se muestran como rango
**[Comprobado]** `sleep_detail.dart`: `_ranges(n)`, `_rangeText(ana.StageInterval)`
y el texto `sleepDetailStageRangeExplain` (traducido en los 8 ARB); analytics
expone `stageRanges` en `sleep/segment.dart`. La auditoría proponía crearlo
(ALG‑S2, P‑05) y citaba columnas `light_range_sec`/`deep_range_sec`/
`rem_range_sec` en `sleep_session_candidates`: **esas columnas no existen**
(la tabla es `day_id, algo_version, payload_json, computed_at`).
**Consecuencia:** ALG‑S2 queda reducida a comprobar la jerarquía de la
pantalla (duración → horario → deuda → fases) y la etiqueta "estimación de
muñeca"; no hay componente `StageRangeBar` que construir sin antes ver qué
falta.

### 2.4 El RPE ya se pide al cerrar una sesión
**[Comprobado]** `ui2/activity/summary.dart` (`_rpeDismissed`,
`LocalDb.setSessionRpe`, fila "Your rating … of 10"). Lo que falta de ALG‑L2
es **usar** ese RPE (sRPE semanal) y el tonelaje, y comprobar si las sesiones
importadas de Hevy pasan por esa pantalla. **[Hipótesis]** las de Hevy no
tienen forma de recibir RPE hoy; hay que mirarlo en `hevy_import.dart` y en el
detalle de sesión antes de diseñar.

### 2.5 "Piezas implementadas sin producto" está exagerado
**[Comprobado]** por búsqueda de símbolos en `lib/ui2`, `lib/notify` y el read
seam:

| Pieza | ¿Tiene producto? |
|---|---|
| CUSUM de enfermedad | Sí: `health_screen`, `home_screen`, `rough_night`, notificación |
| Mahalanobis (`anomaly`) | Parcial: notificación y read seam; sin pantalla propia |
| MDC | Sí en el detalle de readiness (`past_mdc`, `mdc_multiples` en `readiness_detail`, `driver_breakdown`); no en Home ni en las tendencias de Health |
| `weekdayEffect` | Sí: `wellness_screen` vía `getWeekdayEffect` |
| `session_cost` | Sí: `workout_screen` |
| Correlaciones con permutaciones | Sí: read seam (`journalNumericCorrelations`) |
| `theilSen` | Solo en `notify/battery_forecast.dart`; **ninguna tendencia de métricas lo usa** |
| `percentileOfYou`, `readinessLnRmssd` | Calculados en el pipeline; **[Hipótesis]** sin superficie clara, por comprobar en la iteración 4 |

**Consecuencia:** lo que de verdad no tiene producto es la **tendencia con
significancia** (ALG‑T1) y el **MDC fuera del detalle de readiness** (P‑02).
El resto es integrar, no exponer.

### 2.6 La regla de "Ya estoy despierto" tiene dos límites
**[Comprobado]** `sleep_override` se escribe con REPLACE por `day_id`:
1. Una **edición posterior pisa la pulsación** (fila y `created_at`). La
   etiqueta de despertar de esa noche se pierde; la regla solo clasifica la
   fila que queda.
2. `created_at` se toma **después** de `await _requireSleepSubstrate(...)`,
   así que |Δ| es pequeño pero no cero, y una edición manual cuyo final
   coincida con el minuto en curso también cumple `|Δ| ≤ 60`.
   **[Hipótesis]** poco frecuente; el test de la iteración 2 debe fijar ambos
   casos como límites documentados, no esconderlos.

**[Recomendación]** mantener la decisión (sin cambiar `source`), documentar
los dos límites en ALGORITHMS.md y contar en ALG‑S1 solo noches cuya fila
cumple la regla.

### 2.7 P‑02 ya existe a medias en Health
**[Comprobado]** `health_screen.dart` `_trends`: `usualRangeFor(...)` dibuja el
rango habitual y abstiene con menos de `kUsualMinDays` ("no band, no arrow").
La auditoría lo describía como "flechas sin banda". Falta la puerta del MDC y
llevar la misma lectura a las constantes de Home. **[Hipótesis]** el alcance
exacto se fija leyendo `usualRangeFor` al empezar P‑02.

### 2.8 Docs que quedaron atrás del código
**[Comprobado]** y corregido en esta iteración:

| Doc | Decía | Es |
|---|---|---|
| ALGORITHMS.md cabecera y §3.6 | `kAlgoVersion 120`; serie densa con ceros | 121; `_loadWithCoverage` abstiene sin cobertura |
| ALGORITHMS.md §1 ritmo irregular | bandera diurna sola | exige cribado nocturno coincidente |
| DATA_QUALITY.md §2 | CTL/ATL "se calcula" | abstiene desde 121 |
| IMPROVEMENT_BACKLOG.md | ALG‑L1/C1 "pendiente de tests"; ALG‑S2 y ALG‑L2 como trabajo nuevo | ver §2.1, §2.3, §2.4 |
| ALGORITHM_EVALUATION.md ALG‑S2, UI_UX_AUDIT.md P‑05, DATA_MODEL.md | columnas `*_range_sec` | no existen; el rango sale de `stageRanges` |
| DECISIONS.md | D‑05, D‑06, D‑09, D‑11 "Propuesta" | decididas por el propietario |
| PLANNING.md | ALG‑L1/C1 "done on branch" | en `main`; suite completa pendiente |
| README.md (índice) | "última auditoría … 120" | se añade el puntero a este documento |

Las cifras de la exportación (v120, 3 noches) en DATABASE_AUDIT.md,
DATA_ANALYSIS.md y DATA_DICTIONARY.md **no se tocan**: describen esa
exportación tal como era.

### 2.9 `CLAUDE.md` se contradice con CI_RUNBOOK.md
**[Comprobado]** `CLAUDE.md` dice a la vez "sigue CI_RUNBOOK.md" y "tests run
locally on the owner's PC", y "No commits, pushes … unless asked". El prompt
maestro pide ramas, commits y `test-files.yml`. **[Recomendación]** alinear
`CLAUDE.md` (es un archivo del fork) en la iteración 2; no se ha editado ahora
porque es el archivo de instrucciones y el cambio debe ser tuyo o aprobado.

## 3. Supuestos de la misión que el código no sostiene tal cual

Son los puntos donde, según tu regla, toca documentar y preguntar.

### 3.1 El contador `substrate_archive_failures` no sirve para fallos de lectura
**[Comprobado]** `SubstrateArchive.failuresKey` cuenta, por `device|utc_day`,
pasadas de **escritura** fallidas de un cubo ya fuera de la retención; al
llegar a `maxFailedPasses` (3) el fallo se trata como permanente y el cubo se
**borra del vivo sin archivar** (`archiveAndDeleteBefore`). Si la
re‑derivación sumara ahí sus fallos de lectura, un archivo ilegible podría
acelerar el borrado de crudo vivo de ese mismo cubo.
**Impacto:** riesgo de pérdida de datos (invariante 9) por reutilizar un
contador con otra semántica.
**Alternativas:** (a) clave propia en `compute_freshness`
(`archive_rederive_failures`), mismo formato; (b) reutilizar la existente y
auditar todos sus lectores. **[Recomendación]** (a). Es tu criterio de
aceptación 5 el que cambia: **necesito tu visto bueno**.

### 3.2 ALG‑T1, ALG‑H1, ALG‑S3 y ALG‑L2 son fórmulas nuevas
**[Comprobado]** en analytics `3a7ca34d` no existen: IC por bootstrap de la
pendiente, SWC como función reutilizable (solo está dentro de
`readinessLnRmssd`), CV de lnRMSSD entre noches, SD de horario, sRPE,
tonelaje ni Edwards. Existen las piezas: `theilSen`, `robustBaseline`, `mdc`,
`mean`, `stddev`, `mad`.
**Por qué no basta con orquestar:** combinar `theilSen` + remuestreo + puerta
`max(MDC, SWC)` es una regla de decisión nueva; no es "llamar a lo que hay".
**Alternativas:**

| Opción | A favor | En contra |
|---|---|---|
| A. Módulos del fork en `edge`, calculados **al leer** y sin persistir, que solo componen primitivas de analytics (precedente: `healthspan.dart`, `calibration_estimate.dart`, "owner chose edge over an analytics fork") | Sin pin nuevo, sin subir `kAlgoVersion`, sin tocar goldens; se puede borrar sin migración | Contradice la letra de AGENTS §1 ("nueva métrica → analytics"); no llega a `day_result` ni al coach |
| B. Crear `MarcoteRL/analytics` y re‑pinear | Arquitectura limpia; persistido y versionado | Repo nuevo, pin por SHA, fusiones con upstream, cada cambio = bump + goldens; coste alto para fórmulas que aún no tienen datos con que validarse |

**[Recomendación]** A para las cuatro, con una regla: funciones puras, en un
directorio propio del fork (`lib/compute/fork/`), con tests sintéticos, sin
escribir en `day_result`/`metric_series`. Pasar a B solo cuando una de ellas
esté validada con ≥ 60 noches y merezca persistirse. **Para y pregunta, como
pediste: no empiezo la iteración 3 sin tu respuesta.**

### 3.3 Política por defecto del archivo: 90 días
**[Comprobado]** `SubstrateArchivePolicy.defaults = 90`. DATA‑02 solo puede
re‑derivar lo que siga archivado. DATA‑01 (ponerlo en "para siempre" en
Ajustes → Tus datos) es una acción tuya en el iPhone, sin código, y conviene
hacerla **ya**.

### 3.4 La re‑derivación tiene que convivir con dos guardas existentes
**[Comprobado]** `rescanDayIds` descarta días cuya ventana queda por debajo del
cursor de poda (`windowTruncatedByPrune`), y `_derivePreparedDay` se niega a
escribir un resultado vacío sobre uno bueno. Ambas guardas existen para
proteger el histórico. DATA‑02 debe añadir una ruta **separada** que
compruebe que el archivo cubre la ventana completa del día (incluida la
víspera desde mediodía, `kNocturnalSearchLookbackSec`), no relajar esas
guardas.

### 3.5 Multi‑dispositivo
**[Comprobado]** `_loadSubstrateRange` filtra filas por propiedad
(`ownership`, `device_coverage`). El archivo conserva `device_id` por cubo,
así que la rehidratación debe pasar por el mismo filtro. Cubre tu caso de
aceptación "`device_id ''` junto a otro dispositivo".

## 4. Lo que no se pudo comprobar

- Resultado de la suite completa 43233915353 (en curso al escribir esto).
- Todo lo que dependa de datos reales: no hay exportación en esta sesión.
- Comportamiento en dispositivo: instalación del IPA, tiempos, batería.
- Las cifras de validación del *stager* (κ 0,132): las declara el código de
  analytics; no se han reproducido.
- Referencias marcadas **G** en `research/REFERENCES.md` (Foster 2001,
  Buchheit 2014, Task Force 1996): sin verificar todavía; se verifican al
  abrir la tarea que las usa.
