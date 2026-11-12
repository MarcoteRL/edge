# Diccionario de datos

> Fecha: 2026-11-12 · Esquema `schemaVersion 58` · Fuente de verdad del DDL:
> `lib/data/db.dart`. Fuente de verdad del significado de cada byte de la banda:
> paquete `openstrap_protocol` (`lib/src/gen5_records.dart` para WHOOP 5/MG,
> `lib/src/records.dart` para WHOOP 4), fijado por SHA en `pubspec.yaml`.
>
> Columnas "Cobertura/Rango" medidas sobre la exportación real de una WHOOP 5.0
> (4 días vivos). Los rangos son **del sensor**, no fisiológicos: incluyen
> artefactos, banda fuera de la muñeca y cargando. No se copian valores
> individuales. "No verificado" = el significado no está confirmado en el
> protocolo ni en el código.

## 1. Convenciones

| Convención | Regla |
|---|---|
| Tiempo absoluto | `rec_ts`, `ts`, `start_ts`, `end_ts`, `onset_ts`, `device.first_seen/last_seen` en **segundos Unix**. `ts_ms`, `beat_ts_ms`, `rr_ts_ms`, `captured_at`, `created_at`, `computed_at`, `*_at` de `sync_ledger` en **milisegundos**. |
| Etiqueta de día | `day_id` / `date` = `YYYY-MM-DD` **local** (invariante 7). Solo vía `todayLabel()` / `dayLabelOf()` de `lib/data/day_label.dart`. El día va de medianoche local a medianoche local (`calendarDays()` en `lib/compute/substrate.dart`). Una noche se atribuye al día en que te despiertas. |
| `device_id` | `''` = banda principal. Otros valores = dispositivos secundarios. |
| Ausencia | `NULL` = no medido. Nunca `0` como relleno (invariante 3). Excepción heredada: `samples.hr = 0` cuando no hubo lectura. |
| Envoltorio de métrica | En `payload_json`, casi todo es `{value, confidence 0..1, tier, inputs_used, note}`. `note` sigue el formato `need_baseline:have=H,need=N` cuando falta histórico. |
| Tiers | `auth` medido · `high` fuerte evidencia · `estimate` estimación · `relative` solo frente a tu baseline. |

## 2. Ledger crudo

### `decoded_onehz` — un registro por segundo de banda

| Campo | Tipo | Unidad | Significado | Cobertura gen5 | Rango observado | Notas de calidad | Utilidad |
|---|---|---|---|---|---|---|---|
| `device_id`, `ts_ms` | TEXT, INT | —, ms | PK | 100 % | — | `ts_ms = rec_ts*1000` | — |
| `rec_ts` | INT | s | Segundo Unix del registro (reloj de la banda) | 100 % | — | | Eje temporal |
| `counter` | INT | — | Índice de registro de la banda | 100 % | monótono | 1 duplicado | Detección de huecos |
| `hr` | INT | lpm | FC de la banda | 99,9 % | 30–164 | `NULL` = sin lectura (banda calentando / fuera de piel). 0,02 % < 35 lpm | RHR, zonas, TRIMP, strain |
| `hr_alt` | INT | lpm | Segunda estimación de FC | 100 % | 0–200 | Coincide con `hr` ±3 lpm en el 74 %. **No verificado**; no lo lee ningún cálculo | Investigar como control de calidad |
| `ax, ay, az` | REAL | g | Aceleración triaxial (1 Hz) | 100 % | ~±3 g | | Sueño (z‑angle), actividad |
| `dyn_accel_g` | REAL | g | Máx. delta adyacente de magnitud de aceleración (movimiento) | 100 % | 0–12,7 | "Es movimiento, no calidad de señal" (protocolo) | Actividad, artefactos |
| `signal_quality_logvar` | REAL | log var | Calidad de señal óptica | 100 % | aprox. −5,3 a 0,2 | Mayor = más ruido | Filtrar artefactos de FC/RR |
| `skin_temp_c` | REAL | °C | Temperatura de piel de muñeca | 100 % | 16–39 | 80 % entre 30–37 °C; el resto es banda fría/cargando/quitada | Desviación nocturna, enfermedad |
| `temp_ch2_c`, `temp_ch3_c` | REAL | °C (supuesto) | Otros termistores | 100 % | 16–43 | Pasos de 0,1–0,3. **No verificado** | Investigar (ambiente/batería) |
| `step_count` | INT | pasos (acum.) | Contador de movimiento del chip | 100 % | monotono, 1 reinicio | El protocolo avisa: el nombre "steps" es inferencia de terceros | Pasos diarios |
| `step_cadence` | INT | ppm (supuesto) | "Cadencia" | 100 % | 57–255 | 2,2 % = 255 (centinela probable) | METs de marcha (`Calories.metFromCadenceSpm`) |
| `activity_class` | INT | código | 0 desconocido, 1 caminar, 2 correr | 100 % | 0–2 | **0 = "no clasificado", no "quieto"** | Auto-detección de entrenos |
| `band_sleep_state` | INT | código | Estado de sueño de la propia banda: 0 despierto, 1 quieto, 2 dormido, 3 levantado | 100 % | 0–3 | Envolvente, sin fases. Retrasa ~10 min el inicio | Recorte del final de la noche (`band_offset.dart`), validación cruzada |
| `ts_subsec` | INT | Q15 | Sub‑segundo (centésimas × 327,68) | 100 % | 0–32 440 | | Alinear latidos |
| `device_family` | TEXT | — | `gen4`/`gen5`/... | 100 % | `gen5` | | Ramas de algoritmo |
| `skin_temp_raw`, `spo2_red_raw`, `spo2_ir_raw`, `ambient_raw`, `on_wrist`, `hr_valid` | INT | ADC | Canales de WHOOP 4 | **0 %** en gen5 | — | Ausentes por diseño del formato gen5 | SpO2 relativo solo en gen4 |
| `source` | TEXT | — | Fuente multi‑dispositivo | 0 % | — | `NULL` = banda | — |

### `decoded_rr` — latidos

| Campo | Unidad | Significado | Observado | Calidad |
|---|---|---|---|---|
| `rec_ts`, `ts_ms` | s, ms | Segundo del registro que trajo el latido | 127 988 segundos con latidos | Cobertura de RR ≈ 93 % del sueño y ≈ 25 % del día |
| `beat_index` | — | 0..3 dentro del segundo | | |
| `rr_ms` | ms | Intervalo R‑R (pulso, **PRV**, no ECG) | 333–2400 | **1,0 % exactamente 333** y 0,3 % exactamente 2400: topes del rango aceptado, no fisiología |
| `beat_ts_ms` | ms | Instante del latido | | Alinea con `ts_subsec` |
| `rr_ts_ms` | ms | Clave heredada | | |

### Otras tablas crudas

| Tabla | Clave | Contenido | Notas |
|---|---|---|---|
| `samples` | `(device_id, ts_ms)` | `ts`, `counter`, `hr` | Duplicado legado de `decoded_onehz.hr` (DB‑01) |
| `raw_archive_frames` | `UNIQUE(device_id, hash)` | Frames que la app no decodificó: `packet_type`, `counter`, `reason`, `frame` (BLOB) | gen5: 100 % `undecodable_rec_v26` (registro PIP, ver DATABASE_AUDIT DB‑02) |
| `substrate_archive` | `(device_id, utc_day)` | 1 Hz + RR comprimidos de días podados (`codec`, `blob`, `onehz_rows`, `rr_rows`, `tz_offset_min`) | Partición por día **UTC**, no local. Solo escritura de momento |
| `events` / `band_events` | `(device_id, hex)` | Eventos de banda; `band_events` decodificado (`name`, `payload_json`) | 35 tipos. Útiles: `WRIST_ON/OFF`, `CHARGING_ON/OFF`, `BATTERY_*`, `DOUBLE_TAP`, `STRAP_DRIVEN_ALARM_*` |
| `band_battery` | `(device_id, ts, source)` | `% batería`, `charging`, `millivolts` | 3 fuentes: `band_event`, `band_event_ext`, `device_state` |
| `band_backlog` | `(device_id, ts)` | Ocupación de flash de la banda | Diagnóstico de sync |
| `device_coverage` | `(device_id, signal, start_ts)` | Intervalos con señal por tipo | |

## 3. Derivado

### `day_result`

| Campo | Significado |
|---|---|
| `day_id`, `algo_version` | PK. Inmutable por versión (invariante 4) |
| `payload_json` | Bundle completo del día (ver §4). 75–82 KB por día completo |
| `window_json` | Ventana de derivación |
| `finalized` | 1 = bloqueado (48 h después del último registro del día, `_finalizationSec`) |
| `partial` | 1 = escalares buenos pero falló la segunda mitad del cálculo |
| `skipped`, `imported` | Día saltado / importado de otro vendor (no entra en baselines) |
| `rhr`, `rmssd`, `readiness` | Copias desnormalizadas para consultas rápidas |

### `metric_series` (`date`, `key`, `value`) — 42 claves en esta base

| Clave | Unidad | Origen (payload) | Días con valor (de 8) |
|---|---|---|---|
| `rhr` | lpm | `clinical.resting_hr.low30_mean_bpm` (media más baja de 30 min dentro del sueño) | 3 |
| `rmssd` | ms | `clinical.rmssd_sleep_session` (media de ventanas de 5 min limpias) | 3 |
| `ln_rmssd` | ln(ms) | ln de `rmssd` | 3 |
| `sdnn`, `hrv_cv`, `lf_hf`, `prsa_dc` | ms, —, —, ms | HRV temporal/frecuencial/PRSA | 3 |
| `resp_rate` | rpm | RSA (pico HF del RR) | 3 |
| `skin_temp_adc` | centi‑°C en gen5, ADC en gen4 | Media nocturna | 3 |
| `skin_temp_coverage_frac` | 0..1 | Fracción de noche con temperatura | 3 |
| `skin_temp_z` | z | Desviación frente a ≥3 noches previas | 0 |
| `tst_min`, `deep_min`, `light_min`, `rem_min` | min | `sleep.accounting` | 3 |
| `efficiency` | % | TST / tiempo en cama observado | 3 |
| `awakenings` | n | Despertares ≥ 5 min | 3 |
| `sol_min`, `longest_sleep_min`, `unobserved_min` | min | Latencia, tramo más largo, minutos sin datos | 2–3 |
| `sleep_onset_sec`, `midsleep_sec` | s desde medianoche local | Horario | 3 |
| `dip_pct` | % | Caída nocturna de FC | 3 |
| `stress` | 0–100 | Índice de Baevsky → escala | 3 |
| `brv_cv` | — | Variabilidad de frecuencia respiratoria | 3 |
| `trimp` | u.a. | TRIMP de Banister del día despierto | 3 |
| `trimp_net`, `strain` | u.a., 0–21 | Sobre el nivel de reposo personal | 0 (abstiene) |
| `quiet_hrr` | fracción FCR | Mediana de %FCR en vigilia | 2 |
| `readiness`, `readiness_z` | 0–100, z | Composite canónico | 0 (abstiene) |
| `calories`, `calories_total` | kcal | Activa (Keytel) / total (Mifflin + activa) | 3 |
| `steps`, `active_min`, `worn_min`, `dyn_p90`, `nap_min` | — | Actividad y uso | 6–8 |
| `irregular_rhythm_flag` | 0/1 | Cribado de ritmo irregular 24 h | 7 |
| `hrr_bpm`, `hr_ceiling_bpm`, `hrr_tau_s` | lpm, lpm, s | Recuperación de FC post‑esfuerzo | 0–1 |

### Otras tablas derivadas

| Tabla | Contenido |
|---|---|
| `metric_series_version(date)` | `algo_version`, `source` (`band`), `device_family`, `priority_hash` del día |
| `metric_method(date,key)` | Procedencia por valor (`hr_1hz`/`ours`); ver DB‑04 |
| `baselines(key)` | `rolling` (medias), `rolling_artifact` (series usadas para el baseline + firma), `sleep_user_profile` (perfil de FC/HRV de sueño), `crossday_input`, `crossday` (salidas multi‑día), `tz_travel_guard` |
| `sleep_session_candidates`, `wake_day_features` | Intermedios por día y versión |
| `compute_freshness(key)` | Marcadores de migraciones/backfills, política de archivo, firmware visto, estado de "hoy" |
| `sync_cursor(name)` | `decoded_pruned_before`, `rec_ts_hw`, `counter_hw`, `strap_trim`, `baseline_quiet`, `baseline_sig` |

## 4. Forma de `day_result.payload_json` (v120)

```text
date, day_confidence, flags[]            # p.ej. SLEEP_MANUAL
scalars{...}                             # ~55 escalares; la mayoría acaban en metric_series
clinical{hrv_time, rmssd_sleep_session, rmssd_nocturnal, hrv_freq, resting_hr,
         hr_dip, prsa_dc, prsa_ac, irregular, irregular_24h, brv,
         readiness_lnrmssd, readiness_composite, strain, trimp}
baselines{resting_hr, hrv, resp, skin_temp}   # baseline, spread, n_valid, z, delta, mdc, mdc_multiples, status
sleep{window, accounting, stager, cycles[], cycle_count, cycles_metric,
      cycle_series[], absence_reason, band_offset_trim_sec}
sleep_source                             # auto | manual | vendor_staged | auto_fallback
respiration{rsa, cvhr_apnea, odi}        # odi rechazado en gen5 (canales red/IR no separables)
hrv_night_shape, wellness{skin_temp}, stress{...}
zones{z1..z5}, zone_source, zone_max_hr, zone_lower_bpm[], max_hr_used, hr_stats
series{hr_curve, strain_curve, zone_timeline, hrv_timeline, hypnogram[], hrv_day, resp_day, skin_temp_day}
coverage{hr_samples, rr_beats, nn_clean, clean_fraction, sleep_seconds, rr_coverage, rr_duplicate_beats}
readiness_absent_diag{hrv, rhr, resp, temp, note}   # solo si readiness abstiene
calories_total{value, active, basal}, activity{...}, activity_curve{t0, dt, v[288]}
wear{segments[], worn_min, coverage_pct, longest_off_min}, steps{...}
absent_notes{...}
```

## 5. Entrenamiento y entrada manual

| Tabla | Campos clave | Estado en esta base |
|---|---|---|
| `sessions` | `start_ts`/`end_ts` (s), `type`, `source` (`manual`, `hevy`, `suggestion`…), `strain`, `calories`, `max_hr`, `avg_hr`, `zone_min_json` (5 zonas, min), `hrr_bpm`, `trace_json`, `rpe`, `vo2max_estimate`, `end_ts_fabricated` | 24 importadas de Hevy (sin FC, anteriores a la banda) + 1 registrada con traza |
| `strength_set` | `session_id`, `exercise_key`, `set_index`, `reps`, `load_kg`, `rpe`, `rest_sec` | 503 series; `load_kg` 99 %, `rpe` 1 % |
| `exercise_def` | catálogo de ejercicios | 11 |
| `sleep_override` | `day_id`, `onset_ts`, `offset_ts`, `source` (`manual`/`rejected`/`confirmed`) | 3 (2 manuales, 1 rechazo) |
| `journal*`, `food_*`, `med_*`, `lab_*`, `cycle_*` | Hábitos, nutrición, medicación, analíticas, ciclo | Vacías |
