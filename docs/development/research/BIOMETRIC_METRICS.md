# Inventario de métricas biométricas: obtenidas, derivadas, estimadas, no disponibles

> Fecha: 2026-11-12 · Banda: WHOOP 5.0 (gen5). Para WHOOP 4.0 cambia la fila de
> SpO2 y temperatura (ver nota final). Columnas de frecuencia y cobertura
> medidas en la exportación real (DATA_QUALITY.md).

| Métrica | Clase | Fuente | Frecuencia | Cobertura real | Nota |
|---|---|---|---|---|---|
| FC | **Obtenida** | `decoded_onehz.hr` | 1 Hz | 99,9 % | Óptica de muñeca |
| Intervalos RR | **Obtenida** | `decoded_rr.rr_ms` | latido a latido (hasta 4/s) | ~93 % noche, ~25 % día | Pulso (PRV), no ECG |
| Aceleración 3 ejes | **Obtenida** | `ax, ay, az` | 1 Hz | 100 % | Insuficiente para contar pasos por la marcha |
| Movimiento dinámico | **Obtenida** | `dyn_accel_g` | 1 Hz | 100 % | |
| Calidad de señal óptica | **Obtenida** | `signal_quality_logvar` | 1 Hz | 100 % | Infrautilizada |
| Temperatura de piel | **Obtenida** (°C) | `skin_temp_c` | 1 Hz | 100 % (80 % en rango de piel) | Muñeca, no corporal |
| Otros termistores | **Obtenida, semántica no verificada** | `temp_ch2_c`, `temp_ch3_c` | 1 Hz | 100 % | |
| Contador de pasos | **Obtenida, semántica inferida** | `step_count` | 1 Hz (acumulado) | 100 % | Nombre heredado de clientes de terceros |
| Clase de actividad | **Obtenida** | `activity_class` | 1 Hz | 95 % "no clasificado" | |
| Estado de sueño de la banda | **Obtenida** | `band_sleep_state` | 1 Hz | 100 % | Envolvente sin fases |
| Ventana PPG cruda (PIP v26) | **Obtenida, no consumida** | `raw_archive_frames` | episodios de 40 s | — | 25 muestras ópticas por registro |
| Batería, carga, puesta/quitada | **Obtenida** | `band_events`, `band_battery` | por evento | — | |
| RHR | **Derivada** | media mínima 30 min en sueño | nocturna | 3/3 noches | |
| HRV (RMSSD, SDNN, pNN50) | **Derivada** | ventanas de 5 min | nocturna | 3/3 | |
| LF/HF, PRSA DC/AC | **Derivada** | espectral / PRSA | nocturna | 3/3 | Interpretación autonómica discutida |
| Frecuencia respiratoria | **Estimada** | pico RSA del RR | nocturna | 3/3 | |
| Caída nocturna de FC (dip) | **Derivada** | día vs noche | diaria | 3/3 | |
| Estrés (Baevsky) | **Estimada** | histograma RR | diaria | 3/3 | |
| TRIMP | **Derivada** | FC + RHR + FCmax | diaria/sesión | 3/3 | |
| Strain 0–21 | **Estimada** | TRIMP neto | diaria/sesión | 0/8 (abstiene) | |
| Readiness 0–100 | **Estimada** | composite | diaria | 0/8 (abstiene) | |
| Ventana de sueño, TST, eficiencia | **Estimada** | acelerómetro + FC | nocturna | 3/3 | 2/3 cerradas con "I'm awake" |
| Fases de sueño | **Estimada (baja fiabilidad)** | *stager* cardiorrespiratorio | épocas 30 s | 3/3 | κ 0,13 declarado |
| Calorías | **Estimada** | Keytel + Mifflin | diaria | 3/8 | |
| VO2max | **Estimada** | modelo no‑ejercicio / ratio FC | — | — | |
| Edad fisiológica | **Estimada** | 9 contribuyentes | — | — | Módulo del fork |
| Ciclos de sueño | **Estimada** | fractal sobre RMSSD | nocturna | 3/3 | |
| Apnea (CVHR) | **Estimada, cribado** | ciclos de FC | nocturna | 3/3 | No es IAH |
| Ritmo irregular | **Estimada, cribado** | Poincaré + pNN70 | diaria | 7/8 | Falsos positivos probables (Q‑04) |
| **SpO2** | **No disponible** en gen5 | — | — | 0 % | El pipeline lo rechaza; WHOOP oficial lo calcula en su nube |
| **ECG** | **No disponible** en 5.0 | — | — | — | Solo MG |
| **Presión arterial** | **No disponible** | — | — | — | WHOOP MG la estima con calibración en su app |
| **Carga muscular de WHOOP** | **No disponible** | — | — | — | Propietaria; sustituir por sRPE/tonelaje |
| **Scores oficiales de WHOOP** | **No disponibles sin suscripción** | Solo vía exportación "My Data" si se tiene | — | — | `whoop_import.dart` |

Nota WHOOP 4.0: añade `skin_temp_raw` (ADC), `spo2_red_raw`/`spo2_ir_raw`
(permiten un índice de desaturación **relativo**), `ambient_raw` y `on_wrist`.
