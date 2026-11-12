# Glosario

| Término | Significado en este proyecto |
|---|---|
| **1 Hz / sustrato** | Registro por segundo de la banda (`decoded_onehz`) + latidos (`decoded_rr`). Todo se deriva de aquí |
| **ACK / HISTORY_END** | Token de 8 bytes que la app devuelve a la banda tras guardar; la banda entonces borra su flash |
| **`algo_version` / `kAlgoVersion`** | Versión de la analítica que produjo un día. Subirla re‑deriva los días con sustrato vivo |
| **Baseline** | Tu referencia personal para una métrica (mediana + MAD de las noches previas, normalmente 28) |
| **Banda de asentamiento (settle band)** | Rango que define cuándo la temperatura de piel ya se estabilizó tras ponerse la banda. gen5 no tiene |
| **Calibración (FP‑CAL)** | Estimación gris de Recovery/Strain mientras no hay baseline; usa una referencia poblacional |
| **CTL / ATL / TSB** | Carga crónica (EWMA 42 d), aguda (7 d) y su diferencia ("forma") |
| **Día (`day_id`)** | Fecha local, medianoche a medianoche. La noche pertenece al día en que te despiertas |
| **Driver** | Contribución de cada entrada al readiness, mostrada para explicar el número |
| **Finalizado** | Día bloqueado 48 h después de su último registro |
| **FCR (%HRR)** | Fracción de reserva cardíaca: `(FC − RHR)/(FCmax − RHR)` |
| **gen4 / gen5** | WHOOP 4.0 / WHOOP 5.0 y MG (formatos de registro distintos) |
| **I'm awake** | Botón de Home que cierra la noche ahora (`AppState.markAwakeNow`) |
| **MAD** | Desviación absoluta mediana; ×1,4826 ≈ SD robusta |
| **MDC** | Cambio mínimo detectable: por debajo, el cambio es ruido de medida |
| **`Metric<T>`** | Envoltorio de toda métrica: valor, confianza, tier, entradas, nota |
| **`need_baseline:have=H,need=N`** | Nota estándar cuando falta histórico |
| **Nivel de reposo (quiet HRR)** | Mediana de %FCR en tus minutos despiertos; lo que "cuesta" estar despierto |
| **PIP (v26)** | Registro gen5 con una ventana de 25 muestras ópticas (PPG); archivado, sin uso |
| **PRV** | Variabilidad del pulso (óptica de muñeca); no es HRV de ECG |
| **Readiness / Recovery** | Puntuación 0–100 del estado autonómico frente a tu baseline |
| **RHR** | FC en reposo: media más baja de 30 min dentro del sueño |
| **RMSSD / lnRMSSD** | HRV de dominio temporal (y su logaritmo, la forma usada para baselines) |
| **RSA** | Arritmia sinusal respiratoria; de ella sale la frecuencia respiratoria |
| **sRPE** | Esfuerzo percibido (0–10) × minutos (Foster) |
| **SRI** | Índice de regularidad del sueño (Phillips 2017) |
| **Strain** | Carga cardiovascular del día en 0–21 sobre tu nivel de reposo |
| **SWC** | Cambio mínimo relevante: 0,5 × SD intra‑individual |
| **Tier** | `auth`, `high`, `estimate`, `relative`: nivel de evidencia de una métrica |
| **TRIMP** | Impulso de entrenamiento de Banister |
| **Vista `v_*`** | Vistas SQL permitidas al coach; nunca tablas base |
