# Backlog de mejoras (listo para issues)

> Fecha: 2026-11-12 · commit `15d791a0`. Cada entrada se puede copiar como
> issue. Prioridades: **P0** fiabilidad/integridad · **P1** alto valor
> inmediato · **P2** evolución · **P3** experimental. Esfuerzo S (≤ 1 día), M
> (≤ 1 semana), L (> 1 semana). "Repo" indica dónde va el cambio
> (edge = este repo, analytics = `OpenStrap/analytics`).
> El estado vivo de cada tarea se lleva en PLANNING.md; este archivo es la
> especificación. Plan de ejecución por iteraciones: ITERATION_PLAN.md.

Plantilla de cada tarea: **Qué** · **Por qué** · **Dónde** · **Cómo** ·
**Prueba** · **Resultado esperado**.

---

## P0 — Integridad de datos

### DATA‑01 · Archivo de sustrato indefinido por defecto en el fork
- **Qué:** poner la política de `substrate_archive` en "para siempre" (‑1) en tu dispositivo ya; valorar cambiar el defecto del fork.
- **Por qué:** lo que sale del archivo no se puede re‑derivar nunca (O‑01). Coste ~0,6 GB/año.
- **Dónde:** Ajustes → Tus datos (`ui2/profile/data.dart`); defecto en `SubstrateArchivePolicy.defaults` (`lib/data/substrate_archive.dart`).
- **Cómo:** primero, acción manual en la app (sin código). Cambiar el defecto solo si decides que es fork‑only (DECISIONS D‑07).
- **Prueba:** `compute_freshness.substrate_archive_policy.keep_days = -1` en una exportación.
- **Resultado:** cero pérdida de sustrato. **Esfuerzo:** S. **Repo:** edge.

### DATA‑02 · Re‑derivar días desde `substrate_archive` — **hecho (iteración 2, 2026‑11‑12; ver ALGORITHMS.md §7)**
- **Qué:** que un cambio de `kAlgoVersion` (o "Re‑analizar") pueda recalcular días podados leyendo el archivo.
- **Por qué:** sin esto, cada mejora de algoritmo solo llega a los últimos ~5 días (TD‑10).
- **Dónde:** `lib/data/substrate_archive.dart` (lectura), `lib/compute/derive_prepare.dart` (fuente del sustrato), `DerivationEngine` (selección de días).
- **Cómo:** función `readArchivedSubstrate(day)` que descomprima a la misma forma que `decoded_onehz`/`decoded_rr`; `derive_prepare` la usa cuando no hay filas vivas; ejecutar en isolate y por lotes. Toca hotspots: revisión independiente.
- **Prueba:** T‑05 (ida y vuelta: derivar desde vivo y desde archivo produce el mismo `payload_json`).
- **Resultado:** histórico recalculable. **Esfuerzo:** M–L. **Repo:** edge (candidato a PR upstream; el propio código lo anuncia como siguiente paso).

### ALG‑L1 · CTL/ATL: "no llevada" ≠ "descanso" — **en `main` (kAlgoVersion 121; runs 43231936403, 43232851823; suite completa 43233915353 pendiente de resultado)**
- `_loadWithCoverage` en `lib/compute/crossday_pipeline.dart`: abstiene hasta que el 80 % de los últimos 42 días naturales (y ≥ 14) tengan TRIMP medido. Tests en `test/crossday_pipeline_test.dart`. Queda el *upgrade* en analytics (serie con nulos), marcado con `ponytail:`.
- **Qué / Por qué / Cómo / Prueba:** ALGORITHM_EVALUATION.md §3 ALG‑L1.
- **Dónde:** `lib/compute/crossday_pipeline.dart` (`_denseDailyTrimp`) + `ctlAtlTsb` en analytics.
- **Resultado:** con la exportación actual, la carga **abstiene**. **Esfuerzo:** M. **Repo:** analytics + edge; bump `kAlgoVersion`.

### SEC‑09 · Ignorar exportaciones `.db` en git — **hecho (2026‑11‑12)**
- **Qué:** añadir `*.db`, `*.db-wal`, `*.db-shm` a `.gitignore`.
- **Por qué:** una exportación con biometría puede acabar en un commit (comprobado: hoy no se ignoran).
- **Prueba:** `git check-ignore -v foo.db`. **Esfuerzo:** S. **Repo:** edge (candidato upstream).

## P1 — Alto valor

### ALG‑C1 · Cribado de ritmo irregular solo en reposo — **primera fase en `main` (mismos runs que ALG‑L1)**
- `irregularRhythmFlag` en `lib/compute/onehz_pipeline.dart`: el veredicto diario exige que el cribado nocturno también exista y coincida. Test: `test/irregular_flag_corroboration_test.dart`. Segunda fase (enmascarar RR diurno por movimiento/calidad) pendiente, marcada con `ponytail:`.
- Ver ALGORITHM_EVALUATION.md §5. **Prueba:** T‑03. **Esfuerzo:** M. **Repo:** analytics + edge; bump.

### ALG‑R1 · Validar la estimación de calibración (FP‑CAL)
- Ver ALGORITHM_EVALUATION.md §1. Primer paso: script offline de concordancia estimación↔real desde la noche 15. **Esfuerzo:** S. **Repo:** edge (`docs/development/analysis/`).

### ALG‑T1 · Motor de tendencias 7/14/30/90
- Ver ALGORITHM_EVALUATION.md §6. **Esfuerzo:** M. **Repo:** analytics (función) + edge (llamada y UI P‑03).

### ALG‑L2 · Carga interna de fuerza (sRPE + tonelaje)
- **Comprobado 2026‑11‑12:** el RPE ya se pide (`ui2/activity/summary.dart`); falta usarlo.
- **Qué:** pedir RPE (CR‑10) al cerrar una sesión de fuerza; `sRPE = RPE × min`; tonelaje por grupo con el mapeo de `strength_summary.dart`; mostrar junto a la carga cardiovascular, sin mezclarlas.
- **Dónde:** `ui2/screens/log_workout.dart` / cierre de sesión → `sessions.rpe`; cálculo en analytics `workout/`; vista en `workout_screen.dart`.
- **Prueba:** test de ausencia (sin RPE ⇒ null), test de suma semanal. **Esfuerzo:** M.

### FI‑B4 · Tarjeta matinal de 10 segundos — **ya existe casi entera (2026‑11‑12)**
- El diario (`lib/data/journal_fields.dart`) ya tiene `mood`, `sleep_quality`, `energy`, `stress`, `soreness` (1–5), `caffeine_mg` con hora, `alcohol_units`, `water_ml`, `screens_min`. Lo que falta es **usarlo cada mañana**, no código. Pendiente real y pequeño: marcar una noche como "sin alarma" para la deuda de sueño (hoy `_isFreeDay` en `crossday_pipeline.dart` usa sábado/domingo).
- **Qué:** energía 1–5, sueño percibido 1–5, agujetas 1–5, "noche libre (sin alarma)" sí/no, hora de acostarse si difiere.
- **Por qué:** es la única verdad de referencia posible para validar readiness, sueño y deuda (ALG‑R1, ALG‑S1, FI‑E5).
- **Dónde:** reutilizar `journal_field_def` / `journal_metric` (sin tabla nueva); tarjeta en Home tras "I'm awake" o al abrir por la mañana.
- **Prueba:** test de widget + test de que se guarda en `journal_metric` con la etiqueta de día correcta (`dayLabelOf`). **Esfuerzo:** S–M.

### DATA‑06 · Distinguir "I'm awake" de una edición de ventana — **descartada (2026‑11‑12)**
- **No hace falta código.** La pulsación ya es reconocible: `markAwakeNow` guarda `offset_ts` = instante de la pulsación y `putSleepOverride` pone `created_at` en el mismo segundo (|Δ| ≤ unos segundos), con el inicio igual al detectado; una edición guarda horas redondeadas al minuto. Regla de análisis: `source = 'manual' AND abs(created_at - offset_ts) <= 60`. Cambiar el `source` habría obligado a tocar ~12 lectores de `'manual'` (riesgo AGENTS §4.7). Texto original abajo, como referencia.
- **Qué:** `source = 'awake_tap'` en `sleep_override` cuando viene de `AppState.markAwakeNow`.
- **Por qué:** hoy ambas son `manual`; se pierde la etiqueta de despertar que necesita ALG‑S1.
- **Cómo:** revisar **todos** los lectores de `sleep_override.source` (precedencia en `substrate.dart`, flag `SLEEP_MANUAL`, `overnightSettled(userSet:)`) para que `awake_tap` se trate como `manual`. Sin cambio de esquema.
- **Prueba:** test de que `awake_tap` produce la misma derivación que `manual`. **Esfuerzo:** S.

### UX‑P02 · Banda personal en lugar de flecha (Health → Overview)
- Ver UI_UX_AUDIT.md P‑02. Datos ya en `payload_json.baselines`. **Esfuerzo:** M.

### UX‑P04 · Progreso de calibración por métrica
- Ver UI_UX_AUDIT.md P‑04. Datos: notas `need_baseline` del payload. **Esfuerzo:** S.

### ALG‑H1 · CV de lnRMSSD a 7 días
- Ver ALGORITHM_EVALUATION.md §2. **Esfuerzo:** S.

### ALG‑S2 · Fases de sueño como rango — **ya existe (comprobado 2026‑11‑12)**
- `sleep_detail.dart` ya muestra cada fase como rango (`stageRanges`). Los `*_range_sec` son campos del payload del candidato, no columnas. Queda solo la jerarquía de la pantalla (P‑05).

## P2 — Evolución

| ID | Tarea | Dónde | Esfuerzo |
|---|---|---|---|
| ALG‑R3 | Banda de asentamiento de temperatura gen5 | analytics `temp_circadian.dart` | M |
| ALG‑R2 | Experimento de baselines (≥ 60 noches) | `docs/development/analysis/` | M |
| ALG‑R5 | Sueño→autonómico personal en el detalle de readiness | `readiness_detail.dart` | S |
| ALG‑S1 | Error del final automático frente a "I'm awake" | análisis offline | S |
| ALG‑S3 | SD de horario 7 d antes del SRI | analytics `human/` | S |
| ALG‑L3 | Distribución de intensidad (Edwards/zonas) | `workout_screen.dart` | S |
| UX‑P01 | Línea de decisión determinista | `home_screen.dart`, `grammar.dart` | M |
| UX‑P03 | Evolución (sparklines 30 d) en Home | `home_screen.dart`, `trend.dart` | M |
| UX‑P07 | Workout centrado en la carga | `workout_screen.dart` | M |
| UX‑P08 | Indicador de frescura de datos en todas las pestañas | `app_shell.dart` | S |
| FI‑F8 | Modo validación frente a export oficial WHOOP | `whoop_import.dart` + pantalla | M |
| FI‑F7 | Exportación analítica completa (CSV/Parquet + diccionario) | `csv_export.dart` | S |
| FI‑D1 | Etiquetas rápidas de hábitos | diario | S |
| FI‑E4 | Registro de recomendaciones (`recommendation_log`) | `db.dart` (migración aditiva) | M |
| FI‑F2 | Experimentos N‑of‑1 | nueva pantalla + `experiment` | M |
| DATA‑03 | Poda o consumo de PIP v26 en `raw_archive_frames` | `db.dart` (`_thinRawArchiveVia`) | S |
| T‑02 | Test de contrato `payload_json` ↔ lector | `test/` | S |

## P3 — Experimental

| ID | Tarea | Notas |
|---|---|---|
| FI‑E3 | Predicción de readiness de mañana | ≥ 90 noches + FI‑B4 |
| FI‑F4 | Laboratorio de métricas | Fórmulas sobre `metric_series` |
| FI‑F5 | Dashboard configurable | |
| FI‑D3 | Doble toque como marcador | `band_events.DOUBLE_TAP` |
| ALG‑R4 | Signo de la temperatura (|z|) | Tras ALG‑R3 |
| ALG‑C2 | RR en topes 333/2400 ms | Investigación en `protocol` |
| INV‑01 | Semántica de `hr_alt`, `temp_ch2_c`, `temp_ch3_c` | Repo `protocol` |

## Ya cubierto por el fork (no duplicar)

FP‑01 caducidad de sideload · FP‑HS edad fisiológica · FP‑CAL estimaciones de
calibración · FP‑HEVY import Hevy · UX‑01…06 Home · BUG‑T01 noche abierta ·
BUG‑L01 idioma del coach (ver PLANNING.md).
