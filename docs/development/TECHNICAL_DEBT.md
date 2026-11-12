# Deuda técnica

> Fecha: 2026-11-12. Amplía TECHNICAL_AUDIT.md (F‑01…F‑05, 2026‑11‑09) con
> lo encontrado al cruzar código y datos reales. IDs estables; cada uno está en
> IMPROVEMENT_BACKLOG.md.

## 1. Decisiones técnicas acertadas que hay que conservar

| Decisión | Por qué es buena | Dónde |
|---|---|---|
| Separación protocol / analytics / edge | Cada capa testeable y versionable por SHA | AGENTS.md §1, `pubspec.yaml` |
| Commit antes de ACK | Imposible perder datos de la banda por un cierre | `ble_engine.dart` (invariante 1) |
| Derivado inmutable por `kAlgoVersion` | Auditoría y reproducibilidad | `day_result` |
| Política "nunca inventar" con notas legibles por máquina | Confianza y depuración | `Metric`, `need_baseline:` |
| Políticas puras extraídas (`ble_state.dart`, `sync_policy.dart`) | BLE testeable sin hardware | `lib/ble/`, `lib/sync/` |
| Cálculo pesado en `Isolate.run` | Sin ANR | `lib/compute/` |
| Sistema de diseño con tests de contraste, escala de texto y objetivos táctiles | Accesibilidad automática | `test/ui2_*` |
| Tests de regresión con nombre del bug | Memoria del proyecto | `test/readiness_*_test.dart` |
| Algoritmos documentados en la cabecera con su evidencia y lo descartado | Evita repetir errores | `openstrap_analytics` |
| Archivo comprimido del sustrato | Base para re‑derivar | `lib/data/substrate_archive.dart` |

## 2. Deuda detectada

| ID | Tipo | Descripción | Evidencia | Impacto | Esfuerzo |
|---|---|---|---|---|---|
| TD‑01 | Arquitectura | Archivos gigantes: `data/db.dart`, `compute/derivation_engine.dart`, `ble/ble_engine.dart`, `state/app_state.dart` (≈ 48 k líneas) concentran la mayoría de fixes | AGENTS.md §2, TECHNICAL_AUDIT | Riesgo de regresión | L — **no refactorizar en el fork** (conflictos con upstream) |
| TD‑02 | Datos | `samples` duplica `decoded_onehz.hr` (~20 % de la base) | DATABASE_AUDIT DB‑01 | Disco, tiempo de backup | S (upstream) |
| TD‑03 | Datos | `raw_archive_frames` sin poda para v26 | DB‑02 | Crecimiento ~0,4 MB/día | S |
| TD‑04 | Datos | Unidades de tiempo mezcladas s/ms | DB‑03 | Bugs en consultas manuales y en el coach | Documentar (hecho); no migrar |
| TD‑05 | Datos | `metric_method` con nombre engañoso | DB‑04 | Confusión | Documentar |
| TD‑06 | Datos | `payload_json` sin esquema declarado | DB‑05 | Contrato implícito entre pipeline y UI | M: test de contrato que congele las claves leídas por `local_repository_impl.dart` |
| TD‑07 | Algoritmo | Serie de TRIMP densa con 0 para días sin datos | Q‑05 | CTL/ATL engañosos | M (ALG‑L1) |
| TD‑08 | Algoritmo | Sin banda de asentamiento de temperatura para gen5 | Q‑02 | Temperatura nunca en readiness | M (ALG‑R3) |
| TD‑09 | Algoritmo | `glassBoxReadiness` deprecado pero aún calculado y guardado (`crossday.readiness_glassbox`) | `crossday_pipeline.dart` | Coste y confusión | S (upstream) |
| TD‑10 | Re‑derivación | `substrate_archive` solo escribe; ninguna ruta lo lee para derivar | `substrate_archive.dart` cabecera | Cambios de algoritmo no llegan al histórico | M (O‑01) |
| TD‑11 | Docs | `lib/ui2/README.md` dice "cuatro pestañas"; hay cinco | `app_shell.dart` | Menor | S |
| TD‑12 | Docs | Cabecera de `substrate.dart` describe un modelo de día que ya no existe | AGENTS.md cabecera | Menor | S |
| TD‑13 | Operación | Sin toolchain en la sesión de agente; tests solo en el PC del propietario | CLAUDE.md, PROGRESS.md | Ciclo de validación lento | Proceso (TESTING.md) |
| TD‑14 | Escalabilidad | 1 Hz ≈ 15 MB/día en vivo; el archivo indefinido ≈ 0,6 GB/año | `SubstrateArchivePolicy` | Disco del móvil | Aceptable; ofrecer exportar archivo |
| TD‑15 | Dependencias | `flutter pub outdated` y avisos de seguridad sin revisar | PLANNING AUD‑03 | Desconocido | S (en tu PC) |

## 3. Rendimiento

No medido en dispositivo en esta sesión. Señales estáticas:
- Payload por día completo 75–82 KB; la lectura de Home deserializa JSON
  grande en el hilo de UI si la pantalla lo pide entero. Revisar con el
  profiler antes de optimizar.
- Índices de `decoded_onehz` ≈ 9,4 MB para 4 días: proporcionales y razonables.

## 4. Errores potenciales (para revisar, no confirmados)

- Q‑06: `rhr_nocturnal` igual a `rhr` en todas las noches; si la intención era
  medirlo distinto, hay un cableado duplicado.
- `sessions.strain` vacío en la sesión con traza tras 2 días: confirmar que
  `strain_backfill.dart` la rellena cuando el nivel de reposo exista.
- ALG‑C2: RR en 333/2400 ms exactos.
