# Hoja de ruta

> Fecha: 2026-11-12 · commit `15d791a0`. Especificación de cada tarea en
> IMPROVEMENT_BACKLOG.md; estado vivo en PLANNING.md. Criterios: impacto en el
> usuario, valor funcional, esfuerzo, riesgo técnico y **disponibilidad de
> datos** (hoy: 3 noches).

## Principio rector

El cuello de botella no es el código, es el **histórico**. Por eso la
secuencia es: (1) no perder datos, (2) empezar a capturar la verdad de
referencia (cómo te sientes, cuándo te despiertas, RPE), (3) arreglar lo que
engaña, (4) construir inteligencia cuando haya 30–90 noches para validarla.

## Fases

```mermaid
gantt
  dateFormat YYYY-MM-DD
  title Fases (orientativo, uso diario continuo)
  section Fase 0 · Proteger
  DATA-01 archivo indefinido         :a1, 2026-11-13, 1d
  SEC-09 .gitignore                  :a2, 2026-11-13, 1d
  ALG-L1 no llevada ≠ descanso       :a3, 2026-11-14, 5d
  DATA-02 re-derivar desde archivo   :a4, 2026-11-19, 10d
  section Fase 1 · Verdad de referencia
  FI-B4 tarjeta matinal              :b1, 2026-11-14, 3d
  DATA-06 procedencia I'm awake      :b2, 2026-11-17, 1d
  ALG-L2 RPE y carga de fuerza       :b3, 2026-11-18, 5d
  section Fase 2 · Lo que engaña
  ALG-C1 cribado irregular en reposo :c1, 2026-11-24, 5d
  UX-P04 progreso de calibración     :c2, 2026-11-24, 2d
  ALG-S2 fases como rango            :c3, 2026-11-26, 2d
  UX-P02 banda personal              :c4, 2026-12-01, 5d
  section Fase 3 · Inteligencia (≥30 noches)
  ALG-R1 validar FP-CAL              :d1, 2026-12-12, 3d
  ALG-T1 motor de tendencias         :d2, 2026-12-12, 7d
  ALG-H1 CV 7 días                   :d3, 2026-12-19, 2d
  UX-P01 decisión determinista       :d4, 2026-12-22, 5d
  UX-P03 evolución en Home           :d5, 2027-01-05, 5d
  section Fase 4 · Diferencial (≥60–90 noches)
  ALG-R2 experimento de baselines    :e1, 2027-01-15, 5d
  FI-F2 experimentos N-of-1          :e2, 2027-01-20, 10d
  FI-E4 registro de recomendaciones  :e3, 2027-02-01, 7d
  FI-E3 predicción (experimental)    :e4, 2027-02-15, 10d
```

| Fase | Objetivo | Condición de salida |
|---|---|---|
| 0 · Proteger | Que ningún día se pierda para futuros algoritmos | Archivo indefinido; carga sin ceros inventados; re‑derivación desde archivo con test de ida y vuelta |
| 1 · Verdad de referencia | Capturar lo que la banda no sabe | 14 días seguidos con tarjeta matinal y RPE |
| 2 · Lo que engaña | Quitar alarmas y precisión falsas | Tasa de cribado irregular en días solo diurnos = 0 con fixture; fases con rango |
| 3 · Inteligencia | Tendencias y decisión explicable | Concordancia FP‑CAL medida; tendencias con < 5 % de falsos positivos en sintético |
| 4 · Diferencial | Aprender de ti | Primer experimento N‑of‑1 cerrado con resultado |

## Matriz impacto / esfuerzo

```mermaid
quadrantChart
  title Impacto vs esfuerzo
  x-axis Bajo esfuerzo --> Alto esfuerzo
  y-axis Bajo impacto --> Alto impacto
  quadrant-1 Planificar
  quadrant-2 Hacer ya
  quadrant-3 Rellenar huecos
  quadrant-4 Evitar o posponer
  DATA-01: [0.05, 0.85]
  FI-B4: [0.25, 0.9]
  DATA-06: [0.1, 0.5]
  SEC-09: [0.05, 0.45]
  ALG-L1: [0.4, 0.7]
  ALG-C1: [0.4, 0.65]
  UX-P04: [0.15, 0.55]
  ALG-S2: [0.15, 0.4]
  ALG-L2: [0.45, 0.75]
  DATA-02: [0.75, 0.9]
  ALG-T1: [0.5, 0.8]
  UX-P01: [0.5, 0.7]
  UX-P02: [0.45, 0.6]
  ALG-R3: [0.5, 0.35]
  FI-F2: [0.65, 0.65]
  FI-E3: [0.9, 0.3]
  FI-F5: [0.85, 0.2]
```

## Riesgos de la hoja de ruta

| Riesgo | Mitigación |
|---|---|
| Cambios en hotspots (`db.dart`, `derivation_engine.dart`) chocan con upstream | Diffs mínimos, ramas por tarea, PR upstream si les sirve |
| Sin toolchain en la sesión de agente | Tests en tu PC (`--concurrency=1`); nunca afirmar que se ejecutaron |
| Un cambio de algoritmo sin bump deja días incoherentes | Checklist de DEVELOPMENT_GUIDE §3 |
| Se dejan de usar la tarjeta matinal o el RPE | Mantenerlos en ≤ 10 s; medir cumplimiento y decir cuándo falta |
| Firmware actualizado por la app oficial | No instalarla con esta banda |
