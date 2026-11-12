# Guía permanente para agentes (fork)

> Equivale al `AGENTS.md` que pide la misión, pero vive aquí porque el
> `AGENTS.md` de la raíz es de upstream y no se edita (DECISIONS.md D‑01/D‑04).
> `CLAUDE.md` importa `AGENTS.md` y enlaza esta guía. **Orden de lectura:**
> `CLAUDE.md` → `AGENTS.md` (invariantes) → este archivo → `docs/development/README.md`.
> Última revisión: 2026-11-12, commit `15d791a0`.

## 1. Arquitectura y convenciones (resumen)

- Tres repos: `protocol` (bytes) · `analytics` (fórmulas) · `edge` (esto:
  flujos, BLE, almacenamiento, UI). Una fórmula nueva **no** va en `lib/compute/`.
- Flujo: banda → `ble_engine.dart` → `LocalDb` (commit **antes** del ACK) →
  `DerivationEngine` en isolate → `day_result`/`metric_series` → la UI solo lee
  (`local_repository_impl.dart`). Ver DATA_FLOW.md.
- Estado con `provider`/`ChangeNotifier`. UI solo con tokens de `lib/ui2/`.
- Comentarios con `ponytail:` marcan simplificaciones conscientes (skill `ponytail`).

## 2. Ejecutar y probar

```bash
flutter pub get
flutter analyze
flutter test --concurrency=1            # obligatorio --concurrency=1
flutter test test/<archivo>_test.dart   # un archivo
```

Flutter **3.41.6** exacto. En la sesión de agente **no hay toolchain**: los
tests y el IPA se lanzan en GitHub Actions con `gh` siguiendo
**CI_RUNBOOK.md** (rama → `test-files.yml` → id del run en PROGRESS.md). Nunca afirmes validación en
hardware: "unit‑tested, not hardware‑validated". Línea base de fallos y
evidencias: PROGRESS.md.

## 3. Qué leer antes de tocar cada módulo

| Vas a tocar… | Lee antes |
|---|---|
| `lib/ble/`, `lib/sync/` | AGENTS.md §3 (1, 2, 12, 14, 15) y §4.3; WHOOP_INTEGRATION.md |
| `lib/data/db.dart` (esquema) | AGENTS.md §3.11; DATA_MODEL.md; DATABASE_AUDIT.md |
| `lib/compute/` | AGENTS.md §3.3–3.10, §4.1–4.2; ALGORITHMS.md; DATA_FLOW.md |
| Una fórmula | ALGORITHMS.md; ALGORITHM_EVALUATION.md; el archivo en `openstrap_analytics` (su cabecera explica lo descartado) |
| `lib/ui2/` | `lib/ui2/README.md`; UI_UX_AUDIT.md |
| `lib/notify/` | AGENTS.md §4.6 |
| `lib/coach/`, `lib/ai/` | SECURITY.md; AGENTS.md §3.13 |
| Datos reales / exportaciones | §6 de esta guía; DATA_QUALITY.md; `analysis/README.md` |

## 4. Añadir una funcionalidad

1. Comprueba que no exista: FEATURES.md, FEATURE_IDEAS.md, PLANNING.md.
2. Coge la especificación de IMPROVEMENT_BACKLOG.md (qué/por qué/dónde/cómo/prueba).
3. Rama por tarea, diff mínimo, sin refactors de paso.
4. Si añades componente UI: galería (`ui2/profile/gallery.dart`) y l10n en
   los 7 idiomas (el español tiene test de cobertura).
5. Si añades tabla: migración aditiva e idempotente + `_repairOpenSchema` +
   test de migración + `schemaVersion`.

## 5. Modificar un algoritmo

1. Cambio en `openstrap_analytics` con test (incluido "entrada ausente → null").
2. Re‑pin por **SHA completo** en `pubspec.yaml` y `pubspec.lock`; verifica que
   el SHA contiene el cambio (AGENTS.md §3.5–3.6).
3. Sube `kAlgoVersion` con entrada de changelog encima de la constante.
4. Actualiza ALGORITHMS.md y, si cambia la valoración, ALGORITHM_EVALUATION.md.
5. Re‑ejecuta `docs/development/analysis/*.py` y compara agregados.
6. Recuerda: solo se re‑derivan los días con sustrato vivo hasta que exista DATA‑02.

## 6. Trabajar con datos biométricos

- **Nunca inventes** un valor: ausente ⇒ `null`/"—" (invariante 3). La única
  excepción aceptada es FP‑CAL (gris, solo lectura, D‑08).
- PRV ≠ ECG; piel de muñeca ≠ temperatura corporal; fases ≠ PSG; "steps" de
  gen5 es un contador de nombre heredado.
- Día local con `day_label.dart`; tiempos en s **o** ms según la tabla
  (DATA_DICTIONARY.md §1).
- Baseline: excluye el día objetivo; usa `trailingSeriesValues`, nunca
  `metricSeries(limit:)` para una ventana reciente.
- **Privacidad:** trabaja sobre una copia en solo lectura; no subas
  exportaciones a ningún servicio; en Markdown, issues y PRs solo agregados y
  ejemplos sintéticos; las exportaciones `.db` nunca entran en el repo.

## 7. Qué actualizar cuando cambias algo

| Cambio | Actualiza |
|---|---|
| Cualquier trabajo con sentido | PROGRESS.md (entrada nueva arriba, con evidencia) y PLANNING.md |
| Funcionalidad | FEATURES.md; si estaba propuesta, FEATURE_IDEAS.md / IMPROVEMENT_BACKLOG.md |
| Algoritmo | ALGORITHMS.md, ALGORITHM_EVALUATION.md, changelog de `kAlgoVersion` |
| Esquema | DATA_MODEL.md, DATA_DICTIONARY.md |
| Flujo BLE/sync/derivación | DATA_FLOW.md, WHOOP_INTEGRATION.md |
| Decisión de diseño | DECISIONS.md |
| UI relevante | UI_UX_AUDIT.md (marca el problema como resuelto) |

## 8. Restricciones que no deben romperse

1. Los 15 invariantes de AGENTS.md §3.
2. No editar `AGENTS.md` ni archivos de upstream solo para añadir notas del fork.
3. No subir `kAlgoVersion`, `schemaVersion` ni pins sin el proceso completo.
4. No commits, push ni resets sin que el propietario lo pida.
5. No refactorizar los hotspots en el fork (D‑02).
6. No usar ACWR como predictor (D‑05) ni presentar aproximaciones como el
   algoritmo oficial de WHOOP (D‑06).
7. No activar telemetría en builds propias (SECURITY.md SEC‑05).
