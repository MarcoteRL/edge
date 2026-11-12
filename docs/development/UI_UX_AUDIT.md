# Auditoría visual y de UX

> Fecha: 2026-11-12 · commit `15d791a0`. Fuentes: código de `lib/ui2/`
> (sistema de diseño en `theme.dart`, `grammar.dart`, `charts.dart`,
> `app_shell.dart`), las capturas de `screenshots/` y el estado real de tus
> datos. **Las capturas de `screenshots/` son de upstream y anteriores al
> rediseño de Home del fork (UX‑02…UX‑06, PROGRESS.md)**: para Home manda el
> código, no la captura. Health, Sleep y Workout no cambiaron en ese rediseño. **No se ha
> ejecutado la app en esta sesión** (no hay toolchain Flutter en el entorno);
> las observaciones de interacción vienen del código y las capturas.

## 1. Punto de partida: lo que ya está bien

- **Sistema de diseño con reglas automatizadas**: tokens obligatorios, contraste
  ≥ 4,5:1 comprobado por test para todo acento × superficie × tema
  (`ui2_contrast_test.dart`), barrido de componentes a 1,0–3,1× de texto sin
  desbordes, objetivo táctil ≥ 44 pt (`ui2_component_sweep_test.dart`). Es
  mejor base de accesibilidad que la mayoría de apps comerciales.
- **Honestidad visible**: "Calibrating 5 of 14 nights", "—" en vez de ceros,
  avisos de cribado "no es un diagnóstico". Diferenciador real frente a WHOOP.
- **Corrección del usuario en contexto**: "Set the times myself" / "Not sleep"
  en la propia noche.
- Tema oscuro cuidado, tipografía de 7 pasos, iconografía Lucide coherente.
- Rediseño de Home del fork (UX‑02…06): jerarquía clara, movimiento que se
  desactiva con "reducir movimiento", carga silenciosa en la cabecera, bloque
  de fuerza útil para un usuario de gimnasio.

## 2. Las tres preguntas del dashboard

| Pregunta | ¿La responde Home hoy? | Evidencia |
|---|---|---|
| ¿Cómo estoy hoy? | **Sí, bastante mejor tras el rediseño.** Titular de Recovery con "▲/▼ vs ayer", barras de los tres pilares, constantes con "Usual" frente a 28 días, estimación gris durante la calibración | `home_screen.dart` (UX‑02, UX‑06) |
| ¿Qué debería hacer hoy? | **Parcial.** Banda objetivo de strain en la barra y tarjeta del coach; pero la recomendación explicada depende de tener un proveedor de IA configurado | `strain_target`, tarjeta del coach |
| ¿Cómo estoy evolucionando? | **Débil.** "vs ayer" y "Usual" dan contexto de un día; no hay tendencia de semanas en Home (hay que ir a Health → Trends) | `health_screen.dart` |

## 3. Problemas detectados

| ID | Problema | Dónde | Impacto | Gravedad |
|---|---|---|---|---|
| UX‑01 | Arranque en frío: en Home lo **mitiga** la estimación gris (FP‑CAL), pero no se dice qué falta ni cuándo llega lo real por métrica; la carga de Workout sigue bloqueada ("No training load yet") | Home, Workout | El usuario no sabe qué esperar | Media |
| UX‑02 | Flechas de tendencia sin magnitud ni banda en Health → Overview (en Home ya hay "Usual", que abstiene < 14 días) | `health_screen.dart` | Cambios dentro del ruido parecen señales; el color sugiere juicio | Alta |
| UX‑03 | Cribado de ritmo irregular destacado como "Observación" con alta probabilidad de falso positivo | Health → Observations | Alarma innecesaria | Alta (ver Q‑04) |
| UX‑04 | Fases de sueño con precisión aparente (barras a la época) pese a κ 0,13 | `sleep_detail.dart` (hipnograma) | Sobreinterpretación de REM/profundo | Media |
| UX‑05 | "Asleep of that 99 %": eficiencia casi siempre alta porque la muñeca no ve la vigilia quieta | Sleep | Métrica poco informativa | Media |
| UX‑06 | ~~Cabecera grande~~ resuelto por la cabecera compacta de UX‑02 | Home | — | — |
| UX‑07 | Workout abre con mascota y "74 activities"; la semana (M‑S) vacía no aporta | `workout_screen.dart` | La carga queda bajo el pliegue | Media |
| UX‑08 | "Usual" en Home es un valor, no una banda, y no usa el MDC: no distingue "un poco por encima" de "fuera de tu normal" | Home (constantes), Health | Lectura binaria de cambios pequeños | Media |
| UX‑09 | El estado de sync ya está en la cabecera de Home (UX‑05); en Health, Sleep y Workout no | resto de pestañas | No se sabe si los datos son de hace 5 min o de ayer | Baja |
| UX‑11 | La estimación gris (FP‑CAL) y el valor real se parecen visualmente salvo por el gris; con una referencia poblacional, el usuario puede tomarla por suya | Home | Confianza en un número no validado | Media (ALG‑R1) |
| UX‑10 | El README del sistema de diseño habla de "cuatro pestañas"; hay cinco (Home, Health, Nutrition, Workout, Wellness) | `lib/ui2/README.md` | Doc desactualizada | Baja |

## 4. Propuestas concretas

### P‑01 · Línea de decisión determinista (responde a 2)

Hoy la recomendación explicada vive en la tarjeta del coach (IA). Añadir una
línea **sin IA**, siempre disponible, bajo el titular:

```
Hoy: buen día para intensidad          [Recovery 72 · tu normal 48–66]
Objetivo de strain 12–15 · Sueño esta noche 7 h 50 m (acostarse 23:20)
Por qué: HRV por encima de tu media 7 d · RHR estable · dormiste lo necesario
```

- **Componentes nuevos:** `DecisionLine` (grammar.dart) con `Driver` chips; la
  tarjeta del coach puede ampliarla, no sustituirla.
- **Datos:** `readiness`, `drivers`, `strainTarget`, `sleepNeed`,
  `recommendedBedtime` (todos existen en el payload).
- **Durante el arranque:** "Calibrando · estimación" y nada de recomendación
  de intensidad hasta que el Recovery sea real.
- **Prueba:** test de widget con payload completo, sin readiness y sin sueño.

### P‑02 · Valor + banda personal en cada métrica (UX‑02, UX‑08)

> **Corrección (iteración 1):** las tendencias de Health ya dibujan el rango
> habitual y abstienen con < 14 días (`usualRangeFor`, `ui2/trend.dart`).
> Falta la puerta del MDC y llevarlo a las constantes de Home.

En Health → Overview, y como evolución del "Usual" de Home: sustituir la
flecha por un **mini gráfico de bala** (bullet): punto de hoy sobre la banda
personal (mediana ± MAD de 28 d) y la línea del MDC. Color solo
si sale de la banda **y** supera el MDC. Componente `BaselineBullet` en
`charts.dart`. Los datos ya están en `payload_json.baselines.*`
(`baseline`, `spread`, `mdc`, `mdc_multiples`).

### P‑03 · Sección "Evolución" en Home (responde a 3)

Tres *sparklines* de 30 días (lnRMSSD, RHR, sueño) con media 7 d superpuesta y
una línea de texto solo cuando ALG‑T1 detecta un cambio significativo
("Tu RHR lleva 9 días 3 lpm por encima de tu normal"). Si no hay cambio:
"Estable".

### P‑04 · Progreso de calibración (UX‑01, UX‑11)

Al tocar la estimación gris, una hoja "Aprendiendo tu normal" con barra por
métrica y la explicación de que el gris parte de una referencia general: Readiness 3/14,
Strain 2/3, Carga 3/14, Sueño libre 0/3, Temperatura 2/3. Datos: notas
`need_baseline` del payload. Desaparece cuando todas están completas.

### P‑05 · Fases como rango y jerarquía de sueño (UX‑04, UX‑05)

> **Corrección (iteración 1):** el rango de fases ya existe en
> `sleep_detail.dart`; `light_range_sec` es un campo del payload del candidato, no una columna. Queda la jerarquía.

Orden: duración → horario y regularidad → deuda → fases. Fases como barra
apilada con **rangos** (`light_range_sec`…) y la etiqueta "estimación de
muñeca"; hipnograma a demanda. Sustituir "Asleep of that" por "Vigilia
detectada" con nota de sensibilidad.

### P‑06 · Observaciones de salud con umbral de confianza (UX‑03)

Mostrar el cribado de ritmo irregular solo si se repite ≥ 2 noches en reposo
(tras ALG‑C1) y con un texto neutro; el resto en el log de hallazgos.

### P‑07 · Workout centrado en la carga (UX‑07)

Primero: carga de la semana (cardiovascular y muscular por separado),
distribución por zonas y comparación con las 4 semanas anteriores. Después: el
catálogo para empezar sesión.

### P‑08 · Estado de datos global (UX‑09)

El de Home (`_syncLine`) ya existe; llevar el mismo indicador a la cabecera de
cada pestaña: "Actualizado hace 4 min"
/ "Sincronizando 38 %" / "Sin datos desde ayer 23:10". La fuente ya existe
(`sync_cursor.rec_ts_hw`, `LocalDb.latestSample`).

## 5. Visualización de datos

| Necesidad | Gráfico propuesto | Notas |
|---|---|---|
| Serie temporal diaria | Línea + media 7 d + banda personal sombreada | Sin eje en cero para HRV/RHR |
| Tendencia | Pendiente Theil‑Sen con texto, no solo la línea | ALG‑T1 |
| Comparar con baseline | Bullet chart (P‑02) | |
| Zonas de FC | Barra apilada horizontal por sesión + semanal | Colores de zona con contraste validado |
| Distribución de carga | Barras semanales cardiovascular / muscular | ALG‑L2 |
| Calendario de actividad | Mes con intensidad por color (el sistema prohíbe rachas; respetarlo) | `month_grid.dart` existe |
| Heatmap | Hora del día × día de semana para FC, actividad o sueño | Útil para regularidad |
| Correlaciones | Diagrama de puntos con n, ρ y p ajustada; nunca solo el ρ | `journalNumericCorrelations` |
| Semana vs semana / mes vs mes | Barras emparejadas con diferencia y su incertidumbre | FI‑F3 |

## 6. Dirección visual

**Principio:** "instrumento de precisión, no tragaperras". Referencias de
patrones (no de interfaces):

| Producto | Patrón que merece la pena | Patrón que evitar |
|---|---|---|
| WHOOP | Un número principal por pilar, color = estado | Opacidad del cálculo |
| Oura | Contribuyentes visibles bajo cada score | Lenguaje vago ("pay attention") |
| Garmin Connect | Estado de entrenamiento con explicación | Densidad excesiva de widgets |
| Athlytic | Rangos personales visibles alrededor del valor | — |
| TrainingPeaks | CTL/ATL/TSB como gráfico de rendimiento | Jerga sin explicar |
| Apple Health | Rangos y tendencias neutrales, sin juicio | Sin decisión |

Paleta: mantener los acentos actuales; reservar el rojo para "fuera de tu banda
y por encima del MDC"; usar un único acento por pilar (Recovery verde‑azul,
Strain violeta, Sueño azul ya están). Tipografía numérica tabular para que las
cifras no bailen al actualizar.

## 7. Componentes a crear o mejorar

| Componente | Nuevo/mejora | Archivo |
|---|---|---|
| `DecisionLine` | Nuevo | `grammar.dart` |
| `BaselineBullet` | Nuevo | `charts.dart` |
| `TrendSparkline` con banda | Mejora de `trend.dart` | `trend.dart` |
| `CalibrationProgress` | Nuevo | `grammar.dart` |
| `DataFreshnessBadge` | Extraer `_syncLine` de Home | `app_shell.dart` |
| `StageRangeBar` | Nuevo | `charts.dart` |
| `LoadSplitBars` | Nuevo | `charts.dart` |

Cada componente nuevo debe entrar en la galería (`ui2/profile/gallery.dart`)
o fallará `ui2_tokens_test.dart`.

## 8. Priorización

| Prioridad | Cambio | Esfuerzo |
|---|---|---|
| P1 | P‑04 calibración, P‑02 banda personal, P‑06 cribado | S–M |
| P1 | P‑01 línea de decisión determinista | M |
| P2 | P‑03 evolución en Home, P‑08 frescura de datos | M |
| P2 | P‑05 sueño, P‑07 workout | M |
| P3 | Heatmaps y correlaciones avanzadas | M–L |

## 9. Estado tras la iteración 4 (2026‑11‑12, en rama, sin validar en CI ni en dispositivo)

| Propuesta | Estado | Dónde |
|---|---|---|
| P‑01 línea de decisión | **Hecha.** `DecisionLine`: una frase por banda de Recovery (las mismas bandas que el anillo) + qué entradas ayudaron y cuáles frenaron. Solo con Recovery final (D‑19). La frase del bloque de fuerza se alinea con las mismas bandas (D‑18) | `ui2/screens/home_guidance.dart`, `home_screen.dart` |
| P‑02 banda + MDC | **Ya existía la banda** (`UsualRange`, `ui2/trend.dart`, abstiene < 14 días). **No añadida** la puerta del MDC en las tarjetas de Health: el veredicto con significancia vive en la nueva sección de evolución de Home. Pendiente decidir si se unifican |
| P‑03 evolución en Home | **Hecha.** `HomeEvolution` → `TrendService` (isolate + caché) → `EvolutionCard`: HRV, FC en reposo y sueño, "estable" / "Δ frente a tu normal" / "aún no hay días suficientes" | `home_guidance.dart` |
| P‑04 calibración | **Ya existía** `firstWeekCard` (qué llega y cuándo, con cuenta atrás). **Añadido:** una línea que explica que el gris parte de una referencia general, solo mientras hay un número gris en pantalla. Sin hoja con barras por métrica: habría duplicado esa tarjeta |
| P‑05 fases como rango / jerarquía | Rango: ya existía. **Jerarquía de la pantalla de sueño: sin tocar** (no revisada) |
| P‑07 Workout por carga | **Parcial.** La carga muscular de la semana (kg levantados, series sin carga, sRPE o su suelo) se muestra en el bloque de fuerza de Home, separada del strain. **La pestaña Workout no se ha reordenado** |
| P‑08 frescura en todas las pestañas | **Hecha** en Health, Workout y Sueño (`dataFreshnessLine`); sin datos de banda no dibuja nada |
| Ficha "Cómo se calcula" | **Hecha** como página (`HowComputedScreen`, puerta al final de Home): Recovery, Strain, Sueño, HRV/FC en reposo, con tipo, entradas, ventana y datos ausentes, límites y versión del algoritmo. Texto estático; **no** muestra todavía la suficiencia de los datos de hoy por métrica |
