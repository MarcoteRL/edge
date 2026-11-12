# Guía de desarrollo

> Fecha: 2026-11-12. Para el propietario y para agentes. Lo general de
> upstream está en `docs/DEVELOPMENT.md` y `CONTRIBUTING.md`; aquí lo
> específico del fork.

## 1. Entorno

- Flutter **3.41.6** exacto (fijado en todos los workflows). Dart `^3.11.4`.
- Windows: Android y tests. iOS solo en CI (`ios-sideload.yml`) → IPA sin
  firmar → Sideloadly.
- Siblings: para trabajar en analytics/protocol en local, clónalos al lado y
  crea `pubspec_overrides.yaml` (ignorado por git; **nunca** lo commitees).

## 2. Ejecutar

```bash
flutter pub get
flutter run                       # dispositivo/emulador
flutter analyze
flutter test --concurrency=1
```

`--dart-define`s opcionales: `COMPANION_URL`, `BACKEND_URL` (vacío = apagado),
`ENABLE_HEALTH_DATA_CONTRIBUTION` (false).

## 3. Dónde va cada cambio

| Cambio | Repo / carpeta | Checklist |
|---|---|---|
| Nuevo opcode o formato de registro | `OpenStrap/protocol` | Re‑pin; sin bump si no cambia salida |
| Nueva métrica o cambio de fórmula | `OpenStrap/analytics` | Re‑pin + bump `kAlgoVersion` + changelog + test |
| Qué datos se pasan a una métrica | `lib/compute/` | Bump si cambia una salida |
| Nueva tabla o columna | `lib/data/db.dart` | Migración aditiva e idempotente, `_repairOpenSchema`, test de migración, bump `schemaVersion` |
| Pantalla o componente | `lib/ui2/` | Tokens, añadir a la galería, l10n (7 idiomas, ES obligatorio por test de cobertura) |
| Notificación | `lib/notify/notification_center.dart` | Solo vía `NotificationCenter.emit` |
| Módulo propio del fork | `lib/compute/healthspan.dart` como ejemplo | Cabecera con citas; tests |

## 4. Trabajar con datos biométricos

- Ausente ⇒ `null` y "—". Nunca 0, nunca valor por defecto (invariante 3).
- Etiquetas de día solo con `lib/data/day_label.dart`.
- Ventanas de baseline: `trailingSeriesValues(key, n)`, no
  `metricSeries(limit: n)` (devuelve los más antiguos).
- Excluir el día objetivo de su propio baseline.
- PRV de muñeca ≠ ECG; temperatura de muñeca ≠ corporal; fases ≠ PSG.

## 5. Analizar tu exportación

Ver `docs/development/analysis/README.md`. Copia el `.db` fuera del repo,
ábrelo en solo lectura, y documenta solo agregados.

## 6. Flujo de trabajo del fork

Rama por tarea, diff mínimo, PROGRESS.md y PLANNING.md al terminar, y PR a
upstream cuando el arreglo les sirva (CLAUDE.md, "Scope discipline").
