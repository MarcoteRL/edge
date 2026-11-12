# Catálogo de funcionalidades nuevas

> Fecha: 2026-11-12. Contrastado con lo que ya existe (FEATURES.md) y con lo que
> permiten los datos reales (DATA_OPPORTUNITIES.md). Sustituye y amplía
> `FEATURE_PROPOSALS.md` (FP‑01…FP‑06 siguen vigentes allí).
>
> Columnas: **Datos** = qué necesita · **Viab.** = viabilidad técnica (A/M/B) ·
> **Cx** = complejidad (S/M/L) · **Dif.** = valor diferencial frente a WHOOP
> (A/M/B) · **Pri.** = P0–P3 (ROADMAP.md).
> "Ya hay pieza" = el algoritmo existe en analytics y falta producto.

## A. Inteligencia de recuperación

| ID | Funcionalidad | Problema que resuelve | Beneficio | Datos | Viab. | Cx | Dependencias | Dif. | Pri. |
|---|---|---|---|---|---|---|---|---|---|
| FI‑A1 | **Recomendación diaria de intensidad explicada** | "¿Qué hago hoy?" no tiene respuesta | Decisión en 5 s con su porqué | readiness, drivers, CTL/ATL, sueño | A | M | ALG‑R1, ALG‑L1, UX P‑01 | A (explicable) | P1 |
| FI‑A2 | Validar la estimación de calibración (FP‑CAL, **ya existe**) y, si falla, sustituir su parte autonómica por Plews intra‑persona | La estimación usa una referencia poblacional sin validar | Que el gris no engañe | estimación + real desde la noche 15 | A | S | ALG‑R1 | M | P1 |
| FI‑A3 | Detección de recuperación insuficiente sostenida | Un mal día no importa; cinco sí | Aviso temprano de fatiga | z autonómico, ALG‑T1 | A | M | 14+ noches | M | P2 |
| FI‑A4 | HRV frente a baseline con banda y CV 7 d | La flecha no dice nada | Interpretación correcta del ruido | lnRMSSD | A | S | ALG‑H1, UX P‑02 | M | P1 |
| FI‑A5 | Fatiga acumulada (TSB + autonómico) | Carga y respuesta se miran por separado | Ver si la carga "te está costando" | CTL/ATL, z autonómico | M | M | ALG‑L1, 6 semanas | A | P2 |
| FI‑A6 | Días óptimos para entrenar (patrón semanal) | Planificar la semana | Elegir el día duro | readiness por día de semana | M | S (ya hay `weekdayEffect`) | 4+ semanas | M | P3 |
| FI‑A7 | Relación descanso → rendimiento | ¿Me sirve dormir más? | Motivación con evidencia propia | sueño, cargas Hevy / ritmos | M | M | FI‑C6, 60+ días | A | P3 |

## B. Inteligencia del sueño

| ID | Funcionalidad | Problema | Beneficio | Datos | Viab. | Cx | Dep. | Dif. | Pri. |
|---|---|---|---|---|---|---|---|---|---|
| FI‑B1 | Consistencia de horario (SD 7 d → SRI) | Regularidad invisible | Hábito accionable | inicio/fin | A | S | ALG‑S3 | M | P1 |
| FI‑B2 | Deuda de sueño con noches libres etiquetadas | El coach no arranca sin noches libres | Necesidad personal antes | TST + etiqueta "sin alarma" | A | S | FI‑B4 | M | P2 |
| FI‑B3 | Recomendación de horario (acostarse/levantarse) | Ya existe pero oculto y bloqueado | Plan nocturno | coach de sueño | A | S | FI‑B2 | B | P2 |
| FI‑B4 | **Tarjeta matinal (10 s)**: hora real de levantarse, sueño percibido 1–5, energía 1–5, noche libre sí/no | No hay verdad de referencia para validar nada | Valida sueño y readiness; alimenta correlaciones | `journal_metric` (existe) | A | S | — | A | **P1** |
| FI‑B5 | Segunda opinión de la banda **solo para el inicio** | Inicio de noche sin referencia | Corrección guiada del inicio | `band_sleep_state` (fiable al inicio, sobreestima el final: DATA_ANALYSIS §3) | A | S | — | B | P3 |
| FI‑B6 | Sueño en días de entreno vs descanso | ¿Entrenar tarde me quita sueño? | Ajuste de horario | sesiones + sueño | A | S | 30+ días | M | P2 |
| FI‑B7 | Patrones que perjudican la recuperación (hora de cena, pantalla, alcohol) | Causas invisibles | Cambios concretos | diario + RHR/HRV | M | M | FI‑D1, 30+ días | A | P2 |

## C. Inteligencia del entrenamiento

| ID | Funcionalidad | Problema | Beneficio | Datos | Viab. | Cx | Dep. | Dif. | Pri. |
|---|---|---|---|---|---|---|---|---|---|
| FI‑C1 | **Carga muscular (sRPE + tonelaje por grupo)**. Ya existe el recuento de series de trabajo por grupo en 7 d (`lib/data/strength_summary.dart`, Home); falta carga interna (sRPE) y tonelaje en la tendencia de carga | La fuerza puntúa bajo en strain | Carga real del gimnasio | `strength_set`, RPE | A | M | ALG‑L2 | A | P1 |
| FI‑C2 | Carga semanal con comparación a 4 semanas | Sin visión de semana | Progresión controlada | TRIMP, sRPE | A | S | ALG‑L1 | M | P1 |
| FI‑C3 | Distribución de intensidad (polarizado/piramidal) | Entrenar siempre "a medias" | Mejor estructura | zonas | A | S | — | M | P2 |
| FI‑C4 | Detección de sobrecarga (monotonía de Foster + respuesta autonómica) | Picos de carga sin aviso | Prevenir semanas malas | carga diaria, z | M | M | ALG‑L1, 4+ semanas | M | P2 |
| FI‑C5 | Evolución de la capacidad cardiovascular (FC a ritmo/potencia fija, recuperación de FC, VO2max estimado) | Progreso aeróbico invisible | Ver mejora real | sesiones con GPS/cadencia, `hrr_bpm` | M | M | sesiones repetidas | A | P2 |
| FI‑C6 | Comparación entre sesiones del mismo tipo | ¿Hoy fue más fácil? | Progreso por ejercicio | Hevy + traza FC | A | M | llevar la banda en el gimnasio | A | P2 |
| FI‑C7 | ~~Emparejar sesiones Hevy con la traza 1 Hz~~ **Hecho** por FP‑HEVY (se adjunta a la sesión de banda solapada) | — | — | — | — | — | — | — | — |

## D. Análisis de hábitos

| ID | Funcionalidad | Problema | Beneficio | Datos | Viab. | Cx | Dep. | Dif. | Pri. |
|---|---|---|---|---|---|---|---|---|---|
| FI‑D1 | Etiquetas rápidas: cafeína (hora), alcohol (unidades), última comida, hidratación, estrés percibido | Diario vacío | Base para correlaciones | `journal` | A | S | — | M | P1 |
| FI‑D2 | Correlaciones explicadas con n, efecto y p ajustada | Correlaciones engañosas | Saber qué te afecta | `journalCorrelations` (ya hay pieza) | A | S | 30+ días | A | P2 |
| FI‑D3 | Doble toque en la banda = marcador ("café", "estrés") | Registrar cuesta | Registro sin móvil | `band_events.DOUBLE_TAP` | M | M | gestos (existe) | A | P3 |
| FI‑D4 | Efectos con desfase (alcohol → noche, cafeína tarde → sueño) | Causas desplazadas | Atribución correcta | `journalTagLagDays` (ya hay pieza) | A | S | FI‑D1 | M | P2 |

## E. Inteligencia personalizada

| ID | Funcionalidad | Problema | Beneficio | Datos | Viab. | Cx | Dep. | Dif. | Pri. |
|---|---|---|---|---|---|---|---|---|---|
| FI‑E1 | Motor de tendencias 7/14/30/90 con significancia | "¿Cómo evoluciono?" | Señal, no ruido | todas | A | M | ALG‑T1 | A | P1 |
| FI‑E2 | Alertas inteligentes (persistencia + MDC + confianza) | Alertas de un día | Menos y mejores avisos | CUSUM, Mahalanobis (ya hay piezas) | A | M | FI‑E1 | M | P2 |
| FI‑E3 | Predicción experimental de readiness de mañana | Planificar | Anticipar | 90+ noches, carga, sueño | B | L | FI‑B4 | M | P3 |
| FI‑E4 | Recomendaciones explicables y registradas (qué se recomendó, si se siguió, qué pasó) | Sin bucle de aprendizaje | Medir si las recomendaciones sirven | `recommendation_log` (DATA_MODEL §4) | M | M | FI‑A1 | **A** | P2 |
| FI‑E5 | Validación personal del score ("¿cómo te sientes?" vs readiness) | Confianza ciega | Saber si el score te sirve | FI‑B4 | A | S | 30 días | **A** | P1 |
| FI‑E6 | Informe semanal automático (local, compartible) | Revisión manual | Resumen accionable | todas | A | M | FI‑E1 | M | P2 |
| FI‑E7 | Análisis mensual de evolución | Largo plazo | Ver progreso | todas | A | M | FI‑E1, 2 meses | M | P3 |

## F. Funcionalidades diferenciales

| ID | Funcionalidad | Problema | Beneficio | Datos | Viab. | Cx | Dep. | Dif. | Pri. |
|---|---|---|---|---|---|---|---|---|---|
| FI‑F1 | **Archivo indefinido + re‑derivación del histórico** | Algoritmos nuevos no llegan al pasado | Tu historia mejora con cada versión | `substrate_archive` | A | M | — | **A** | **P0/P1** |
| FI‑F2 | Experimentos personales (N‑of‑1): "acostarme 23:00 durante 14 días" con comparación A/B y bloques alternos | Cambiar hábitos a ciegas | Evidencia propia | diario + métricas | A | M | FI‑E1 | **A** | P2 |
| FI‑F3 | Comparación de periodos (cualquier rango vs cualquier rango) | Preguntas ad hoc | Exploración libre | `metric_series` | A | S | — | M | P2 |
| FI‑F4 | Laboratorio de métricas: fórmulas propias sobre `metric_series` (p. ej. RHR − media 30 d) | Personalización | Métricas a medida | `metric_series` | M | L | — | A | P3 |
| FI‑F5 | Constructor de dashboard (elegir tarjetas y orden) | Un dashboard para todos | Foco personal | — | M | L | — | M | P3 |
| FI‑F6 | Motor de recomendaciones configurable (reglas visibles y editables) | Caja negra | Control total | FI‑E4 | M | L | FI‑A1 | A | P3 |
| FI‑F7 | Exportación completa analítica (Parquet/CSV por día + diccionario) | Análisis fuera de la app | Notebook propio | todas | A | S | `csv_export.dart` | M | P2 |
| FI‑F8 | Modo validación frente a WHOOP (import "My Data" + gráfico de concordancia Bland‑Altman) | ¿Mis números se parecen? | Confianza / calibración | `whoop_import.dart` | A | M | export oficial | A | P2 |
| FI‑F9 | Diagnóstico de sincronización (FP‑05 ampliado con cobertura RR/día y huecos) | Problemas invisibles | Fiabilidad | `sync_ledger`, coverage | A | M | — | M | P2 |
| FI‑F10 | Mapa de calidad de datos por día (cobertura, artefactos, temp. asentada) | Saber cuándo fiarse | Contexto de cada número | `coverage`, `wear` | A | S | — | M | P2 |

## Las 10 con mayor potencial

| # | ID | Por qué |
|---|---|---|
| 1 | FI‑F1 | Protege todo lo demás: sin histórico re‑derivable, nada longitudinal madura |
| 2 | FI‑B4 | 10 s al día que convierten la app en algo validable |
| 3 | FI‑A1 | Responde la pregunta principal del dashboard |
| 4 | FI‑E1 | Responde "¿cómo evoluciono?" sin ruido |
| 5 | FI‑C1 | Arregla el punto ciego más grande para un usuario de fuerza |
| 6 | FI‑E5 | Mide si el score te sirve a ti |
| 7 | FI‑F2 | Diferencial claro: experimentos N‑of‑1 |
| 8 | FI‑A2 | Que la estimación de arranque (ya visible) sea fiable |
| 9 | FI‑E4 | Bucle de aprendizaje de recomendaciones |
| 10 | FI‑F8 | Validación frente a WHOOP con tus propios datos |
