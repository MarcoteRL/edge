# Calidad y cobertura de los datos

> Fecha: 2026-11-12 · Exportación real, WHOOP 5.0 · Zona horaria del
> dispositivo: CET (UTC+1, `tz_offset_min = 60`). Agregados únicamente.
> Reproducible con `docs/development/analysis/profile.py` y `cov.py`.

## 1. Cobertura temporal

| Nivel | Días | Detalle |
|---|---|---|
| Eventos de banda | ~14 | Primer evento ~13 días antes de la exportación |
| Sustrato comprimido (`substrate_archive`) | 4 días UTC | Todos parciales (de minutos a ~12 h) |
| 1 Hz vivo (`decoded_onehz`) | 4 días locales | 2 completos (24,0 h), 2 parciales (~14–15 h) |
| `day_result` v120 | 8 días | 3 con noche detectada |
| Noches con HRV, RHR, resp., sueño | **3** | |
| Sesiones de fuerza (Hevy) | ~2 meses | **Anteriores** a la banda: no hay FC que cruzar |

Huecos dentro del tramo vivo: 11 huecos > 60 s (6 > 10 min), 6,1 h en total,
todos en el primer día (emparejamiento y primeras sincronizaciones). Desde
entonces la cobertura es continua. Entre los días archivados y los vivos hay
2 días naturales sin ningún dato.

Uso (`worn_min`): los días completos registran 1440 min. La WHOOP 5 se carga
puesta, así que "llevada" no implica "midiendo bien": durante la carga la
temperatura de piel cae a valores de ambiente (ver §3).

## 2. ¿Qué métricas tienen histórico suficiente?

| Métrica | Noches/días disponibles | Mínimo que exige el código | Estado |
|---|---:|---:|---|
| Readiness composite | 3 (baseline: 2 previas) | 14 (`readinessCompositeMinBaseline`) | Abstiene |
| Calibración personal de readiness | 0 | 14 (`readinessCalibrationMinNights`) | — |
| Readiness lnRMSSD (Plews) | 2 previas | 4 | Abstiene |
| Strain diario | 2 días de nivel de reposo | 3 (`personalQuietWakingHrr`) | Abstiene |
| CTL/ATL/TSB | 3 días con TRIMP | 14 (`ctlAtlMinDays`) | **Se calcula** (ver Q-05) |
| Desviación de temperatura (gen5) | 2 previas | `kSkinTempDevMinNights` | Abstiene |
| Illness CUSUM | 2 | 7 | Abstiene |
| Anomalía multivariante | 2 | 10 | Abstiene |
| Sleep debt / necesidad de sueño | 0 noches libres | 3 noches libres | Abstiene |
| Cronotipo | 3 | 14 con ≥2 libres | Abstiene |
| SRI (regularidad) | 3 | se calcula | Poca fiabilidad con 3 noches |

**Ningún análisis estadístico de tendencias, correlaciones o validación de
recovery es fiable todavía.** Con uso continuo, la app empezará a dar
readiness en ~2 semanas y CTL fiable en ~6 semanas (42 días de constante).

## 3. Calidad de señal

| Señal | Observación | Gravedad |
|---|---|---|
| FC 1 Hz | 0,1 % `NULL`; 0,02 % < 35 lpm | Baja |
| RR nocturno | Cobertura ≈ 93 % del periodo de sueño en las 3 noches | Buena |
| RR diurno | Cobertura 10–55 % según la hora (≈ 25 % de media) | Esperado (movimiento) |
| RR en topes | 1,0 % de latidos = 333 ms exactos, 0,3 % = 2400 ms exactos | **Q‑01**: valores de tope, no fisiología |
| Diferencias sucesivas > 20 % | 16 % de los pares en todo el día | Alto de día; la limpieza Lipponen/Malik las trata |
| Temperatura de piel | 20 % de segundos fuera de 30–37 °C (carga, banda quitada, calentamiento) | **Q‑02** |
| `step_cadence` | 2,2 % = 255 | Probable centinela |
| `activity_class` | 95 % = 0 ("no clasificado") | No usar como "sedentario" |

### Hallazgos

- **Q‑01 RR en los topes 333/2400 ms.** Coinciden con los límites de
  aceptación. Ráfagas de 333 ms (180 lpm) en reposo son artefactos. La
  corrección `correctRr` (Lipponen & Tarvainen 2019) debería filtrarlos para
  RMSSD, pero el cribado de ritmo irregular trabaja sobre Poincaré/pNN70 y es
  sensible a ellos. Ver Q‑04.
- **Q‑02 Temperatura gen5 sin "banda de asentamiento".** El código no tiene
  banda de *settle* medida para gen5 (`lib/compute/onehz_pipeline.dart`,
  comentario sobre `nightlySkinTemp`: "gen5 has none"), así que
  `skin_temp_settled_frac` es `NULL` siempre y **readiness rechaza la
  temperatura todas las noches** en tu banda. La media nocturna incluye
  minutos de calentamiento.
- **Q‑03 Las ventanas "manuales" son pulsaciones de "I'm awake".**
  `sleep_override` tiene 2 filas `manual` y 1 `rejected`. En las 2 manuales
  `offset_ts == created_at` y el inicio es idéntico al detectado: es la firma de
  `AppState.markAwakeNow` (UX‑04), no de una edición. Consecuencias: (a) el
  inicio automático no se corrigió en ninguna noche; (b) esas 2 noches dan una
  **hora de despertar de referencia** (con el retraso de cuánto tardaste en
  pulsar); (c) la tabla **no distingue** "pulsé I'm awake" de "edité la
  ventana" (ambas `source = 'manual'`): procedencia perdida (backlog DATA‑06).
  El rechazo fue una ventana vespertina de ~3 h (el caso que BUG‑T01 arregló
  después). La banda (`band_sleep_state`) sigue marcando "dormido" entre 29 y
  161 min después del despertar pulsado: su envolvente sobreestima el final.
- **Q‑04 Cribado de ritmo irregular dispara en días sin noche.**
  `irregular_rhythm_flag = 1` en los 3 días con solo datos diurnos parciales y
  `0` en las 4 noches completas. Hipótesis (no verificada con ECG): el RR
  diurno con movimiento produce falsos positivos. Una alerta de salud con alta
  tasa de falsos positivos daña la confianza.
- **Q‑05 CTL/ATL rellena días no llevados con carga 0.** `crossday_pipeline.dart`
  construye una serie diaria densa (`_denseDailyTrimp`): un día natural sin
  fila o sin TRIMP cuenta como descanso. En esta base, 3 días con TRIMP y 12
  ceros producen `load` con confianza 0,36, pese a que `ctlAtlTsb` exige 14 días
  para no "inventar" un atleta. No llevar la banda no es descansar. Ver
  ALGORITHM_EVALUATION.md §3.
- **Q‑06 `rhr_nocturnal` == `rhr`** en las 3 noches (escalares duplicados).

## 4. Fechas, UTC y zonas horarias

- Todas las etiquetas de día comprobadas son locales y coherentes con
  `tz_offset_min = 60`. No se detectan días desplazados.
- `substrate_archive` se particiona por **día UTC** a propósito; con UTC+1 un
  día local cruza dos cubos. Correcto, pero hay que recordarlo al restaurar.
- La exportación empieza después del cambio de hora de octubre: el código de
  DST (`day_strain_dst_grid_test.dart`) no se pudo contrastar con datos reales.

## 5. Duplicados y nulos

| Comprobación | Resultado |
|---|---|
| Segundos duplicados en `decoded_onehz` | 0 (PK) |
| `counter` duplicados | 1 |
| Latidos duplicados (`coverage.rr_duplicate_beats`) | se informa por día; `rrCoverage > 1.10` bloquea RMSSD |
| `samples` vs `decoded_onehz` | Duplicado casi total (DB‑01) |
| `day_result` multi‑versión | 5 días con v113 y v120 (por diseño) |
| `sync_ledger` con error | 0 de 4 649 |
| `sync_quarantine` | vacía |

## 6. Métricas que no se están almacenando bien

| Métrica | Problema | Referencia |
|---|---|---|
| Temperatura en readiness | Siempre rechazada en gen5 | Q‑02 |
| `sessions.strain` | `NULL` en la sesión con traza | Esperable hasta tener nivel de reposo; confirmar que `strain_backfill.dart` lo rellena |
| Registros PIP v26 | Se archivan como "no decodificables" aunque el protocolo los parsea | DB‑02 |
| `metric_series` por versión | Solo la última; no permite comparar versiones por métrica | DATA‑03 en el backlog |
| Hábitos | Ningún registro de diario | Depende del uso |
