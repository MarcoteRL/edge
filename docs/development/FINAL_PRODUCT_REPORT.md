# Informe final de producto

> Fecha: 2026‑11‑13 · `kAlgoVersion` 121 · `schemaVersion` 58 · pins sin
> cambios (analytics `3a7ca34d`, protocol `b4fde6ab`).
> Etiquetas: **[Comprobado]** (hay comando, test o run), **[Hipótesis]**,
> **[Recomendación]**, **[Decidido]**.
> Este informe no contiene valores biométricos individuales con fecha.

## 1. Qué responde hoy la app a las cuatro preguntas

| Pregunta | Dónde | Estado |
|---|---|---|
| ¿Cómo estoy? | Home: anillos de Recovery, Strain y Sueño; con pocos días, estimación en gris y explicación de por qué | En `main`. **[Comprobado]** suite local del propietario +7128 −28 (las 28: portabilidad Windows) |
| ¿Qué ha cambiado frente a mi normal? | Health: rango habitual por métrica; debajo, veredicto de la semana solo si supera max(MDC, SWC). Home: "Cómo evolucionas". Laboratorio de periodos | Rango y evolución en `main`. Veredicto semanal y laboratorio en rama, **sin compilar** |
| ¿Qué hago hoy? | Home: línea de decisión determinista por banda de Recovery, con las entradas que ayudaron y frenaron; solo con Recovery final (D‑19) | En `main` |
| ¿Cómo evoluciono? | Tendencias 7/14/30/90 días (ALG‑T1), estabilidad de HRV (ALG‑H1), consistencia de horario (ALG‑S3), carga de fuerza (ALG‑L2/L3), informe semanal | Cálculo en `main`; informe en rama, **sin compilar** |

## 2. Qué se ha hecho, por iteración

| Iteración | Contenido | Dónde | Evidencia |
|---|---|---|---|
| 1 | Auditoría contrastada con el código y plan | `main` | Documentos; sin código |
| 2 | Re‑derivación desde el archivo de sustrato (DATA‑02), fuera del hilo de UI y sin crear sugerencias; regla de "Ya estoy despierto"; contrato del payload | `main` | Runs test‑files 43255670024, 43273419312; exportaciones antes/después del propietario (agregados en DATA_ANALYSIS.md §8) |
| 3 | Módulos del fork calculados al leer (D‑15): tendencias, CV de HRV, horario, sRPE, tonelaje, Edwards | `main` | Run 43305607581 (solo sintético) |
| 4 | Línea de decisión, evolución en Home, frescura de datos en todas las pestañas, "Cómo se calcula" | `main` | Suite local del propietario; IPA run 43327489818 |
| — | BUG‑N01 (siestas dentro de la noche) y tests portables a Windows | PR #2 | Prueba local del propietario: 15 archivos, +172 ~12, 0 fallos |
| 4 (resto) | P‑02, P‑05, P‑07, "en qué se apoya el número de hoy" | rama `iter5/lab-report` | **Ninguna todavía** |
| 5 | Laboratorio de periodos (ALG‑P1), informe semanal | rama `iter5/lab-report` | **Ninguna todavía**; tests sintéticos escritos |
| 6 | Revisión estática (TECHNICAL_DEBT.md §5) y este informe | rama `iter5/lab-report` | Barridos con `grep` del 2026‑11‑13 |

## 3. Lo que NO está validado

- **Nada está validado en hardware.** Todo lo anterior es, como mucho,
  *unit‑tested, not hardware‑validated*.
- **La rama `iter5/lab-report` no se ha compilado.** No hay Flutter en la
  sesión del agente y no se ha gastado CI. Puede no compilar.
- **Las reglas estadísticas del fork solo se han probado con series
  sintéticas.** [Comprobado] La exportación disponible no tiene ninguna noche
  con readiness, así que ni ALG‑T1 ni ALG‑P1 se han visto sobre datos reales.
  La condición de salida de D‑15 (≥ 60 noches) sigue lejos.
- **ALG‑R1 y ALG‑S1** (acuerdo de la estimación de calibración; error del
  final automático del sueño): scripts escritos, sin datos suficientes.
- **Fallos 1 a 10 de la suite completa en Windows:** no se recibieron en el
  log; cinco archivos se corrigieron por patrón, no por evidencia.
- **Ninguna mejora de velocidad o batería está medida.** Las de
  TECHNICAL_DEBT.md §5 son [Hipótesis].

## 4. Lo que no se ha hecho, y qué lo desbloquea

| Pendiente | Qué falta |
|---|---|
| Registro de recomendaciones | **Tu aprobación** de una tabla nueva (migración aditiva + `schemaVersion`) |
| N‑of‑1 | Usar el diario: hoy tiene 0 entradas |
| Validación frente a WHOOP | El ZIP de la exportación oficial |
| ALG‑R1 / ALG‑S1 | ~10 noches con readiness / ~10 pulsaciones de "Ya estoy despierto" |
| "Días anteriores sin esfuerzo" | Saber en qué pantalla y qué día lo ves. [Hipótesis] la estimación gris de Strain solo se calcula para hoy |
| Revisión de BLE, latches y batería | Dispositivo, o una lectura dedicada de `ble_engine.dart` y `app_state.dart` |
| Bugs heredados (BUG‑601, BUG‑558, BUG‑186, BUG‑566) | Dispositivo para reproducir |
| Galería y goldens de las pantallas nuevas | Flutter para generarlos |

## 5. Riesgos abiertos, por orden

1. **Invariante 9 (riesgo conocido de upstream):** un día `partial` más allá
   de `_maxRawHoldDays` pierde su sustrato. El archivo "Para siempre" que
   activaste lo mitiga para lo decodificado; no se ha tocado la política.
2. **Reglas nuevas sin datos reales** (§3). Mientras tanto dicen "aún no hay
   días" en vez de un veredicto, que es el comportamiento buscado.
3. **Home es más largo** (dos puertas más). Si molesta, agruparlas (R6‑6).
4. **Presupuesto de Actions:** cada fusión a `main` construye un IPA
   (≈ 130 min facturados). Hasta el 2026‑12‑01 queda margen para uno.
5. **Autoría de commits:** desde el 2026‑11‑13 todo sale a tu nombre; los
   anteriores siguen a nombre de Claude porque reescribirlos exige
   force‑push, que está prohibido.

## 6. Recomendación de orden

[Recomendación] 1) Prueba local de `iter5/lab-report` (`flutter analyze` y
los tests listados en PROGRESS.md). 2) Fusionar PR #2 y esa rama **juntos**,
para gastar un solo IPA. 3) Usar la app dos semanas, con diario, antes de
tocar más algoritmos: casi todo lo pendiente está bloqueado por datos, no por
código. 4) Decidir la tabla del registro de recomendaciones.
