# Bitácora de implementación

> Punto de reanudación entre sesiones. Entrada nueva **arriba**, al cerrar
> cada tarea: qué cambió, por qué, evidencia, tests añadidos, limitaciones y
> siguiente paso. El plan vigente es ITERATION_PLAN.md; el estado por tarea,
> PLANNING.md; las evidencias de CI, `../../PROGRESS.md`.

## Estado actual

- **Iteración:** 1 cerrada; **plan pendiente de aprobación del propietario**.
- **Bloqueos:** Q1 (dónde viven las fórmulas nuevas), Q2 (contador de
  fallos de re‑derivación), Q3 (alinear `CLAUDE.md`). Ver ITERATION_PLAN §0.
- **Siguiente paso tras la aprobación:** iteración 2, empezando por los tests
  de ida y vuelta de DATA‑02 (fallan primero, luego el código).
- **Entorno de trabajo:** clon en la nube de `MarcoteRL/edge` con `gh`
  autenticado (tests e IPA por Actions). El checkout de Windows del
  propietario no se toca desde la sesión: sus archivos tienen finales CRLF y
  la máquina virtual de la sesión no puede borrar archivos allí, así que
  `git` no es fiable en esa copia. El propietario hace `git pull`.

## 2026-11-12 — Iteración 1: auditoría contrastada y plan

- **Qué:** AUDIT_VERIFICATION.md (nuevo), ITERATION_PLAN.md (nuevo), este
  archivo; correcciones en ALGORITHMS.md, ALGORITHM_EVALUATION.md,
  AUDIT_SUMMARY.md, DATA_MODEL.md, DATA_QUALITY.md, DECISIONS.md (D‑05, D‑06,
  D‑09, D‑11 aceptadas; D‑12…D‑16 nuevas), IMPROVEMENT_BACKLOG.md,
  PLANNING.md, README.md, UI_UX_AUDIT.md. **Ningún archivo de código.**
- **Por qué:** la auditoría del 2026‑11‑12 se escribió sobre `kAlgoVersion
  120` y sin ejecutar nada; había que saber qué sigue siendo cierto antes de
  planificar.
- **Hallazgos que cambian el plan:** fases como rango y petición de RPE ya
  existen; `putDayResult` reescribe la misma versión; el contador
  `substrate_archive_failures` gobierna borrados; las tendencias, el CV de
  HRV, la consistencia de horario y el sRPE son fórmulas nuevas; ALG‑L1/C1 se
  fusionaron antes de que acabara la suite completa.
- **Evidencia:** símbolos y archivos citados en AUDIT_VERIFICATION.md;
  `gh run list` para el estado de CI. Sin tests nuevos (solo docs).
- **Limitaciones:** sin exportación de datos en la sesión; sin dispositivo;
  varias afirmaciones de UX quedan como [Hipótesis] hasta leer cada pantalla
  al abrir su tarea.
- **Rama:** `iter1/audit-contrast` (solo docs; no genera IPA).
