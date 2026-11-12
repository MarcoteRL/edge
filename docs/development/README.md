# Índice de conocimiento del fork

> Punto de entrada para cualquier persona o agente. Última auditoría:
> **2026-11-12**, commit `15d791a0`, `kAlgoVersion 120`, `schemaVersion 58`,
> con una exportación real de WHOOP 5.0 (3 noches). Código actual: léelo en
> `derivation_engine.dart` (`kAlgoVersion`, 121 a 2026‑11‑12) y `db.dart`. Empieza por
> **AUDIT_SUMMARY.md** si solo vas a leer una cosa.

## En 30 segundos

- **Qué es:** app Flutter que usa una WHOOP sin suscripción: BLE → SQLite en
  el móvil → métricas propias con métodos publicados. → PROJECT_OVERVIEW.md
- **Cómo está hecho:** 3 repos (protocol / analytics / edge), isolates,
  resultados versionados, UI que solo lee. → ARCHITECTURE.md, DATA_FLOW.md
- **Qué hace:** sueño, HRV, recovery, strain, estrés, fuerza (Hevy), coach,
  exportación a Salud… → FEATURES.md
- **Qué falta:** proteger el histórico, verdad de referencia diaria,
  tendencias y decisión explicable. → ROADMAP.md, IMPROVEMENT_BACKLOG.md
- **Reglas:** `CLAUDE.md` → `AGENTS.md` (invariantes) → AGENT_GUIDE.md

## Mapa de documentos

| Necesitas… | Documento |
|---|---|
| Resumen ejecutivo | [AUDIT_SUMMARY.md](AUDIT_SUMMARY.md) |
| Auditoría contrastada con el código | [AUDIT_VERIFICATION.md](AUDIT_VERIFICATION.md) |
| Plan de iteraciones (pendiente de aprobación) | [ITERATION_PLAN.md](ITERATION_PLAN.md) |
| Bitácora de implementación | [IMPLEMENTATION_LOG.md](IMPLEMENTATION_LOG.md) |
| Reglas para agentes | [AGENT_GUIDE.md](AGENT_GUIDE.md) |
| Qué es y estado | [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) |
| Arquitectura y módulos | [ARCHITECTURE.md](ARCHITECTURE.md) |
| De la banda a la pantalla | [DATA_FLOW.md](DATA_FLOW.md) |
| Modelo de datos | [DATA_MODEL.md](DATA_MODEL.md) |
| Campos uno a uno | [DATA_DICTIONARY.md](DATA_DICTIONARY.md) |
| BLE, sync y qué da la WHOOP | [WHOOP_INTEGRATION.md](WHOOP_INTEGRATION.md) |
| Funcionalidades existentes | [FEATURES.md](FEATURES.md) |
| Algoritmos (fórmulas) | [ALGORITHMS.md](ALGORITHMS.md) |
| Evaluación y mejoras de algoritmos | [ALGORITHM_EVALUATION.md](ALGORITHM_EVALUATION.md) |
| UX/UI | [UI_UX_AUDIT.md](UI_UX_AUDIT.md) |
| Deuda técnica | [TECHNICAL_DEBT.md](TECHNICAL_DEBT.md) · hallazgos previos: [TECHNICAL_AUDIT.md](TECHNICAL_AUDIT.md) |
| Seguridad y privacidad | [SECURITY.md](SECURITY.md) |
| Tests | [TESTING.md](TESTING.md) |
| Desarrollar | [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) · iOS: [IOS_BUILD_PIPELINE.md](IOS_BUILD_PIPELINE.md) |
| **Ejecutar tests y generar el IPA (CI con `gh`)** | [CI_RUNBOOK.md](CI_RUNBOOK.md) |
| Base de datos real | [DATABASE_AUDIT.md](DATABASE_AUDIT.md) · [DATA_QUALITY.md](DATA_QUALITY.md) · [DATA_ANALYSIS.md](DATA_ANALYSIS.md) · [DATA_OPPORTUNITIES.md](DATA_OPPORTUNITIES.md) |
| Scripts de análisis | [analysis/README.md](analysis/README.md) |
| Ideas y prioridades | [FEATURE_IDEAS.md](FEATURE_IDEAS.md) · [IMPROVEMENT_BACKLOG.md](IMPROVEMENT_BACKLOG.md) · [ROADMAP.md](ROADMAP.md) · propuestas previas: [FEATURE_PROPOSALS.md](FEATURE_PROPOSALS.md) |
| Plan y estado vivo | [PLANNING.md](PLANNING.md) · `../../PROGRESS.md` |
| Decisiones | [DECISIONS.md](DECISIONS.md) |
| Términos | [GLOSSARY.md](GLOSSARY.md) |
| Investigación | [research/RECOVERY_RESEARCH.md](research/RECOVERY_RESEARCH.md) · [SLEEP_RESEARCH](research/SLEEP_RESEARCH.md) · [STRAIN_RESEARCH](research/STRAIN_RESEARCH.md) · [BIOMETRIC_METRICS](research/BIOMETRIC_METRICS.md) · [DATA_SOURCES](research/DATA_SOURCES.md) · [REFERENCES](research/REFERENCES.md) |
| Skills | [SKILLS_AUDIT.md](SKILLS_AUDIT.md) |

## Antes de trabajar en cada área

| Área | Lee |
|---|---|
| BLE / sync | AGENTS.md §3, WHOOP_INTEGRATION.md, TECHNICAL_AUDIT.md F‑02 |
| Algoritmos | ALGORITHMS.md → ALGORITHM_EVALUATION.md → research/ |
| Base de datos | DATA_MODEL.md → DATABASE_AUDIT.md |
| UI | `lib/ui2/README.md` → UI_UX_AUDIT.md |
| Nuevas funciones | FEATURE_IDEAS.md → IMPROVEMENT_BACKLOG.md → ROADMAP.md |

## Convenciones de estos documentos

- **Hecho** = verificado en código o datos; **Hipótesis** = sin verificar;
  **Propuesta** = cambio sugerido.
- IDs estables: `Q‑` calidad de datos, `DB‑` base de datos, `ALG‑` algoritmos,
  `UX‑`/`P‑` interfaz, `FI‑` ideas, `TD‑` deuda, `SEC‑` seguridad, `D‑` decisiones,
  `O‑` oportunidades de datos, `T‑` tests.
- Nombres de símbolos, no números de línea (cambian).
- Sin valores biométricos individuales: solo agregados.
- `docs/` (fuera de `development/`) es de upstream: no se edita.
