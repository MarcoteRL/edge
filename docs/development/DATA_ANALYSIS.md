# Análisis estadístico y experimentos sobre datos reales

> Fecha: 2026-11-12 · Exportación WHOOP 5.0, `kAlgoVersion 120`.
> Entorno: Python 3 + pandas/numpy sobre una **copia de solo lectura**
> (`sqlite3 ...?mode=ro`). Ningún dato salió del equipo de trabajo ni se
> escribió en la exportación. Scripts: `docs/development/analysis/` (reciben
> la ruta de la base como argumento; no contienen datos).
>
> **Límite de todo este documento:** 3 noches y 4 días vivos. Sirve para
> comprobar que el código hace lo que dice, **no** para validar que las
> métricas sean fisiológicamente correctas ni para estimar efectos.

## 1. Inventario numérico

Ver DATA_QUALITY.md §1–2 y DATABASE_AUDIT.md §1. Resumen: 275 918 segundos,
152 896 latidos, 3 noches completas, 25 sesiones (24 sin FC).

## 2. Reproducción de métricas desde el crudo

Objetivo: comprobar que lo almacenado en `metric_series` / `day_result` se
obtiene de `decoded_onehz` / `decoded_rr` con la fórmula documentada.

| Métrica | Método de reproducción | Error relativo (3 noches) | Veredicto |
|---|---|---|---|
| RHR (`rhr`) | Mínimo de la media móvil de 30 min de FC > 0 dentro de la ventana de sueño | **0,0 %** las 3 | Coincide exactamente |
| `rhr_nocturnal` | — | idéntico a `rhr` | Escalar redundante (Q‑06) |
| RMSSD (`rmssd`) | Ventanas de 5 min, regla de Malik 20 %, ≥ 20 diferencias, media de ventanas | −2,1 % a −2,9 % | Coincide dentro de lo esperable (la app usa además `correctRr` de Lipponen) |
| RMSSD, mediana de ventanas | igual, mediana | −6,0 % a +0,8 % | La elección media/mediana mueve el valor ~3 % |
| TRIMP (`trimp`) | Banister por minuto de vigilia, `x = (FC−RHR)/(FCmax−RHR)`, coeficientes 0,64·e^(1,92x) | 0,0 % a 0,4 % | Coincide; usa los coeficientes del perfil configurado (con los otros el error es 24–27 %) |
| Nivel de reposo (`quiet_hrr`) | Mediana de %FCR por minuto de vigilia | 0,000 | Coincide exactamente |
| Cobertura RR nocturna | Σ RR / duración de la ventana | 0,93–0,94 | Coherente con `coverage.rr_coverage` |

**Conclusión:** la cadena crudo → métrica es determinista y la documentación
del paquete de analítica describe lo que realmente se ejecuta. No se
detectaron errores de cálculo.

## 3. Ventana de sueño: app frente a la propia banda

`band_sleep_state` (estado 2 = "dormido" según el firmware) comparado con la
ventana final usada por la app:

| Medida | Noche 1 (auto) | Noche 2 ("I'm awake") | Noche 3 ("I'm awake") |
|---|---|---|---|
| % de la ventana que la banda marca "dormido" | 90 % | 96 % | 93 % |
| % de las 6 h previas / 3 h posteriores marcadas "despierto" | 94 % | 95 % | 95 % |
| Inicio: banda − app | +9 min | +5 min | −2 min |
| Final: banda − app | +84 min | +29 min | +161 min |

Las noches 2 y 3 terminan donde pulsaste "I'm awake" (`offset_ts ==
created_at`, inicio = el detectado), así que su final es una **referencia
real** de despertar (con el retraso hasta pulsar).

Lectura: en el **inicio** coinciden (la banda va unos minutos tarde, como
documenta el protocolo). En el **final**, la banda sigue marcando sueño entre
0,5 y 2,7 h **después de que dijeras que estabas despierto**. Su envolvente no
distingue quedarse quieto en la cama de dormir y no sirve como hora de
despertar sin más. El uso actual es seguro: `analytics:sleep/band_offset.dart`
solo **recorta** cuando la banda pasa a despierto al final ("corroboration,
never a source"), así que esta sobreestimación no lo afecta. Pero descarta
usar la envolvente para alargar noches o para validar la ventana automática
de la noche 1. **Experimento propuesto:** ALG‑S1.

## 4. Simulación: strain con nivel de reposo personal frente a poblacional

El strain diario resta un "coste de estar despierto" calculado con el nivel de
reposo **personal** (`personalQuietWakingHrr`, mediana móvil de 28 días). La
app abstiene hasta tener 3 días. Simulación con la fórmula guardada
(`strainScoreFromSeries`: minutos ≥ 40 % FCR nunca se compensan; el resto se
compensa contra Q y se acota a 0; mapa log 0–21, C = 15, máx. 400):

| Día | Minutos ≥ 40 % FCR | Strain con Q del propio día frente a Q = 0,20 (poblacional) |
|---|---:|---|
| Día completo A (sin entreno) | ~10 | ~3× mayor con Q personal; ambos en la franja baja |
| Día completo B (con entreno) | ~100 | Diferencia < 3 % |
| Día parcial C | ~10 | ~1,3× mayor con Q personal |

(Valores absolutos omitidos a propósito: son datos personales.)

Lectura: con un entrenamiento real ambos Q dan casi lo mismo; en días sin
ejercicio, Q decide si el día marca "casi nada" o "actividad ligera". **El valor de Q importa más en los
días tranquilos**, que son la mayoría. Limitaciones: usa la Q del mismo día
(la app usa la mediana de días previos), 3 días, sin referencia de esfuerzo
percibido. No es una validación.

## 5. Experimento: cribado de ritmo irregular

| Tipo de día | Días | Días con `irregular_rhythm_flag = 1` |
|---|---:|---:|
| Solo datos diurnos (sin noche) | 3 | 3 |
| Con noche completa | 4 | 0 |

Combinado con Q‑01 (1 % de RR en el tope de 333 ms) y la cobertura diurna de RR
de ~25 %, el patrón apunta a falsos positivos por artefactos de movimiento. No
hay ECG para confirmarlo. Propuesta: ALG‑C1.

## 6. Sensibilidad y datos incompletos

| Situación | Comportamiento observado | Valoración |
|---|---|---|
| Baseline corto | Readiness, strain, illness, anomaly abstienen con nota `need_baseline` | Correcto (invariante 3) |
| Día parcial sin noche | RHR/HRV `NULL`; actividad sí | Correcto |
| Temperatura con calentamiento | gen5 sin banda de asentamiento → rechazada en readiness | Conservador; deja una señal sin usar |
| Días no llevados en CTL/ATL | Se cuentan como carga 0 | **Incorrecto conceptualmente** (Q‑05) |
| Corrección manual de sueño | Re‑deriva con `flags = SLEEP_MANUAL` | Correcto |

## 7. Lo que no se pudo hacer (y por qué)

- Validar readiness frente a rendimiento o frente a WHOOP: no hay readiness
  (abstiene) ni exportación oficial de WHOOP importada.
- Correlaciones sueño → recuperación, entreno → HRV: n = 3.
- Comparar algoritmos alternativos de baseline (EWMA vs. mediana/MAD,
  ventanas 7/14/28/60): requiere ≥ 30–60 noches.
- Detectar anomalías: requiere ≥ 10 noches.

Plan para repetir este análisis con más datos: DATA_OPPORTUNITIES.md §4.
