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
| D‑05 | 2026‑11‑12 | CTL/ATL/TSB se muestran como descriptivos; **no** se usa ACWR como predictor de lesión | Acoplamiento matemático y teoría cuestionada (Lolli 2019; Impellizzeri 2020/21) | Propuesta |
| D‑06 | 2026‑11‑12 | No intentar "clonar" las fórmulas de WHOOP; las métricas [WHOOP‑LIKE] se etiquetan como propias | No son públicas; no hay verdad de referencia | Propuesta |
| D‑07 | 2026‑11‑12 | `samples` no se borra en el fork aunque duplica `decoded_onehz` | Tabla de upstream con lectores de *fallback*; issue upstream | Propuesta |
| D‑08 | 2026‑11‑10 | Estimaciones de calibración (FP‑CAL) con referencia poblacional, **relajando el invariante 3** solo en lectura, en gris y nunca persistidas | Petición del propietario: ver algo desde la noche 1 como en WHOOP | Aceptada; validación pendiente (ALG‑R1) |
| D‑09 | 2026‑11‑12 | Fuerza: carga muscular (sRPE/tonelaje) como **segunda dimensión**, no mezclada con el 0–21 cardiovascular | Mezclar oculta qué la causa | Propuesta |
| D‑10 | 2026‑11‑12 | Las validaciones con datos reales se hacen con scripts offline de solo lectura y se documentan solo agregados | Privacidad del propietario | Aceptada |
| D‑11 | 2026‑11‑12 | No ajustar pesos de readiness hasta tener ≥ 30 días de tarjeta matinal | Sin verdad de referencia, ajustar es opinión | Propuesta |

## Plantilla

```
### D-NN · Título
Fecha · Estado
Contexto: …
Decisión: …
Consecuencias: …
Alternativas descartadas: …
```
