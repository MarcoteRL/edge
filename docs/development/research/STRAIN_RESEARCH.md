# Investigación: strain y carga de entrenamiento

> Fecha: 2026-11-12. Referencias en REFERENCES.md.

## 1. Modelos considerados

| Modelo | Fórmula | Datos que necesita | Ventajas | Problemas | ¿Útil aquí? |
|---|---|---|---|---|---|
| **Banister TRIMP** | `Σ Δt·x·k·e^(b·x)`, `x` = %FCR | FC continua, RHR, FCmax, sexo | Continuo, sin zonas, pondera intensidad de forma exponencial | Subestima fuerza e intervalos cortos; depende de FCmax | **Sí, ya implementado** |
| **Edwards** | `Σ min_zona·(1..5)` | Minutos por zona | Simple, explicable | Saltos en los bordes de zona | Sí, como vista (ALG‑L3) |
| **Lucia** | 3 zonas por umbrales ventilatorios × 1/2/3 | Umbrales de laboratorio | Fisiológico | No hay umbrales medidos | No |
| **sRPE (Foster)** | `RPE × min` | RPE subjetivo | Válido para fuerza y todo tipo de sesión | Requiere registro manual | **Sí, para fuerza** (ALG‑L2) |
| **Banister fitness‑fatiga / CTL‑ATL‑TSB** | EWMA 42 d / 7 d | Carga diaria continua | Describe forma y fatiga | Parámetros poblacionales; sin datos de rendimiento no se ajusta | Sí, descriptivo (con ALG‑L1) |
| **ACWR** | ATL/CTL | Carga diaria | Popular | Acoplamiento matemático; teoría cuestionada | **No como predictor** (D‑05) |
| **TSS / Training Stress Balance** | Potencia normalizada / FTP | Potenciómetro | Estándar en ciclismo | No hay potencia | No (salvo import futuro) |

## 2. WHOOP (público)

Escala 0–21 inspirada en Borg, logarítmica (más difícil subir cuanto más
alto), carga cardiovascular de todo el día incluida la no deportiva, y desde
2025–2026 un componente de carga muscular para fuerza. La fórmula no es
pública.

## 3. Lo que hace este proyecto

TRIMP de Banister por minuto de vigilia, menos un "coste de estar despierto"
calculado con **tu** nivel de reposo (mediana de %FCR de los 28 días previos),
con los minutos ≥ 40 % FCR protegidos de esa resta, mapeado de forma
logarítmica a 0–21. La tabla de anclas del código documenta qué valores dan
paseo, carrera moderada y sesión dura para un perfil de referencia.

## 4. Relación intensidad‑duración

El peso exponencial de Banister hace que 30 min a 85 % FCR cuenten mucho más
que 60 min a 60 %. Para un usuario de fuerza esto significa que el strain
**infravalora sistemáticamente** las sesiones de pesas (FC media moderada,
picos cortos). Por eso hace falta una segunda dimensión de carga (sRPE /
tonelaje), no un ajuste de la curva.

## 5. Carga semanal y mensual

- **Semanal:** suma de TRIMP neto y de sRPE; distribución por zonas
  (polarización = % tiempo en Z1–Z2 vs Z4–Z5).
- **Mensual:** CTL (forma) con ALG‑L1 aplicado; monotonía de Foster
  (`media/SD` de la carga diaria semanal) y *strain* de Foster
  (`carga semanal × monotonía`), ambos descriptivos.
- **Comparativa:** semana actual frente a la media de las 4 anteriores, con
  el mismo criterio de cambio relevante que el resto (ALG‑T1).
