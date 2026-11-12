# Visión general del proyecto

> Fecha: 2026-11-12 · commit `15d791a0` · app `0.11.3+78` ·
> `kAlgoVersion 120` · `schemaVersion 58`.

## Qué es

Fork personal de **OpenStrap `edge`**: una app Flutter (iOS y Android) que
lee una WHOOP por Bluetooth **sin la suscripción ni la nube de WHOOP**, guarda
todo en SQLite en el móvil y calcula en el propio dispositivo sueño, HRV,
recuperación, strain, estrés y decenas de métricas más con métodos publicados.

El objetivo del fork: convertirlo en una plataforma personal de rendimiento y
salud **más transparente y personalizable que WHOOP**, basada en tus propios
datos.

## Cómo está construido (en una frase por capa)

| Capa | Tecnología | Dónde |
|---|---|---|
| Bytes de la banda | Paquete Dart `openstrap_protocol` (fijado por SHA) | repo `OpenStrap/protocol` |
| Métricas | Paquete Dart `openstrap_analytics` (fijado por SHA) | repo `OpenStrap/analytics` |
| BLE y sincronización | `flutter_blue_plus`, máquina de estados propia | `lib/ble/`, `lib/sync/` |
| Persistencia | `sqflite` (WAL), 70 tablas, migraciones aditivas | `lib/data/db.dart` |
| Orquestación de cálculo | Isolates, derivación por día y multi‑día | `lib/compute/` |
| Estado | `provider` + `ChangeNotifier` | `lib/state/` |
| UI | Sistema de diseño propio con tests de accesibilidad | `lib/ui2/` |
| Plataforma | Swift (BG tasks, HealthKit, widgets, Watch), Kotlin | `ios/`, `android/` |

Tamaño: ~310 archivos Dart en `lib/` (~200 k líneas), ~610 archivos de test.

## Cómo funciona (flujo)

Banda → BLE → decodificar → guardar (y solo entonces confirmar a la banda) →
derivar en segundo plano → guardar resultados versionados → la UI solo lee.
Detalle: DATA_FLOW.md.

## Estado actual

- **Maduro y bien documentado** en upstream; el fork añade CI de sideload iOS,
  traducción completa al español, edad fisiológica, aviso de caducidad,
  rediseño de Home, estimaciones de calibración, import de Hevy y arreglos de
  sueño (PROGRESS.md).
- **Tus datos:** 3 noches completas. Casi toda la inteligencia está esperando
  histórico (DATA_QUALITY.md §2).
- **Validación:** tests unitarios en tu PC; nada validado en hardware salvo lo
  que dice PROGRESS.md.

## Qué falta

Proteger el histórico (re‑derivación desde archivo), capturar una verdad de
referencia diaria (cómo te sientes, RPE), corregir lo que engaña (carga con
días sin datos, cribado irregular diurno) y construir tendencias, decisión
explicable y experimentos personales. Ver AUDIT_SUMMARY.md y ROADMAP.md.
