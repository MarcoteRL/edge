# Resumen ejecutivo de la auditoría

> **Contrastada con el código en la iteración 1 (2026‑11‑12):** varias
> afirmaciones de abajo están corregidas o matizadas en
> [AUDIT_VERIFICATION.md](AUDIT_VERIFICATION.md) (fases como rango y RPE ya
> existen; "piezas sin producto" es parcial; `kAlgoVersion` es 121).

> Fecha: 2026-11-12 · commit `15d791a0` · `kAlgoVersion 120` ·
> `schemaVersion 58` · analytics `3a7ca34` · protocol `b4fde6a`.
> Alcance: código del fork, paquetes de analítica y protocolo en sus pins,
> exportación real de tu base (WHOOP 5.0) y literatura. Sin toolchain Flutter
> en la sesión: **no se ejecutaron tests ni la app**; lo verificado se verificó
> leyendo código y recalculando sobre los datos.

## 1. Estado actual

Un proyecto **técnicamente sólido y honesto**: arquitectura en tres capas,
ingesta BLE que no puede perder datos, resultados versionados e inmutables,
algoritmos publicados con su evidencia en el código y una regla de "nunca
inventar" que se cumple. El fork ya ha añadido CI de iOS, español completo,
rediseño de Home, estimaciones de calibración, import de Hevy y arreglos de
sueño.

Tu base tiene **3 noches**. La app hace lo correcto (abstenerse), pero significa
que casi toda la inteligencia que quieres construir **todavía no tiene datos**
para funcionar ni para validarse.

## 2. Calidad de la arquitectura

| Aspecto | Nota | Comentario |
|---|---|---|
| Separación de responsabilidades | Alta | protocol / analytics / edge |
| Integridad de datos | Alta | commit antes de ACK, REPLACE por segundo, 0 errores de sync en 4 649 lotes |
| Reproducibilidad | Alta | RHR, RMSSD, TRIMP y nivel de reposo recalculados desde el crudo: 0–3 % de diferencia |
| Mantenibilidad | Media | 4 archivos gigantes con la mayoría de los arreglos; no tocarlos en el fork |
| Tests | Alta | ~5 900 casos; tests de regresión por bug; accesibilidad automatizada |
| Re‑derivación histórica | Baja | el archivo comprimido existe pero nada lo lee |

## 3. Funcionalidades existentes

Sincronización BLE y en segundo plano; sueño (ventana, fases, ciclos, siestas,
correcciones, "I'm awake"); HRV, RHR, respiración, estrés; recovery con desglose
y estimación gris; strain diario y por sesión con zonas; carga CTL/ATL; fuerza
(registro, Hevy por API, series por grupo muscular); coach determinista y con
IA (BYOK/ChatGPT/Gemini); diario con correlaciones; nutrición, medicación,
ciclo, analíticas; Apple Health/Health Connect; widgets, Live Activities, Watch;
backups cifrados; edad fisiológica. Detalle y estado: FEATURES.md.

## 4. Principales problemas

| # | Problema | Evidencia | Doc |
|---|---|---|---|
| 1 | **El histórico podado no se puede recalcular** | `substrate_archive` solo se escribe | TD‑10, DATA‑02 |
| 2 | **CTL/ATL cuentan días sin banda como descanso** | 3 días reales + 12 ceros ⇒ carga presente | Q‑05, ALG‑L1 |
| 3 | **Cribado de ritmo irregular con falsos positivos probables** | bandera en 3/3 días solo diurnos, 0/4 noches | Q‑04, ALG‑C1 |
| 4 | Temperatura nunca entra en readiness con WHOOP 5 | sin banda de asentamiento gen5 | Q‑02, ALG‑R3 |
| 5 | La estimación de calibración usa una referencia poblacional sin validar | `calibration_estimate.dart` | ALG‑R1 |
| 6 | Strain solo cardiovascular: la fuerza puntúa bajo | modelo de Banister | ALG‑L2 |
| 7 | Fases de sueño poco fiables (κ 0,13 declarado) mostradas con precisión aparente | `cardio_stager.dart` | ALG‑S2 |
| 8 | "I'm awake" y una edición manual se guardan igual | `sleep_override.source = 'manual'` | DATA‑06 |
| 9 | Exportaciones `.db` no ignoradas por git; exportación en claro | `git check-ignore` | SEC‑09, SEC‑02 |
| 10 | `samples` duplica la FC (~20 % de la base) | perfilado | DB‑01 |

## 5. Principales oportunidades

1. **Verdad de referencia diaria** (tarjeta matinal + RPE): convierte la app en
   algo validable.
2. **"I'm awake" ya es una etiqueta de despertar**: permite medir el error del
   final de la noche (la banda sobreestima el final 0,5–2,7 h).
3. **Archivo indefinido + re‑derivación**: tu historia mejora con cada versión.
4. **Piezas ya implementadas sin producto**: CUSUM, Mahalanobis, MDC,
   `weekdayEffect`, `session_cost`, correlaciones con permutaciones.
5. **Validación frente a WHOOP** con tu exportación oficial (`whoop_import.dart`).

## 6. Mejoras de algoritmos más interesantes

| ID | Mejora | Por qué |
|---|---|---|
| ALG‑L1 | Días desconocidos fuera de la EWMA | Carga honesta |
| ALG‑C1 | Cribado irregular en reposo | Quitar alarmas falsas |
| ALG‑T1 | Tendencias 7/14/30/90 con Theil‑Sen, MDC y SWC | "¿Cómo evoluciono?" sin ruido |
| ALG‑R1 | Validar FP‑CAL contra el real; alternativa Plews intra‑persona | Que el gris no engañe |
| ALG‑L2 | sRPE + tonelaje como segunda carga | Usuario de fuerza |
| ALG‑H1 | CV de lnRMSSD 7 d | Señal de inestabilidad publicada |
| ALG‑R3 | Temperatura gen5 en readiness | Usar una señal que ya tienes |

## 7. Mejoras visuales prioritarias

1. Progreso de calibración por métrica (y explicar el gris).
2. Banda personal + MDC en lugar de flechas en Health.
3. Línea de decisión determinista bajo el titular de Home (sin depender de IA).
4. Fases de sueño como rango; duración, horario y regularidad primero.
5. Workout centrado en la carga semanal (cardio y fuerza por separado).

Detalle: UI_UX_AUDIT.md.

## 8. Las 10 funcionalidades nuevas con mayor potencial

| # | ID | Funcionalidad |
|---|---|---|
| 1 | FI‑F1 | Archivo indefinido + re‑derivación del histórico |
| 2 | FI‑B4 | Tarjeta matinal de 10 s |
| 3 | FI‑A1 | Recomendación diaria de intensidad explicada |
| 4 | FI‑E1 | Motor de tendencias con significancia |
| 5 | FI‑C1 | Carga muscular (sRPE + tonelaje) |
| 6 | FI‑E5 | Validación personal del score |
| 7 | FI‑F2 | Experimentos personales N‑of‑1 |
| 8 | FI‑A2 | Validar la estimación de calibración |
| 9 | FI‑E4 | Registro de recomendaciones y resultado |
| 10 | FI‑F8 | Modo validación frente a WHOOP |

## 9. Las 10 tareas que deberían desarrollarse primero

| # | ID | Tarea | Pri. | Esfuerzo |
|---|---|---|---|---|
| 1 | DATA‑01 | Archivo de sustrato "para siempre" (ajuste en la app, hoy) | P0 | S |
| 2 | SEC‑09 | `*.db` en `.gitignore` | P0 | S |
| 3 | ALG‑L1 | CTL/ATL sin días inventados | P0 | M |
| 4 | DATA‑02 | Re‑derivar desde `substrate_archive` | P0 | M–L |
| 5 | FI‑B4 | Tarjeta matinal | P1 | S–M |
| 6 | DATA‑06 | Procedencia de "I'm awake" | P1 | S |
| 7 | ALG‑C1 | Cribado irregular solo en reposo | P1 | M |
| 8 | UX‑P04 | Progreso de calibración | P1 | S |
| 9 | ALG‑L2 | RPE y carga de fuerza | P1 | M |
| 10 | ALG‑T1 | Motor de tendencias | P1 | M |

## 10. ¿Qué se puede construir ya, qué se desaprovecha, qué falta?

- **Ya:** protección del histórico, calibración visible, cribado más estricto,
  carga honesta, captura de RPE y bienestar, fases como rango.
- **Desaprovechado:** temperatura gen5, "I'm awake" como etiqueta, PIP v26,
  calidad de señal, piezas longitudinales ya implementadas, exportación oficial
  de WHOOP, diario vacío.
- **Falta:** 30–90 noches de uso continuo y una verdad de referencia diaria.
  Sin ellas, cualquier ajuste fino de algoritmos es opinión.
