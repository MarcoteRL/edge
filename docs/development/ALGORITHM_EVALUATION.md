# Evaluación científica y técnica de los algoritmos

> Fecha: 2026-11-12. Base: ALGORITHMS.md (qué hace el código), DATA_ANALYSIS.md
> (qué hacen los datos), research/*.md (qué dice la literatura). Cada propuesta
> tiene ID estable (`ALG-*`) usado en IMPROVEMENT_BACKLOG.md y ROADMAP.md.
>
> Etiquetas: **Hecho** (verificado en código o datos) · **Hipótesis** (plausible,
> sin verificar) · **Propuesta**.
>
> Restricción de arquitectura: un cambio de fórmula va al paquete
> `openstrap_analytics`; la orquestación (qué se le pasa) va en
> `lib/compute/`. Ambos exigen subir `kAlgoVersion` si cambia una salida.

## Valoración global

| Área | Calidad del diseño | Fiabilidad con tus datos hoy | Principal debilidad |
|---|---|---|---|
| Señales base (RHR, RMSSD, resp.) | Alta: métodos publicados, limpieza RR, rechazo explícito | Alta (reproducido al 0–3 %) | RMSSD sensible a la cuantización de 1 Hz en el titular de latidos (declarado) |
| Readiness | Alta en transparencia; conservadora | El real abstiene; se muestra una estimación gris (FP‑CAL) con referencia poblacional | Arranque de 14+14 noches; el sueño no entra; temperatura nunca entra en gen5; la estimación no está validada |
| Strain diario | Buena; corrige el sesgo de "estar vivo" | Abstiene 3 días | Solo cardiovascular: la fuerza puntúa bajo |
| CTL/ATL | Fórmula correcta | Engañosa: días sin llevar = descanso | Q‑05 |
| Sueño (ventana) | Buena, con prioridad a la corrección del usuario y botón "I'm awake" | Inicio sin correcciones; final cerrado a mano en 2/3 noches | Final de la noche; puenteo de bloques vespertinos (BUG‑T01, abierto en analytics) |
| Sueño (fases) | Transparente, honesta con su κ | Baja (κ 0,13 declarado) | Profundo y vigilia |
| Longitudinal | Muy completa (CUSUM, Mahalanobis, MDC) | Sin datos | Falta una capa de tendencias visible |
| Cribado irregular | Prudente en lenguaje | Falsos positivos probables | Corre sobre RR diurno con movimiento |

---

## 1. Recovery / Readiness

### ALG‑R1 · Evaluar y validar las estimaciones de calibración (FP‑CAL)

1. **Hoy (Hecho, 2026‑11‑10, decisión del propietario):**
   `lib/compute/calibration_estimate.dart` muestra en gris un Recovery y un
   Strain *estimados* mientras los reales abstienen. Recovery: mismas entradas,
   signos y pesos que el composite, contra un centro/dispersión que mezcla una
   **referencia adulta genérica** (lnRMSSD 3,85 ± 0,50; RHR 57 ± 8; resp.
   14,5 ± 2,0) que vale 3 noches (`kCalibrationPriorNights`) con tus noches;
   z acotado a ±2. Strain: el mismo marcador neto pero con el nivel de reposo
   **poblacional** (0,20 FCR). Se calcula al leer, nunca se guarda ni se
   notifica. Es una relajación consciente del invariante 3 (DECISIONS.md D‑08).
2. **Fórmula:** `c = (3·c_ref + n·media)/(3+n)`,
   `s = sqrt((3·s_ref² + n·var)/(3+n))`, `z = clamp(signo·(x−c)/s, ±2)`.
3. **Riesgos medidos o razonados:**
   - La referencia es **entre personas**: una persona con HRV naturalmente alta
     sale "muy recuperada" las primeras noches por ser quien es, no por cómo
     está. Con n = 1–3 la referencia pesa 50–75 %.
   - Strain con Q poblacional: en tus días sin entreno, Q personal frente a
     0,20 cambia el strain hasta ~3× (DATA_ANALYSIS.md §4); con entreno real
     la diferencia es < 3 %.
4. **Propuesta A (validación, S):** cuando el Recovery real aparezca (noche
   15+), calcular también la estimación para esas mismas noches y registrar la
   concordancia (Spearman, error absoluto medio, % de noches en la misma banda
   de color). Si la concordancia es baja, el gris engaña. Script offline en
   `docs/development/analysis/`; sin cambio en la app.
5. **Propuesta B (alternativa, S):** desde la noche 5, sustituir la parte
   autonómica de la estimación por la señal intra‑persona de Plews
   (`readinessLnRmssd`, ya calculada: lnRMSSD frente a media 7 d ± SWC), que no
   depende de una referencia poblacional. Decidir con los datos de A.
6. **Dónde:** `calibration_estimate.dart` y `local_repository_impl.dart`
   (`getToday`). Sin bump (no toca el pipeline).
7. **Alternativa científica:** Plews et al. 2013; Buchheit 2014.
8. **Validación:** A sobre tus noches 15–45; tests de que la estimación nunca
   se escribe en `metric_series` (ya existen según PROGRESS.md).

### ALG‑R2 · Elegir el baseline con datos, no por convención (Propuesta, experimento)

1. **Hoy:** mediana/MAD de hasta 28 noches previas (**Hecho**).
2. **Experimento:** con ≥ 60 noches, comparar para HRV y RHR: (a) 28 d
   mediana/MAD, (b) 7 d media (Plews), (c) 60 d mediana/MAD, (d) EWMA
   winsorizada (`ewma_baselines.dart`). Métrica: estabilidad del z en noches
   "normales" (desviación de z en días sin entreno ni etiqueta) y sensibilidad
   a eventos etiquetados (alcohol, enfermedad, viaje) del diario.
3. **Dónde:** script offline en `docs/development/analysis/` (no en la app).
4. **Complejidad:** M. **Resultado esperado:** una decisión documentada en
   DECISIONS.md. Sin cambiar código hasta tener resultado.

### ALG‑R3 · Temperatura gen5 en readiness (Propuesta)

1. **Hoy:** gen5 no tiene banda de asentamiento ⇒ `settled_frac = NULL` ⇒
   `tempInput` rechaza siempre (**Hecho**, Q‑02).
2. **Fórmula propuesta:** definir la banda de gen5 con datos propios: muestras
   de `skin_temp_c` en la ventana de sueño, excluyendo 20 min tras cada
   `WRIST_ON` y los intervalos `CHARGING_ON..OFF`; *settled* = |x − mediana
   nocturna| ≤ k·MAD con k elegido para que noches limpias den ≥ 0,9.
3. **Dónde:** constante por familia en `openstrap_analytics`
   (`temp_circadian.dart`, donde viven las bandas de gen4/anillos). PR al
   paquete + re‑pin + bump.
4. **Limitaciones:** la temperatura de muñeca depende del ambiente y la ropa
   de cama. 5. **Complejidad:** M. 6. **Validación:** sobre ≥ 30 noches,
   fracción de noches aceptadas y correlación de la desviación con RHR en
   noches de enfermedad etiquetadas.

### ALG‑R4 · Signo de la temperatura (Hipótesis, ya identificada como RD‑05 en el paquete)

`tempInput` usa signo −1 (más caliente = peor). El propio código cita a Kräuchi:
una muñeca *más fría* por la noche puede indicar vasoconstricción, no
recuperación, y `glassBoxReadiness` usa |z|. **Propuesta:** usar |z| por
encima del MDC como penalización simétrica. Requiere ALG‑R3 primero.

### ALG‑R5 · Sueño como pilar visible, no como entrada oculta (Propuesta)

WHOOP mete el rendimiento de sueño dentro de Recovery. Aquí no entra (**Hecho**).
Mantenerlo fuera es más honesto (el sueño ya influye vía HRV/RHR y evita
doble conteo), pero el usuario no ve la relación. **Propuesta:** mostrar en el
detalle de readiness un bloque "lo que explica el sueño de anoche" con la
correlación personal sueño→z autonómico cuando haya ≥ 30 noches
(`journalNumericCorrelations` ya calcula Spearman con permutaciones). No
cambia la fórmula.

### ALG‑R6 · Intervalo de confianza en la puntuación (Propuesta)

`confidence` existe (0,3 + 0,15·entradas) pero no refleja la incertidumbre del
baseline. **Propuesta:** banda ± a partir de bootstrap de las noches del
baseline (200 réplicas, en el isolate) y mostrarla como rango en el detalle.
**Complejidad:** M. **Validación:** el rango se estrecha al crecer n.

---

## 2. HRV y RHR

### ALG‑H1 · Estabilidad de HRV (CV de 7 días) (Propuesta)

Plews 2012/2013: el coeficiente de variación semanal de lnRMSSD aporta
información distinta de la media (aumenta con fatiga/estrés no adaptativo).
`hrv_cv` ya existe como escalar diario (variación **intra**noche). Falta el CV
**entre noches**: `CV7 = SD(lnRMSSD_7d)/media(lnRMSSD_7d)`. Dónde:
`crossday_pipeline.dart` (orquestación) o función nueva en analytics.
Complejidad S. Validación: test con series sintéticas.

> **Implementado en el fork (iteración 3):** `lnRmssdCv7` en
> `lib/compute/fork/trends.dart`: `CV7 = 100·SD/media` de lnRMSSD de las
> últimas 7 noches, ausente con menos de 5 o con media ≤ 0. Solo noches del
> mismo método. Sintético únicamente.

### ALG‑H2 · Titular de HRV: media vs mediana de ventanas (Hecho + Propuesta)

El titular usa la **media** de ventanas; existe la **mediana** (`rmssd_nocturnal`).
En tus 3 noches difieren ~3 %. Propuesta: no cambiar; documentar en la UI qué
se muestra y usar la mediana para baselines si ALG‑R2 demuestra menor ruido.

---

## 3. Strain y carga

### ALG‑L1 · No llevar la banda no es descansar (Propuesta, P0 de integridad)

1. **Hoy:** `_denseDailyTrimp` (`lib/compute/crossday_pipeline.dart`) rellena
   con 0 los días sin TRIMP. El comentario lo justifica para no comprimir el
   calendario (**Hecho**). En esta base, 12 de 15 días son ceros ⇒ CTL/ATL
   presentes con confianza 0,36 aunque `ctlAtlTsb` exige 14 días "reales".
2. **Fórmula propuesta:** día con `worn_min < 600` (10 h) ⇒ *desconocido*.
   Desconocidos: no actualizan la EWMA pero el decaimiento sí avanza
   (`ctl ← ctl·(1−λ)` solo si el día fue llevado y sin carga; si es
   desconocido, mantener y marcar). Abstener si < 70 % de días conocidos en
   los últimos 42 (CTL) / 7 (ATL).
3. **Dónde:** `crossday_pipeline.dart` (pasar máscara de días conocidos) +
   `ctlAtlTsb` en analytics (aceptar `List<double?>`). Bump.
4. **Alternativa:** imputación por mediana de días llevados similares (**no**,
   viola invariante 3).
5. **Complejidad:** M. 6. **Validación:** tests con calendarios sintéticos
   (llevada 5/7, 3/7, vacaciones sin banda); el caso de esta exportación debe
   abstener.

### ALG‑L2 · Carga interna para fuerza: sRPE de Foster (Propuesta)

1. **Problema (Hecho):** strain es solo cardiovascular. Las 24 sesiones de
   fuerza importadas no tienen FC; con banda, una sesión de pesas sube poco la
   FC. WHOOP añadió "carga muscular" por el mismo motivo (fuente en
   STRAIN_RESEARCH.md).
2. **Fórmula:** `sRPE = RPE(CR‑10) × duración (min)` (Foster 2001). Además,
   tonelaje por grupo muscular desde `strength_set` (`reps × load_kg`,
   `exercise_def.muscles_json`).
3. **Dónde:** nuevo cálculo en analytics (`workout/`), pedir RPE al cerrar
   sesión (`sessions.rpe` existe y está vacío al 100 %).
4. **No mezclar** sRPE con strain en un único 0–21: mostrar "carga
   cardiovascular" y "carga muscular" por separado.
5. **Complejidad:** M. 6. **Validación:** correlación de sRPE con TRIMP en
   sesiones de cardio (Foster informa r ≈ 0,75–0,90 con TRIMP).

> **Corrección (iteración 1):** el RPE **ya se pide** al cerrar una sesión
> (`ui2/activity/summary.dart`, `LocalDb.setSessionRpe`). Falta usarlo
> (sRPE semanal) y comprobar si las sesiones de Hevy pueden recibirlo.

### ALG‑L3 · Edwards / tiempo en zonas como vista complementaria (Propuesta)

Edwards (1993): `Σ min_zona_i × i`. Es casi lo que ya hay en `zones` y no
requiere modelo exponencial. Útil para **distribución de intensidad**
(polarizado/piramidal). Solo presentación; S.

> **Implementado en el fork (iteración 3), ALG‑L2 y ALG‑L3:**
> `lib/compute/fork/load.dart`. `sessionRpeLoad` (RPE × min; sin RPE ⇒ null),
> `rpeLoadOf` (suma de la semana + nº de sesiones sin valorar: con alguna, el
> total es un suelo y se muestra como tal), `tonnageBy` (Σ reps × kg por
> grupo; una serie sin carga se cuenta, no suma 0 kg), `edwardsLoad` /
> `edwardsShares` (Σ min_zona × i; reparto 1‑2 / 3 / 4‑5). Aritmética pura,
> separada del strain (D‑09). **Sin cablear a pantalla todavía** (iteración
> 4, P‑07). Foster 2001 sigue marcada **G** en REFERENCES.md: sin verificar.

### ALG‑L4 · No usar ACWR como predictor de lesión (Decisión)

ACWR sufre acoplamiento matemático y su base teórica ha sido cuestionada
(Lolli 2019; Impellizzeri 2020/2021). **Decisión:** mostrar CTL/ATL/TSB
como descriptivos ("forma", "fatiga") sin umbrales de riesgo. Registrado en
DECISIONS.md D‑05.

### ALG‑L5 · FCmax observada (Hecho + Propuesta)

`zone_source` / `observed_max_hr.dart` ya preferirían una FCmax observada. Con
pocas sesiones intensas se usa la fórmula por edad. Propuesta: avisar en
zonas "FCmax estimada por edad" hasta tener ≥ 1 valor observado plausible.

---

## 4. Sueño

### ALG‑S1 · Validar el final de la noche con "I'm awake" (Propuesta, experimento)

**Hecho:** 2 de 3 noches se cerraron con el botón "I'm awake"
(`AppState.markAwakeNow`), y la banda siguió marcando sueño 0,5–2,7 h después.
**Experimento:** el botón ya es una etiqueta de despertar casi gratuita. Durante
30 noches: (1) seguir pulsándolo; (2) calcular para cada noche, **sin** la
corrección, dónde habría terminado la ventana automática (re‑derivar en una
copia o leer `sleep_session_candidates`); (3) error absoluto medio del final
automático frente a la pulsación. Requiere poder distinguir la pulsación de
una edición (DATA‑06). **Dónde:** análisis offline. **Complejidad:** S.
Queda abierto (PROGRESS.md, BUG‑T01) que la confirmación por FC compara contra
la mediana del mismo tramo y que la noche puede "puentear" un bloque quieto
vespertino ≤ 90 min, adelantando el inicio: medir también el error de inicio
con una etiqueta de "me acuesto" (FI‑B4).

### ALG‑S2 · Mostrar la incertidumbre de las fases (Propuesta)

El *stager* declara κ = 0,13 y VPP de profundo del 11 % (**Hecho**). En tus
noches el REM sale en 20–34 % del TST, por encima de lo típico en
polisomnografía (~20–25 %). **Propuesta:** en Sueño, mostrar fases como
rangos (`light_range_sec`, `deep_range_sec`, `rem_range_sec` **ya existen**
en `sleep_session_candidates`) y una etiqueta "estimación de muñeca". No
cambia la fórmula. S.

> **Corrección (iteración 1, rectificada en la 3):** las fases **ya se
> muestran como rango** (`_ranges`/`_rangeText` en
> `ui2/screens/sleep_detail.dart`, con `stageRanges` de analytics). Los
> `light_range_sec`… existen, pero no como columnas: son campos de `sleep_session_candidates.payload_json.sleep_json` (comprobado en una exportación real el 2026‑11‑12; la iteración 1 dijo por error que no existían).
> Lo pendiente es la jerarquía de la pantalla (UI_UX_AUDIT.md P‑05).

### ALG‑S3 · Consistencia de sueño útil antes del SRI completo (Propuesta)

SRI necesita ≥ 7 días (y Phillips usa 30). Mientras tanto: SD de hora de
acostarse / despertar en 7 días con mínimo 5 noches. Complejidad S.

> **Implementado en el fork (iteración 3):** `scheduleSdMin` en
> `lib/compute/fork/trends.dart`: desviación estándar **circular** (minutos)
> de la hora de acostarse o de despertar de las últimas 7 noches, ausente con
> menos de 5. Circular porque 23:50 y 00:10 distan 20 min.

### ALG‑S4 · Despertares (Hecho + Propuesta)

`awakenings` cuenta solo vigilias ≥ 5 min y el *stager* tiene 11 % de
sensibilidad en vigilia: casi siempre 0–1. La UI ya lo explica ("shorter ones
are invisible to a wrist"). Propuesta: no destacar el número; mostrar WASO.

---

## 5. Clínico

### ALG‑C1 · Cribado de ritmo irregular solo en reposo (Propuesta, P1)

**Hecho:** bandera = 1 en los 3 días sin noche, 0 en las 4 noches.
**Propuesta:** calcular `irregular_24h` solo sobre segmentos con
`dyn_accel_g` bajo (p. ej. < p25 del día) y `signal_quality_logvar` bajo,
mínimo 30 min de RR limpio; si no, abstener con nota. **Dónde:**
`analytics:clinical/irregular_rhythm.dart` (parámetro de máscara) +
orquestación en `onehz_pipeline.dart`. Bump. **Validación:** tasa de
banderas en días de solo‑día vs. noche; debe caer sin perder la noche.

### ALG‑C2 · RR en los topes (Hipótesis)

1 % de RR = 333 ms y 0,3 % = 2400 ms exactos. Comprobar en el protocolo si son
el rango aceptado del decodificador (`rrIntervalsMs`, "ACCEPTED") o
saturación de la banda. Si son topes, `correctRr` debería tratarlos como
artefactos explícitos. Complejidad S (investigación).

---

## 6. Longitudinal

### ALG‑T1 · Motor de tendencias explicable (Propuesta, P1)

1. **Hoy:** existen piezas (MDC, percentiles propios, CUSUM, Mahalanobis,
   `weekdayEffect`) pero no una vista de "¿cómo evoluciono?".
2. **Fórmula:** para cada métrica clave (lnRMSSD, RHR, resp., TST, strain):
   medias 7/14/30/90 d; pendiente Theil‑Sen 30 d (`theilSen` ya en
   `analytics:util.dart`) con IC por bootstrap; cambio "significativo" solo si
   |Δ| > max(MDC, SWC = 0,5·SD intra‑individual) **y** el IC excluye 0.
3. **Dónde:** función pura en analytics (`human/`), llamada desde
   `crossday_pipeline.dart`; resultado en `baselines.crossday`.
4. **Complejidad:** M. 5. **Validación:** series sintéticas con escalón y
   rampa; debe callar en ruido blanco (tasa de falsos positivos < 5 %).

#### ALG‑T1 · Implementación en el fork (iteración 3, 2026‑11‑12)

`lib/compute/fork/trends.dart` (`trendOf`), servido por
`fork/trend_service.dart` (`Isolate.run` + caché por clave, última fecha de la
serie, día y `kAlgoVersion`). Al leer, sin persistir (D‑15).

- **Problema:** decir "has cambiado" solo cuando el cambio supera el ruido.
- **Fórmula.** Serie diaria `x_d` (un valor por día local; los huecos son
  huecos). Medias de 7/14/30/90 días naturales, cada una ausente con menos de
  4/9/18/54 valores (≥ 60 %). *Reciente* = media de los últimos 7 días (≥ 4
  valores). *Habitual* = mediana de los 28 días **anteriores** a esos 7
  (≥ 14 valores). `Δ = reciente − habitual`.
  `MDC = 1,96·√2·(MADσ_habitual / √n_reciente)`; `SWC = 0,5·SD_habitual`.
  **Relevante** ⇔ `|Δ| > max(MDC, SWC)` y el IC 95 % por bootstrap de Δ
  (500 remuestreos de ambas ventanas) excluye 0 (D‑17). Pendiente: Theil‑Sen
  sobre los últimos 30 días (≥ 15 valores, x = número de día) con IC 95 % por
  bootstrap de pares; se informa aparte.
- **Ventanas por variable [Hipótesis]:** las mismas para HRV, RHR, sueño y
  carga en esta primera versión. Justificación: 7 días promedia el ciclo
  semanal (relevante para sueño y carga) y es la ventana de Plews para HRV;
  28 días son cuatro ciclos semanales completos. Ajustarlas por variable
  requiere ≥ 60 noches reales (ALG‑R2).
- **Baseline lento:** el habitual no contiene la semana reciente y es una
  mediana: una semana enferma no se avala a sí misma, y tarda ~2 semanas en
  empezar a moverlo.
- **Entrada ausente/escasa/atípica:** `relevant = null` con nota
  `need_baseline:have=H,need=N`; habitual plano (MAD = 0) ⇒ `no_dispersion`;
  valores no finitos y días posteriores a hoy se ignoran; un día repetido
  conserva el último valor.
- **n mínimo:** 18 días con valor repartidos en 35 naturales. Con menos no
  hay veredicto. Motivo: 2 parámetros (centro, dispersión) del habitual con
  ≥ 14 valores; coste de un falso positivo (alarma) mayor que el de un falso
  negativo (silencio una semana más).
- **Coste:** ~0,2 M pendientes por pares por serie; en isolate, cacheado.
- **Validación (solo sintética, `test/fork_trends_test.dart`):** escalón,
  rampa, ruido blanco, huecos, días repetidos y cambio de hora. Tasa de falsos
  positivos en ruido blanco y resultado del run: ver PROGRESS.md. **Ganar en
  sintético no valida para producción.**
- **Limitaciones:** sin datos reales; ventanas iguales para todas las
  variables; el bootstrap con 4–7 valores recientes subestima la anchura del
  IC (por eso además se exige el MDC).

### ALG‑P1 · Dos periodos elegidos por el usuario (Hecho 2026‑11‑13, sin validar con datos reales)

- **Qué:** `periodChange` en `lib/compute/fork/trends.dart`; servicio
  `TrendService.periods`; pantalla `PeriodLabScreen`.
- **Regla [Decidido, D‑20]:** Δ = media(después) − media(antes). Relevante si
  \|Δ\| > max(1,96 · SD agrupada · √(1/nₐ + 1/n_b), 0,5 · SD(antes)) y el IC
  95 % por bootstrap (500 remuestreos de ambos periodos) excluye 0.
- **n mínimo:** 60 % de los días de cada periodo y nunca menos de 4
  (7 → 4, 14 → 8, 28 → 17). Con menos: `need_baseline:have=H,need=N` del
  periodo más corto, y la pantalla dice cuántos días hay y cuántos faltan.
- **Abstenciones:** dos periodos planos (SD agrupada 0) ⇒ `no_dispersion`,
  sin veredicto. Días posteriores al último guardado simplemente no existen.
- **Validación (solo sintética, `test/fork_trends_test.dart`):** escalón en
  la fecha, ruido blanco con 200 semillas (se exige < 30 falsos positivos; el
  valor nominal es ~10), periodo escaso, periodos planos, periodo que se sale
  del final de la serie. **Ganar en sintético no valida para producción.**
- **Limitaciones [Comprobado en el código]:** trata las noches como
  independientes (no lo son del todo: la autocorrelación hace el umbral algo
  optimista); con 7 días por lado la potencia es baja y casi todo dirá "sin
  diferencia"; no corrige por comparaciones múltiples si el usuario prueba
  muchas fechas; describe, no atribuye causa. **[Recomendación]** medir la
  tasa real de falsos positivos con ≥ 60 noches antes de fiarse de 7 días.

### ALG‑T2 · Guardar el historial de baselines (Propuesta)

`baselines` guarda una fila por clave (se sobrescribe). Para explicar "por qué
cambió mi readiness" hace falta el baseline de cada día. El payload de
`day_result` ya incluye `baselines{...}` por día (**Hecho**), así que basta con
**leerlo**, no hace falta tabla nueva. Documentado en DATA_MODEL.md.
