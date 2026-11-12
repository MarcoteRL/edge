# Registro de decisiones

> Formato ADR breve. Las decisiones de upstream están en AGENTS.md (invariantes
> §3) y no se repiten. Aquí, las del fork y las de esta auditoría.
> Estado: **Aceptada** · **Propuesta** (pendiente del propietario) · **Rechazada**.

| ID | Fecha | Decisión | Motivo | Estado |
|---|---|---|---|---|
| D‑01 | 2026‑11‑09 | `AGENTS.md` de upstream no se edita; lo del fork va en `CLAUDE.md` y `docs/development/` | Merges limpios con upstream | Aceptada |
| D‑02 | 2026‑11‑09 | No refactorizar los archivos gigantes en el fork | Conflictos con upstream; riesgo sin hardware | Aceptada |
| D‑03 | 2026‑11‑09 | Tests en local (Windows), `test.yml` desactivado | Coste de minutos en repo privado | Aceptada |
| D‑04 | 2026‑11‑12 | La documentación de esta auditoría vive en `docs/development/`, incluida la guía de agentes (`AGENT_GUIDE.md`), y no en `docs/` ni en `AGENTS.md` | D‑01; `docs/FEATURES.md` y la web son de upstream | Aceptada (elegida por el propietario) |
| D‑05 | 2026‑11‑12 | CTL/ATL/TSB se muestran como descriptivos; **no** se usa ACWR como predictor de lesión | Acoplamiento matemático y teoría cuestionada (Lolli 2019; Impellizzeri 2020/21) | Aceptada (propietario, 2026‑11‑12) |
| D‑06 | 2026‑11‑12 | No intentar "clonar" las fórmulas de WHOOP; las métricas [WHOOP‑LIKE] se etiquetan como propias | No son públicas; no hay verdad de referencia | Aceptada (propietario, 2026‑11‑12) |
| D‑07 | 2026‑11‑12 | `samples` no se borra en el fork aunque duplica `decoded_onehz` | Tabla de upstream con lectores de *fallback*; issue upstream | Propuesta |
| D‑08 | 2026‑11‑10 | Estimaciones de calibración (FP‑CAL) con referencia poblacional, **relajando el invariante 3** solo en lectura, en gris y nunca persistidas | Petición del propietario: ver algo desde la noche 1 como en WHOOP | Aceptada; validación pendiente (ALG‑R1) |
| D‑09 | 2026‑11‑12 | Fuerza: carga muscular (sRPE/tonelaje) como **segunda dimensión**, no mezclada con el 0–21 cardiovascular | Mezclar oculta qué la causa | Aceptada (propietario, 2026‑11‑12) |
| D‑10 | 2026‑11‑12 | Las validaciones con datos reales se hacen con scripts offline de solo lectura y se documentan solo agregados | Privacidad del propietario | Aceptada |
| D‑11 | 2026‑11‑12 | No ajustar pesos de readiness hasta tener ≥ 30 días de tarjeta matinal | Sin verdad de referencia, ajustar es opinión | Aceptada (propietario, 2026‑11‑12) |
| D‑12 | 2026‑11‑12 | "Ya estoy despierto" no cambia `sleep_override.source`; se reconoce con `source='manual' AND abs(created_at − offset_ts) ≤ 60` | Cambiar `source` obliga a revisar todos los lectores de `'manual'` (49 apariciones en `lib/`) (AGENTS §4.7). Límites conocidos: una edición posterior pisa la pulsación; una edición con final en el minuto en curso es indistinguible | Aceptada |
| D‑13 | 2026‑11‑12 | DATA‑02 impone la inmutabilidad en su propia ruta (no escribe si ya existe `(day_id, kAlgoVersion)`) y rehidrata el archivo solo en memoria | `putDayResult` usa REPLACE; reinsertar en `decoded_*` interferiría con la poda y el invariante 2 | Aceptada (criterios del propietario) |
| D‑14 | 2026‑11‑12 | Fallos de re‑derivación en una clave propia de `compute_freshness`, no en `substrate_archive_failures` | Ese contador decide borrados de crudo sin archivar a los 3 fallos | **Propuesta** (ITERATION_PLAN Q2) |
| D‑15 | 2026‑11‑12 | Fórmulas nuevas de tendencias, CV de HRV, consistencia de horario y sRPE como módulos del fork en `edge`, calculados al leer y sin persistir; analytics solo tras validarlas con ≥ 60 noches | Sin pin ni bump mientras no hay datos para validarlas; precedente `healthspan.dart` | **Propuesta** (ITERATION_PLAN Q1) |
| D‑16 | 2026‑11‑12 | La suite completa se lanza partida en dos runs | `test-files.yml` corta a los 90 min y la suite ronda ese tiempo | Aceptada |

## Plantilla

```
### D-NN · Título
Fecha · Estado
Contexto: …
Decisión: …
Consecuencias: …
Alternativas descartadas: …
```
