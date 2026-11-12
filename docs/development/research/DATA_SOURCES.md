# Fuentes de datos

> Fecha: 2026-11-12. Qué entra en la app, por dónde y con qué confianza.

| Fuente | Código | Qué aporta | Granularidad | Entra en baselines | Estado en tu base |
|---|---|---|---|---|---|
| WHOOP 4.0/5.0/MG por BLE | `lib/ble/ble_engine.dart` → `RecordGate` → `LocalDb` | 1 Hz, RR, eventos | segundo / latido | Sí | Activa |
| Stream en vivo (0x28/0x2B/0x33) | `lib/state/live_stream_controller.dart` | FC en tiempo real | alta | **Nunca se persiste** (invariante 14) | — |
| Exportación oficial WHOOP "My Data" | `lib/import/whoop_import.dart` (BETA) | Recovery, sueño, strain, entrenos de WHOOP | diaria | **No** (día `imported`) | No usada |
| Backup / NOOP | `lib/import/noop_import.dart`, `backup_crypto.dart` | Restaurar 1 Hz completo | segundo | Sí | — |
| Hevy (API, requiere Hevy Pro) | `lib/import/hevy_import.dart`, `ui2/profile/hevy_screen.dart` → `sessions` + `strength_set`; se adjunta a la sesión de banda solapada; vista `v_strength_sets` para el coach | Series, reps, kg, músculos (`exercise_def`) | serie | No | 24 sesiones, 503 series (anteriores a la banda: sin FC) |
| Apple Health / Health Connect (lectura) | `lib/health/*_import.dart` | Entrenos, medidas, perfil, RHR inicial | variable | Según tipo | Sin datos importados |
| Apple Health / Health Connect (escritura) | `lib/health/health_export.dart` | Exporta sueño, RHR, HRV, resp., energía, entrenos | — | — | — |
| Otros dispositivos BLE | `lib/ble/adapters/*` | Oura, Polar, Garmin… (experimental) | variable | Solo los verificados | — |
| Laboratorio (CSV) | `lib/import/lab_csv_import.dart` | Analíticas | evento | No | Vacío |
| Diario | `lib/ui2/screens/journal_compose.dart` → `journal*` | Hábitos, etiquetas | diario | Para correlaciones | Vacío |
| GPS | `lib/gps/` | Rutas | segundo | — | Vacío |

## API oficial de WHOOP

La API para desarrolladores de WHOOP (developer.whoop.com) expone recovery,
sueño, ciclos y entrenos **ya calculados** y requiere cuenta de WHOOP. Sin
suscripción no es una vía útil, y además no da datos 1 Hz. Este proyecto lee la
banda directamente, que es la única fuente de datos crudos.

## Riesgo de firmware

Firmware ≥ 50.43 pide un token firmado (issue upstream #673, ver
TECHNICAL_AUDIT.md). Tu banda reporta 50.38.1.0 (`compute_freshness.band_firmware`).
**No dejes que la app oficial actualice la banda.**
