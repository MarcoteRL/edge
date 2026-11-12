# Tests y validación

> Fecha: 2026-11-12. Fuente: `test/` (611 entradas en el primer nivel,
> subcarpetas `adapters/`, `ble/`, `fixtures/`, `support/`, `ui2/`; ~5 900
> llamadas `test(`), `.github/workflows/`, PROGRESS.md.

## 1. Cómo se ejecuta

| Dónde | Comando | Notas |
|---|---|---|
| Tu PC (Windows) | `flutter analyze` y `flutter test --concurrency=1` | Flutter **3.41.6** exacto. `--concurrency=1` es obligatorio: los tests comparten ficheros sqflite |
| Un fichero | `flutter test test/readiness_flash_test.dart` | |
| CI | `test.yml` (desactivado en tu repo por coste), `test-files.yml` (subconjunto) | Ver CLAUDE.md para reactivarlo |
| iOS | `ios-sideload.yml` (macOS en CI) | No se puede compilar iOS en Windows |
| Sesión de agente | **No hay toolchain**: `gh workflow run test-files.yml …` | Ver CI_RUNBOOK.md; el analizador debe salir limpio (info incluidos) |

Línea base conocida: 8 fallos preexistentes de upstream (l10n/galería),
corregidos en el fork por CI‑05. Cualquier fallo nuevo es regresión
(PROGRESS.md).

## 2. Qué está bien cubierto

- Políticas BLE/sync puras (`ble_state.dart`, `sync_policy.dart`).
- Regresiones de readiness (flash, freeze, saturación, contaminación del
  baseline, calibración).
- Strain y nivel de reposo (`strain_quiet_level_test.dart`,
  `strain_rescale_backfill_test.dart`, `day_strain_dst_grid_test.dart`).
- Sueño: correcciones, zonas horarias, overrides.
- Sistema de diseño: contraste, escala de texto, objetivos táctiles, tokens.
- El paquete de analítica tiene sus propios tests de calibración
  (`readiness_calibration_test.dart`, `strain_calibration_test.dart`).

## 3. Huecos

| ID | Hueco | Propuesta |
|---|---|---|
| T‑01 | Ningún test de CTL/ATL con días no llevados | Test de ALG‑L1 con calendarios sintéticos |
| T‑02 | ~~Contrato `payload_json` ↔ read seam~~ **hecho**: `test/payload_contract_test.dart` + `test/fixtures/day_payload_contract.json` (262 rutas; se regenera con `tool/payload_contract.py` tras una subida de versión) | — |
| T‑03 | Cribado irregular en días solo diurnos | Fixture sintético con RR diurno ruidoso → debe abstener (ALG‑C1) |
| T‑04 | Temperatura gen5 en readiness | Test de que la entrada no se rechaza con banda de asentamiento definida (ALG‑R3) |
| T‑05 | ~~Re‑derivación desde archivo~~ **hecho**: `test/archive_rederive_test.dart` (ida y vuelta byte a byte, solo lectura, idempotencia, fallos, cesión; con `tz=Europe/Madrid` cubre dos días UTC y cambio de hora) | — |
| T‑06 | Validación con datos reales | Golden de derivación con una base sintética (generada, no la tuya) |

## 4. Cómo validar un cambio de algoritmo

1. Test unitario en `openstrap_analytics` con casos sintéticos (incluido
   "entrada ausente → null").
2. Re‑pin en `pubspec.yaml` + entrada en el changelog de `kAlgoVersion`.
3. `flutter test` completo en tu PC.
4. Re‑ejecutar `docs/development/analysis/*.py` sobre tu exportación y
   comparar agregados antes/después (sin pegar valores individuales).
5. Escribir en PROGRESS.md: "unit‑tested, not hardware‑validated" hasta que
   corra en tu banda.
