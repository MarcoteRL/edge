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
| D‑14 | 2026‑11‑12 | Fallos de re‑derivación en una clave propia de `compute_freshness`, no en `substrate_archive_failures` | Ese contador decide borrados de crudo sin archivar a los 3 fallos. Un test demuestra que un fallo de lectura nunca lo incrementa | Aceptada (propietario, 2026‑11‑12) |
| D‑15 | 2026‑11‑12 | Fórmulas nuevas de tendencias, CV de HRV, consistencia de horario y sRPE como módulos del fork en `edge`, calculados al leer y sin persistir; analytics solo tras validarlas con ≥ 60 noches | **Excepción consciente a AGENTS §1** (una métrica nueva iría en analytics). Condiciones: en `lib/compute/fork/`; nada en `getToday` ni en la ruta caliente del read seam; bootstrap y Theil‑Sen en `Isolate.run`, con caché en memoria invalidada por (clave, última fecha de la serie, `kAlgoVersion`); se calculan al abrir la pantalla que los necesita, no en cada render. **Condición de salida:** pasar a `MarcoteRL/analytics` cuando una fórmula esté validada con ≥ 60 noches y merezca persistirse | Aceptada (propietario, 2026‑11‑12) |
| D‑16 | 2026‑11‑12 | La suite completa se lanza partida en dos runs | `test-files.yml` corta a los 90 min y la suite ronda ese tiempo | Aceptada |
| D‑17 | 2026‑11‑12 | En ALG‑T1, "cambio relevante" exige \|Δ\| > max(MDC, SWC) **y** que el IC por bootstrap **de esa diferencia** excluya 0. El IC de la pendiente Theil‑Sen se informa aparte ("deriva sostenida") y no entra en la regla | Theil‑Sen ignora por diseño hasta ~29 % de puntos atípicos: un escalón real en la última semana deja el IC de una pendiente de 30 días cruzando el 0 durante dos semanas. El MDC es el de una media de n noches (error típico / √n) | Aceptada (decidida por el agente ante una ambigüedad barata de deshacer; revisable por el propietario) |
| D‑18 | 2026‑11‑12 | La frase de entrenamiento del bloque de fuerza de Home usa las **mismas bandas** que el anillo y que la línea de decisión (26 / 37 / 61); deja de tener cortes propios (67 / 34). En un día "estable" no añade ninguna advertencia | Con cortes distintos, la tarjeta podía decir "intensidad moderada" bajo un titular "listo para darlo todo" (AGENTS §4.10) | Aceptada |
| D‑19 | 2026‑11‑12 | La línea de decisión (P‑01) solo se da con un Recovery **final**; con uno provisional no hay recomendación, y calibrando se dice que aún no la hay | Un número provisional puede moverse; una recomendación que cambia a media mañana es peor que una que llega tarde | Aceptada |
| D‑20 | 2026‑11‑13 | El laboratorio de periodos (ALG‑P1) compara N días antes de una fecha con los N desde ella (7/14/28). "Diferencia relevante" exige \|Δ\| > max(1,96·error estándar de una diferencia de medias con SD agrupada, 0,5·SD del periodo anterior) **y** que el IC por bootstrap de Δ excluya 0. Cada periodo necesita el 60 % de sus días (mínimo 4). Sin persistir, sin bump, en isolate (D‑15) | Ninguno de los dos periodos es un "habitual" largo, así que el MDC de ALG‑T1 (ruido de una media frente a un baseline de 28 días) no aplica; hace falta el error de una diferencia entre dos medias cortas. La pantalla dice que difieren, nunca por qué | Aceptada (decidida por el agente; barata de deshacer; revisable) |
| D‑21 | 2026‑11‑13 | El informe semanal es texto Markdown generado en el teléfono y solo sale por la hoja de compartir del sistema, con un toque del usuario. No se guarda en la base, no se sube y no pasa por el coach ni por ningún modelo | Regla de privacidad del fork: los análisis no salen del entorno del propietario salvo por su acción. Guardarlo exigiría tabla nueva (parar y preguntar) | Aceptada |
| D‑22 | 2026‑11‑13 | Una posible siesta pendiente que solapa un sueño principal ya guardado se retira (`superseded`) en un barrido tras escribir la fila del día (BUG‑N01). No se borra y no se resucita | El detector deja de ofrecer el tramo cuando la noche se guarda, así que `reconcile` no vuelve a ver la fila. Mismo criterio de solape que `overlapsMainSleep` (una sola definición, invariante 8) | Aceptada |

## Plantilla

```
### D-NN · Título
Fecha · Estado
Contexto: …
Decisión: …
Consecuencias: …
Alternativas descartadas: …
```
