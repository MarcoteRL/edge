# Funcionalidades existentes (inventario del fork)

> Fecha: 2026-11-12 · App `0.11.3+78`, commit `15d791a0`. Complementa `docs/FEATURES.md`
> (upstream, orientado a usuario) con **dónde** está cada cosa, **qué datos**
> usa, **qué algoritmo** y **en qué estado** está **para tu WHOOP 5.0**.
> Estado: ✅ completa · 🟡 parcial o con limitación relevante · ⏳ depende de
> histórico · 🧪 experimental.

## 1. Núcleo

| Funcionalidad | Dónde | Datos | Algoritmo | Dependencias | Limitaciones | Estado |
|---|---|---|---|---|---|---|
| Emparejado y sync BLE | `lib/ble/ble_engine.dart`, `ble/adapters/whoop_gen4.dart`, `ui2/onboarding/pairing.dart`, `ui2/pairing/` | Flash de la banda | — | `flutter_blue_plus`, `openstrap_protocol` | iOS: segundo plano oportunista | ✅ |
| Aviso de firmware | `ui2/pairing/whoop_firmware_warning.dart` | versión de firmware | — | — | — | ✅ |
| Derivación local | `lib/compute/*` | 1 Hz + RR | ALGORITHMS.md | `openstrap_analytics` | Re‑derivación solo de días vivos | ✅ |
| Backups cifrados y exportación de la base | `lib/data/auto_backup.dart`, `lib/import/backup_crypto.dart`, `ui2/profile/data.dart` | Toda la base | AES‑GCM con passphrase | `flutter_secure_storage` | — | ✅ |
| CSV / GPX | `lib/data/csv_export.dart`, `lib/gps/` | derivado / rutas | — | — | — | ✅ |
| Aviso de caducidad de sideload (fork) | `lib/platform/provisioning.dart`, `ios/Runner/AppDelegate.swift` | `embedded.mobileprovision` | — | — | Solo iOS sideload | ✅ (sin validar en dispositivo) |

## 2. Hoy (Home) — rediseño UX‑02…UX‑06 (2026‑11‑09/10)

| Funcionalidad | Dónde | Datos | Estado |
|---|---|---|---|
| Titular "B+": Recovery grande con "▲/▼ n vs ayer" o "mejor de la semana", y barras Recovery / Sueño / Strain (con banda objetivo de strain) | `ui2/screens/home_screen.dart`, `HomeBarPainter` (`charts.dart`) | `readiness`, `tst_min`/necesidad, `strain`, `strain_target` | ✅ (solo puntuaciones finales para la comparación) |
| Estimación de calibración gris ("Calibrating · n of 14") | `lib/compute/calibration_estimate.dart` vía `getToday` | entradas nocturnas + referencia poblacional | 🟡 decisión del propietario; sin validar (ALG‑R1) |
| Fila de constantes: HRV, RHR, respiración con flecha y "Usual …" frente a los 28 días previos | `home_screen.dart` (`usualBefore`, `kUsualMinDays` = 14) | `metric_series` | ⏳ abstiene < 14 días |
| Tarjeta del coach (briefing matinal) | `home_screen.dart`, `lib/ai/briefing_engine.dart` | vistas del coach + log de fuerza | 🟡 requiere proveedor de IA (BYOK / ChatGPT / Gemini) |
| Franja del día: noche, sesiones y curva de FC | `home_screen.dart` (`getDayTimeline`) | `day_result`, `sessions` | ✅ |
| Bloque de entrenamiento: última sesión (con su día), récords, series de trabajo por grupo en 7 d, días desde cada grupo | `lib/data/strength_summary.dart` | `strength_set`, `exercise_def`, `sessions` | ✅ |
| Actividades del día | `home_screen.dart` (`sessionsOfDay`) | `sessions` | ✅ |
| Estado de sync en la cabecera ("Syncing… / Synced through …") | `home_screen.dart` (`_syncLine`) | estado de sync | ✅ |
| "I'm awake": cierra la noche y la puntúa al momento | `AppState.markAwakeNow` | `sleep_override` (`manual`) | ✅ (usado en 2/3 noches) |
| Noche visible 15 min tras despertar (provisional) | `local_repository_impl.dart` (`overnight_provisional`) | — | ✅ |
| Una observación del día | `home_screen.dart` | hallazgos | ✅ |

## 3. Salud

| Funcionalidad | Dónde | Datos | Algoritmo | Estado |
|---|---|---|---|---|
| Resumen (RHR, HRV, sueño, estrés, resp.) con flecha de tendencia | `ui2/screens/health_screen.dart` | `metric_series` | z/tendencia | ✅ |
| Detalle de métrica y tendencias | `metric_detail.dart`, `ui2/trend.dart`, `month_grid.dart` | `metric_series` | — | ✅ |
| Readiness con desglose de *drivers* | `readiness_detail.dart`, `driver_breakdown.dart` | `clinical.readiness_composite` | composite | ⏳ |
| "Qué cambió" | `what_changed.dart` | baselines | MDC | ⏳ |
| Investigar un día | `investigate.dart` | payload del día | — | ✅ |
| Ritmo circadiano | `circadian_detail.dart` | multi‑día | cosinor, IS/IV | ⏳ 7 días |
| Latidos / HRV puntual | `beats.dart` | RR en vivo | RMSSD | ✅ |
| Ritmo irregular (cribado) | `health_screen.dart` (observaciones) | RR 24 h | Poincaré + pNN70 | 🟡 falsos positivos probables (Q‑04) |
| ECG | `ecg.dart`, `lib/ecg/` | solo WHOOP MG | — | ❌ no aplica a 5.0 |
| Edad fisiológica (fork) | `healthspan_screen.dart`, `lib/compute/healthspan.dart` | 6 meses de métricas | 9 contribuyentes | ⏳ |
| Hallazgos | `findings_log.dart`, `lib/compute/findings.dart` | — | — | ✅ |

## 4. Sueño

| Funcionalidad | Dónde | Estado |
|---|---|---|
| Detalle de noche: duración, en cama, eficiencia, hipnograma, ciclos | `sleep_detail.dart`, `sleep_tab.dart` | 🟡 fases de baja fiabilidad |
| Corregir ventana / "no era sueño" | `sleep_detail.dart` → `sleep_override` | ✅ (usado 3 veces) |
| Siestas | `naps.dart`, `lib/compute/accepted_naps.dart` | ✅ |
| Coach de sueño (necesidad, hora de acostarse, despertar) | `crossday_pipeline.dart` | ⏳ ≥ 3 noches libres |
| Alarma inteligente | `ui2/profile/alarm.dart`, `lib/state/smart_wake.dart` | 🟡 issue upstream #186 |
| Noche dura / alcohol (sin causa) | `rough_night.dart` | ✅ |

## 5. Entrenamiento

| Funcionalidad | Dónde | Estado |
|---|---|---|
| Registro de sesión en vivo con zonas y GPS | `ui2/activity/live.dart`, `lib/state/workout_controller.dart` | ✅ |
| Catálogo de 74 actividades | `ui2/activity/catalogue.dart` | ✅ |
| Fuerza: series, ejercicios (wger) | `log_workout.dart`, `exercise_picker.dart`, `strength_set` | ✅ (sin carga interna sRPE) |
| Import Hevy por API (Hevy Pro), sincronización cada 4 h, músculos por ejercicio | `lib/import/hevy_import.dart`, `ui2/profile/hevy_screen.dart` | ✅ (sin probar contra la API real) |
| Auto‑detección y revisión de actividades | `detected_activities.dart`, `activity_suggestions` | ✅ |
| Strain del día y de la sesión | `ui2/activity/day_strain.dart`, `manual_session.dart` | ⏳ 3 días |
| Carga (CTL/ATL) | `workout_screen.dart` ("Training load") | 🟡 Q‑05 |
| Zonas editables | `ui2/activity/zones.dart` | ✅ |
| Recuperación de FC post‑sesión | `hr_recovery.dart` | ✅ |
| Póster / compartir resumen | `ui2/activity/poster.dart`, `share.dart` | ✅ |

## 6. Bienestar, nutrición y registro

| Funcionalidad | Dónde | Estado |
|---|---|---|
| Diario con correlaciones | `journal_compose.dart`, `custom_journal_field_sheet.dart` | ✅ (sin uso aún) |
| Estrés y respiración guiada (coherencia) | `wellness_screen.dart`, `calm_breathing.dart`, `lib/stress/` | ✅ |
| Nutrición, código de barras | `nutrition_screen.dart`, `log_food.dart`, `scan_barcode.dart` | ✅ |
| Medicación, agua (zumbido en la banda) | `lib/notify/med_buzzer.dart`, `water_buzzer.dart` | ✅ |
| Ciclo menstrual | `cycle_screen.dart` | ✅ |
| Analíticas (CSV) | `lib/import/lab_csv_import.dart` | ✅ |

## 7. Coach, notificaciones e integraciones

| Funcionalidad | Dónde | Estado |
|---|---|---|
| Coach determinista + IA BYOK / ChatGPT / Gemini (con modelo de reserva), respuesta en el idioma de la app | `coach.dart`, `lib/coach/` | ✅ (solo vistas `v_*`, incl. `v_strength_sets`) |
| Notificaciones con deduplicación | `lib/notify/notification_center.dart`, `fired_keys.dart` | ✅ |
| Apple Health / Health Connect | `lib/health/` | 🟡 issue upstream #558 (FC a Apple Health) |
| Widgets, Live Activities, Watch, Atajos | `lib/widget/`, `ios/OpenStrapWidget`, `ios/OpenStrapWatch Watch App` | 🟡 App Groups con sideload gratuito |
| Gestos de la banda (doble toque) | `lib/gestures/`, `ui2/profile/gestures.dart` | ✅ |
| Otros wearables | `lib/ble/adapters/*` | 🧪 |
| Import WHOOP oficial | `lib/import/whoop_import.dart` | 🧪 BETA |
| Recap semanal compartible | Home / `share.dart` | ✅ |

## 8. Lo que no existe todavía

Tendencias 7/14/30/90 con significancia, comparación de periodos, informes
semanales automáticos en la app, experimentos personales, carga interna de
fuerza (sRPE), recomendación diaria de intensidad determinista (hoy depende del
coach con IA), bienestar subjetivo diario,
registro de recomendaciones. Ver FEATURE_IDEAS.md.
