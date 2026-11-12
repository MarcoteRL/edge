# Oportunidades a partir de los datos reales

> Fecha: 2026-11-12. Responde a: **¿qué podemos construir con los datos que ya
> tengo, qué se desaprovecha y qué datos harían falta?** Basado en
> DATABASE_AUDIT.md, DATA_QUALITY.md y DATA_ANALYSIS.md. Los IDs `FI-*` remiten
> a FEATURE_IDEAS.md; los `ALG-*` a ALGORITHM_EVALUATION.md.

## 1. Respuesta corta

1. **Ya tienes un sustrato de primera:** 1 Hz continuo con FC, acelerómetro,
   temperatura en °C y RR nocturno con ~93 % de cobertura. Es más de lo que
   expone la API oficial de WHOOP (que solo da agregados).
2. **Lo que falta es tiempo, no datos.** 3 noches. Casi toda la inteligencia
   de la app está bien diseñada para abstenerse hasta tener histórico. Lo más
   valioso a corto plazo es **no perder histórico** y **acortar el arranque en
   frío** honestamente.
3. **Se desaprovecha:** temperatura gen5 en readiness, el estado de sueño de la
   banda como segundo opinador, los registros PIP v26, la FC de entrenos de
   fuerza (Hevy sin FC), el diario de hábitos (vacío) y tu exportación oficial
   de WHOOP (si la tienes).
4. **Para el siguiente nivel faltan:** etiquetas subjetivas diarias (RPE,
   bienestar, sueño percibido), registro de hábitos, y ≥ 60 noches.

## 2. Inmediato (implementable con los datos de hoy)

| ID | Oportunidad | Datos | Por qué ahora |
|---|---|---|---|
| O‑01 | **Archivo de sustrato "para siempre"** y re‑derivación desde `substrate_archive` | `substrate_archive` (ya escrito, 365 d aquí) | Cada día que sale de la ventana es irrecuperable para futuros algoritmos. El código ya lo prevé ("re-deriving archived history is the follow-up") |
| O‑02 | **Pantalla de "progreso de calibración"** por métrica (readiness 3/14, strain 2/3, CTL 3/14…) | notas `need_baseline` del payload | Ya están en `day_result`; hoy solo se ve "Calibrating N of 14" en el anillo |
| O‑03 | **Temperatura gen5 calibrada con tus noches** (banda de asentamiento medida) | `skin_temp_c` 1 Hz + `WRIST_ON/OFF`, `CHARGING_*` | La señal está al 100 % y en °C; hoy readiness la rechaza siempre (Q‑02) |
| O‑04 | **"I'm awake" como etiqueta de despertar** para medir el error del final automático (ALG‑S1) | `sleep_override` (`offset_ts == created_at`) | Ya ocurre en 2/3 noches; `band_sleep_state` no sirve para esto (sobreestima el final 0,5–2,7 h) |
| O‑05 | **Cribado de ritmo irregular solo en reposo** | RR + `dyn_accel_g` + `signal_quality_logvar` | Reduce falsos positivos (Q‑04) |
| O‑06 | **CTL/ATL que distingue "no llevada" de "descanso"** | `worn_min`, `wear.segments` | Corrige Q‑05 |
| O‑07 | **Importar tu exportación oficial de WHOOP** como *referencia de validación* (no como baseline) | `lib/import/whoop_import.dart` ya existe (BETA) | Permite comparar tu recovery/HRV/sueño con los de WHOOP noche a noche cuando haya solape. Requiere que tengas el ZIP de "My Data" |
| O‑08 | **Carga interna de fuerza** (sRPE) y tonelaje en la tendencia de carga | `strength_set`, `exercise_def`, `sessions.rpe` | 503 series; las series por grupo ya se muestran (`strength_summary.dart`); falta sumarlas a la carga |

## 3. Requiere más histórico (sin datos nuevos)

| ID | Oportunidad | Histórico mínimo | Fecha aproximada con uso continuo |
|---|---|---|---|
| O‑10 | Readiness personal calibrado | 14 noches + 14 de calibración | ~4 semanas |
| O‑11 | Baseline HRV con mediana/MAD 30 d y banda normal (Plews/Altini) | 14–30 noches | 2–4 semanas |
| O‑12 | Detección de cambios en RHR (CUSUM, ya implementado) | 7 noches | 1 semana |
| O‑13 | CTL/ATL/TSB descriptivos | 42 días para CTL estable | ~6 semanas |
| O‑14 | Efecto día de la semana (`weekdayEffect`, ya implementado) | ≥ 4 semanas | 1 mes |
| O‑15 | Sueño: deuda, necesidad, regularidad (SRI), cronotipo | 14 días con ≥ 2–3 libres | 2–3 semanas |
| O‑16 | Correlaciones entrenamiento ↔ HRV/RHR del día siguiente (`session_cost`) | ≥ 14 días con sesiones | 3–4 semanas |
| O‑17 | Anomalía multivariante (Mahalanobis) | 10 noches | ~2 semanas |
| O‑18 | Comparativas de periodos (mes vs. mes) | 2 meses | ~2 meses |
| O‑19 | Predicción experimental de readiness de mañana | ≥ 90 noches | ~3 meses |

## 4. Requiere datos nuevos

| Dato | Para qué | Cómo capturarlo | Coste para el usuario |
|---|---|---|---|
| RPE de sesión (Foster) | Carga interna sin FC (fuerza), validar strain | 1 toque al cerrar sesión (`sessions.rpe` ya existe, 0 % usado) | Muy bajo |
| Bienestar matinal (energía, agujetas, ánimo, 1–5) | Validar readiness contra algo que sientes | Tarjeta matinal → `journal_metric` | Bajo |
| Sueño percibido (1–5) | Validar detección y fases | Tarjeta matinal | Bajo |
| Cafeína/alcohol/última comida/pantalla | Análisis de hábitos | Etiquetas del diario (`journal`) | Bajo |
| FC durante fuerza | Strain real de las sesiones Hevy | Llevar la banda; emparejar sesión Hevy ↔ traza 1 Hz por horario | Ninguno |
| Rendimiento objetivo (ritmo, vatios, 1RM estimado) | Validar si readiness predice rendimiento | Hevy (cargas) o GPS | Ninguno |
| Peso corporal | Calorías, edad fisiológica | `imported_measurement` (báscula/HealthKit) | Bajo |

## 5. Lo que **no** se puede construir con este hardware

- SpO2 absoluto o relativo en gen5: el pipeline lo rechaza explícitamente
  ("the red and IR channels are one signal", `respiration.odi.note`).
- Fases de sueño con validez clínica: son estimaciones HRV+actigrafía.
- Pasos fiables desde 1 Hz (el contador del chip sí existe, con la salvedad de
  nombre que documenta el protocolo).
- ECG: WHOOP MG lo tiene; esta WHOOP 5.0 no (tablas `ecg_*` vacías).
- Temperatura corporal: es piel de muñeca. Solo vale como desviación propia.

## 6. Plan de re‑análisis

Repetir DATA_ANALYSIS.md con los mismos scripts cuando haya **30** y **90**
noches. En el de 30: comparar baselines (ALG‑R2), validar ventanas de sueño
contra diario (ALG‑S1), medir tasa de alertas. En el de 90: correlaciones y
predicción (FI‑E3). Registrar cada ejecución en PROGRESS.md.
