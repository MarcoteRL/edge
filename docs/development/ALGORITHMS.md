# Algoritmos actuales

> Fecha: 2026-11-12. Contrastado con el código: app `edge` @ `cb3bbbeb`
> (`kAlgoVersion 121`; revisado en la iteración 1, ver AUDIT_VERIFICATION.md), `openstrap_analytics` @ `3a7ca34` (pin de
> `pubspec.lock`), `openstrap_protocol` @ `b4fde6a`. Las rutas
> `analytics:<ruta>` son relativas a `lib/src/onehz/` del paquete de analítica;
> las demás, a `lib/` de este repo. El índice oficial de métodos y citas es
> `ALGORITHMS.md` del paquete de analítica; este documento explica **cómo se
> usan en la app**, con fórmulas y umbrales. La evaluación está en
> ALGORITHM_EVALUATION.md.

**Regla de oro:** las matemáticas viven en `openstrap_analytics`. `lib/compute/`
solo orquesta (AGENTS.md §1). Cambiar una fórmula = PR al paquete + re‑pin +
subir `kAlgoVersion` (AGENTS.md §3.4–3.6).

Leyenda de origen:
**[PUB]** reproducido de publicación · **[PROPIO]** heurística del proyecto ·
**[INSP]** inspirado en investigación con adaptación propia ·
**[WHOOP‑LIKE]** intenta parecerse a una métrica propietaria de WHOOP (no es su algoritmo).

## 0. Envoltorio común

Todo devuelve `Metric<T>{value, confidence, tier, inputs_used, drivers, note}`
(`analytics:types.dart`). Entrada ausente ⇒ `value = null`, `confidence = 0`,
`note = "need_baseline:have=H,need=N"` u otra razón. Nunca se imputa.

## 1. Señales base

| Algoritmo | Dónde | Fórmula / regla | Origen |
|---|---|---|---|
| Limpieza RR | `analytics:foundations/rr_correction.dart` `correctRr` | Clasificación dRR/mRR/sRR de Lipponen & Tarvainen 2019 | [PUB] |
| Integridad RR | `analytics:clinical/hrv_time.dart` `rrCoverage` | Σ RR plausibles / duración; > 1,10 ⇒ latidos duplicados ⇒ RMSSD rechazado | [PROPIO] |
| HRV nocturna (titular) | `hrv_time.dart` `sleepSessionRmssdDetail` | Media de RMSSD de ventanas de 5 min dentro del sueño, ≥ 20 diferencias limpias por ventana, rechazo ectópico 20 % (Malik) | [PUB] |
| HRV nocturna robusta | `hrv_time.dart` `nocturnalRmssd` | **Mediana** de RMSSD de ventanas de 5 min | [PUB] |
| RHR | `analytics:clinical/nocturnal.dart` | Media más baja de 30 min consecutivos (+ percentil 1) **dentro de una sesión de sueño detectada**; FC = 0 excluida | [PUB] |
| Frecuencia respiratoria | `analytics:respiration/resp_rate.dart` `rsaRespRate` | Pico HF (arritmia sinusal respiratoria): Lomb‑Scargle en sub‑ventanas de 300 s ≥ 80 % cubiertas, mediana con puerta de acuerdo | [PUB] |
| Temperatura de piel | `lib/compute/onehz_pipeline.dart` + `analytics:wellness/temp_circadian.dart` `nightlySkinTemp` | Media nocturna; gen4 en ADC, gen5 en centi‑°C; "settled fraction" solo donde hay banda de asentamiento medida (no en gen5) | [PROPIO] |
| Estrés | `analytics:clinical/stress_si.dart` | Índice de Baevsky `SI = AMo / (2·Mo·MxDMn)` sobre histograma de RR (bins 50 ms) → 0–100 | [PUB] |
| Ritmo irregular | `analytics:clinical/irregular_rhythm.dart` + `irregularRhythmFlag` (`lib/compute/onehz_pipeline.dart`) | Poincaré SD1/SD2 + pNN70. Desde v121 la bandera diaria exige que el cribado de la ventana de sueño exista y coincida; sin noche puntuada ⇒ null. Cribado, no diagnóstico | [INSP] |

## 2. Recovery / Readiness

**Función:** `readinessComposite` (`analytics:wellness/readiness_composite.dart`).
**Llamada:** `lib/compute/onehz_pipeline.dart` (bloque "READINESS").
**Origen:** [INSP] + [WHOOP‑LIKE] en la presentación (0–100, colores).

### Entradas

| Entrada | Valor de hoy | Baseline | Signo "bueno" | Peso declarado |
|---|---|---|---|---|
| HRV | `ln(rmssd_sleep_session)` | últimas noches (`d.lnRmssdHistory`) | + | 0,40 |
| RHR | `resting_hr.low30Mean` | `d.rhrHistory` | − | 0,30 |
| Resp. | `rsa.brpm` | `d.respHistory` | − | 0,20 |
| Temp. | media nocturna | `d.skinTempAdcHistory` | − | 0,10 (rechazada si no hay *settled fraction* ≥ 0,80) |

Ventana de baseline: hasta 28 días derivados previos (`_baselineWindowDays`
en `lib/compute/derivation_engine.dart`), **excluyendo el propio día**
(`_BaselineHistoryCache.valuesBefore`) y los días importados de otro vendor.

### Fórmula

1. Por entrada: `z_i = (x − mediana(B)) / (1,4826·MAD(B))` (z robusto). Si la
   entrada es cuantizada (RHR en lpm enteros, temp en cuentas) y la dispersión
   del baseline es menor que un escalón, la entrada se **rechaza** por nombre.
   Si MAD = 0 en una entrada continua: z clásico media/SD.
2. Orientación: `o_i = signo_i · z_i`.
3. HRV y RHR forman **un solo bloque autonómico** (correlación 0,82 medida):
   `o_aut = media(o_HRV, o_RHR)` con peso 0,70.
4. `Z = Σ w_i·o_i / Σ w_i` sobre las entradas presentes (renormaliza, no
   imputa). Exige ≥ 2 entradas y Σw ≥ 0,5; cada entrada ≥ 14 noches de baseline.
5. Puntuación: sin calibrar `S = 100 / (1 + e^(−Z))`; con ≥ 14 composites
   previos: `S = 100 / (1 + e^(−0,65·(Z − ĉ)/σ̂))`, `σ̂ = max(0,3; MAD(Z_hist))`,
   `ĉ = clamp(mediana(Z_hist), ±0,5)`.
6. Bandas de Home: cortes 26 / 37 / 61 (percentiles 5/20/75 de logistic(N(0; 0,65))).
7. Siempre devuelve `drivers` (contribución de cada entrada) para explicar.

### Diferencias con WHOOP

| | WHOOP (público) | OpenStrap |
|---|---|---|
| Entradas | HRV, RHR, **sueño**, frecuencia resp. (+ SpO2/temp. en 4.0 como contexto) | HRV, RHR, resp., temp. **El sueño no entra** |
| HRV | Ponderada al último sueño profundo (declaración pública, sin fórmula) | Media de ventanas de 5 min en todo el sueño |
| Pesos | No publicados | Publicados (0,70 / 0,20 / 0,10) |
| Arranque | ~4 noches de calibración | 14 noches + 14 de calibración de escala |

Fuentes: ver research/RECOVERY_RESEARCH.md.

### Estimación de calibración (fork, FP‑CAL) — [PROPIO] + [WHOOP‑LIKE]

Mientras el composite abstiene, `lib/compute/calibration_estimate.dart`
(`calibratingRecovery`) calcula **al leer** una estimación gris con las mismas
entradas, signos y pesos, contra un baseline que mezcla una referencia adulta
genérica (vale 3 noches) con tus noches; z acotado a ±2; mismo logístico.
Exige HRV o RHR de esa noche. Nunca se guarda, fija, notifica ni grafica.
Evaluación en ALGORITHM_EVALUATION.md ALG‑R1.

### Otros dos "readiness" (no titulares)

- `readinessLnRmssd` (`analytics:clinical/readiness_lnrmssd.dart`): Plews
  2013, lnRMSSD frente a la media móvil de 7 noches; exige 4 noches. [PUB]
- `glassBoxReadiness` (`analytics:human/readiness_glassbox.dart`):
  **deprecado**, se conserva por el desglose en percentiles. [PROPIO]

## 3. Strain y carga

**Funciones:** `analytics:clinical/load_trimp.dart`. **Llamadas:**
`lib/compute/onehz_pipeline.dart`, `lib/compute/manual_session.dart`,
`lib/compute/quiet_level.dart`, `lib/compute/strain_backfill.dart`.
**Origen:** TRIMP [PUB]; mapa 0–21 [WHOOP‑LIKE]; nivel de reposo [PROPIO].

1. **TRIMP de Banister** por minuto de vigilia:
   `x = (FC − RHR)/(FCmax − RHR)`, `TRIMP = Σ Δt·x·y(x)`,
   `y = 0,64·e^(1,92x)` (hombre) / `0,86·e^(1,67x)` (mujer).
2. **Nivel de reposo** (`dailyQuietWakingHrr`): mediana de `x` en los minutos
   despiertos del día; nulo si > 0,40. Rasgo personal:
   `personalQuietWakingHrr` = mediana de los 28 días previos; abstiene con < 3
   días, "calibrando" con < 7.
3. **TRIMP neto** (`netTrimpAboveQuiet`): minutos con `x ≥ 0,40` (suelo ACSM de
   intensidad moderada) suman íntegros; los demás se compensan contra
   `Q·y(Q)` por minuto y el bloque se acota a ≥ 0.
4. **Mapa 0–21** (`strainFromNetTrimp`): `u = min(1, net/400)`,
   `strain = 21·ln(1 + 14u)/ln 15`. Satura a ~3,25 h a 160 lpm (perfil de
   referencia del archivo).
5. Curva intradía: `strainCurveFromSeries` (acumulado por minuto).
6. **Carga crónica/aguda** (`ctlAtlTsb`): EWMA, CTL τ = 42 d, ATL τ = 7 d,
   `TSB = CTL − ATL`; mínimo 14 días; arranca con la media de los 7 primeros.
   Desde v121 (`_loadWithCoverage` en `lib/compute/crossday_pipeline.dart`) la
   carga **abstiene** con `need_baseline:have=H,need=N` hasta que
   max(14, 80 % de los últimos 42 días naturales) tengan TRIMP medido; un día
   sin medir ya no cuenta como descanso. La serie que recibe `ctlAtlTsb` sigue
   siendo densa (`_denseDailyTrimp`): aceptar nulos es una fórmula pendiente
   en analytics.
7. **Zonas de FC**: 5 zonas sobre `zone_max_hr` (`zone_source` indica si es
   observada, por edad o editada; `analytics:workout/hr_zones.dart`,
   `observed_max_hr.dart`).
8. **Objetivo de strain** (`strainTarget`, `analytics:human/coaching.dart`):
   recomendación del día según readiness; se dibuja como banda en Home. [WHOOP‑LIKE]
9. **Strain de calibración** (FP‑CAL): el mismo marcador neto con el nivel de
   reposo poblacional (0,20 FCR) mientras el personal no existe; solo al leer.

Modelos **no** implementados: Edwards (zonas × 1..5), Lucia, TRIMP por sesión
RPE (Foster), Training Stress Score de potencia. Evaluación en
ALGORITHM_EVALUATION.md §3.

## 4. Sueño

**Fuente única de ventana:** `segmentSleep` (`analytics:sleep/segment.dart`).
**Precedencia de ventana** (`lib/compute/substrate.dart`):
`override del usuario > vendor_staged > auto (van Hees) > auto_fallback (HR) > none`.

| Paso | Dónde | Regla | Origen |
|---|---|---|---|
| Ventana | `analytics:sleep/van_hees.dart` | Inmovilidad del ángulo z (van Hees 2015/2018) sobre acelerómetro 1 Hz | [PUB] |
| Fallback | `analytics:sleep/hr_fallback.dart` `hrLedSleepWindow` | Ventana guiada por FC cuando no hay acelerómetro útil | [PROPIO] |
| Recorte final | `analytics:sleep/band_offset.dart` | Si la banda pasa a despierto y se queda así hasta el final de la ventana, recorta ese tramo ("corroboración, nunca fuente") | [PROPIO] |
| Noche aún abierta | `lib/compute/substrate.dart` `tonightStillGoing` (BUG‑T01) | Un bloque quieto que empieza ≥ 11:00 y sigue abierto en el borde de datos pertenece al día en que termine, no a hoy | [PROPIO] |
| Cierre manual | `AppState.markAwakeNow` ("I'm awake") | Guarda inicio detectado → ahora como ventana `manual` | — |
| Procedencia del cierre manual | regla de análisis, sin código (D‑12) | Una pulsación de "Ya estoy despierto" es la fila de `sleep_override` con `source = 'manual' AND abs(created_at − offset_ts) ≤ 60` (la pulsación guarda "ahora" como final y la fila se sella en el mismo instante). **Límites:** (1) una fila por día con REPLACE: una edición posterior pisa la pulsación y la etiqueta se pierde; (2) una edición cuyo final cae en el minuto en curso cumple la regla. Fijado en `test/awake_tap_provenance_test.dart` | [PROPIO] |
| Fases (la UI las muestra como rango: `stageRanges` de `analytics:sleep/segment.dart`, `_ranges` en `ui2/screens/sleep_detail.dart`) | `analytics:sleep/cardio_stager.dart` `cardioStager` | Épocas de 30 s; vigilia por movimiento ENMO o FC por encima de mediana local; REM/profundo por puntuación ponderada de R(k), SDNN, SD de FC, LF/HF, z frente a la propia noche. Sin ML | [INSP] |
| Contabilidad | `analytics:sleep/accounting.dart` | TIB, TST, WASO, eficiencia = TST/TIB observado; despertar = ≥ 300 s (`kSustainedAwakeningSec`) | [PUB] |
| Ciclos | `analytics:sleep/cycles.dart` | Método fractal sobre RMSSD por minuto (Rosenblum 2024) | [PUB] |
| Siestas | `analytics:sleep/nap.dart` `detectNaps` | Inmovilidad fuera de la ventana principal + caída de FC; sin fases | [PROPIO] |
| Regularidad | `analytics:sleep/sri.dart` `phillipsSri` | SRI de Phillips 2017, concordancia época a época a 24 h | [PUB] |
| Deuda | `analytics:human/sleep_regularity.dart` `sleepDebt` | p75 de noches libres − sueño habitual; ≥ 3 noches libres | [PROPIO] |
| Necesidad | `coaching.dart` `sleepNeed` | `clamp(base + deuda + (strain/21)·45 min − siesta, 6 h, 11 h)`; base = p75 libre acotado a 7–9,5 h; **sin 8 h por defecto** (`crossday_pipeline.dart`) | [WHOOP‑LIKE] |
| Rendimiento | `coaching.dart` `sleepPerformance` | `min(100, TST/necesidad·100)` | [WHOOP‑LIKE] |
| Hora de acostarse / despertar | `coaching.dart` `recommendedBedtime`, `recommendedWake` | Necesidad / eficiencia típica; despertar alineado a ciclos | [PROPIO] |
| Cronotipo / jet lag social | `analytics:human/circadian_lifestyle.dart` | MSFsc (MCTQ, Wittmann & Roenneberg 2006) | [PUB] |

Validación declarada del *stager* (en su propio código, DREAMT, 49 sujetos de
prueba): κ = 0,132 en 4 clases; profundo 56 % sensibilidad / 10,9 % VPP; REM
51,9 % / 21,5 %; vigilia 11 % de sensibilidad. Por debajo del rango de
consumo (κ 0,21–0,53). **Las fases son orientativas.**

## 5. Longitudinal

| Algoritmo | Dónde | Regla | Mínimo |
|---|---|---|---|
| Baseline robusto | `analytics:foundations/baseline.dart` `robustBaseline`, `mdc` | Mediana + MAD; MDC para no nombrar cambios por debajo del ruido | 3 |
| Baseline EWMA winsorizado | `analytics:foundations/ewma_baselines.dart` | EWMA con winsorización | — |
| Enfermedad (NightSignal) | `analytics:clinical/illness_cusum.dart` | CUSUM online sobre RHR (verde/amarillo/rojo), Alavi 2022 | 7 |
| Anomalía | `analytics:wellness/anomaly.dart` | Mahalanobis {RHR, HRV, temp, resp} + χ² | 10 |
| Puntos de cambio | `analytics:wellness/changepoint.dart` | CUSUM (Killick 2012) | — |
| Sobre‑entrenamiento | `analytics:human/overreaching_conjunction.dart` | Conjunción de señales | 4 |
| Coste de sesión | `analytics:human/session_cost.dart` | Efecto de una sesión sobre RHR/RMSSD del día siguiente | 14 |
| Efecto día de semana | `analytics:human/weekday_effect.dart` | | ≥ 4 semanas |
| Percentil propio | `analytics:human/percentile_of_you.dart` | Percentil frente a tu histórico | — |
| Correlaciones del diario | `coaching.dart` `journalCorrelations`, `journalNumericCorrelations` | Diferencia de medias / Spearman con permutaciones y Benjamini‑Hochberg | según n |

## 6. Energía, actividad y otros

| Algoritmo | Dónde | Regla | Origen |
|---|---|---|---|
| Calorías | `analytics:workout/calories.dart` | BMR Mifflin + excedente activo Keytel 2005 (FC) + METs por cadencia | [PUB] |
| Minutos activos | `analytics:motion/steps.dart` `dailyActiveMinutes` | Movimiento sostenido de muñeca sobre umbral dinámico personal | [PROPIO] |
| Auto‑detección de entrenos | `analytics:workout/auto_detect.dart` | Segmentos de FC/movimiento | [PROPIO] |
| Recuperación de FC | `analytics:workout/hr_recovery.dart` | Caída de FC N s tras el pico (Cole 1999) | [PUB] |
| VO2max | `analytics:clinical/vo2max.dart` | Estimación por ratio de FC / modelo no‑ejercicio | [PUB, ESTIMATE] |
| Edad fisiológica | `lib/compute/healthspan.dart` (módulo del fork) | 9 contribuyentes al estilo WHOOP Age, curvas citadas en cabecera | [WHOOP‑LIKE] |
| Apnea (cribado) | `analytics:respiration/cvhr_apnea.dart` | CVHR (Hayano); no es IAH | [PUB] |
| Alcohol / noche dura | `analytics:human/event_detection.dart` | Firma autonómica; nunca afirma causa | [INSP] |

## 7. Versionado y recalculado

- `kAlgoVersion` (`lib/compute/derivation_engine.dart`) etiqueta cada
  `day_result`. Una versión nueva no pisa a la anterior, pero **la misma
  versión sí se reescribe** (`putDayResult` usa REPLACE): la inmutabilidad
  hay que imponerla en cada ruta que re‑derive (AUDIT_VERIFICATION.md §2.2). Subirlo re‑deriva solo los días con sustrato vivo (≈ 5 días) y
  los no finalizados.
- **Re‑derivación desde el archivo (DATA‑02, fork).** En una pasada `heavy` o
  forzada en primer plano, `_rederiveArchivedPass` (`derivation_engine.dart`)
  lleva a `kAlgoVersion` los días a los que la poda ya ha llegado, leyendo su
  sustrato de `substrate_archive` **en memoria** (`RehydratedSubstrate`:
  archivo ∪ vivo, gana la fila viva; nunca se reinserta en `decoded_*`).
  Reglas: solo días sin fila completa de la versión actual; del más antiguo
  al más reciente, recargando el historial de baselines antes de cada día;
  4 días por pasada (sin tope en "Re‑analyze everything"); cede ante un
  volcado BLE o un sync en segundo plano. Un día **conserva su versión**, con
  el motivo guardado, si: empieza antes que el archivo (`before_archive`), el
  archivo se grabó en otra zona horaria (`tz_changed`), lo leído tiene menos
  grabación que el resultado guardado (`less_data`), las guardas del motor
  prefieren el resultado existente (`no_gain`), no es un día medido
  (`not_measured`) o el archivo no se pudo leer tres veces (`unreadable`,
  contado en `archive_rederive_failures`, nunca en
  `substrate_archive_failures`). No se ejecuta con una zona horaria pendiente
  de resolver ni con un wearable activo. Estado e informe agregado:
  `compute_freshness.archive_rederive` (`DerivationEngine.archiveRederiveReport`).
  No cambia la salida de ningún día: sin subida de versión.
- `metric_series` guarda la última versión de cada día.
- Backfills idempotentes marcados en `compute_freshness`
  (`strain_rescale_v63`, `readiness_calibration_v112`, `quiet_hrr_seed_v1`…).
