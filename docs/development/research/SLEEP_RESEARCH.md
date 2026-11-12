# Investigación: sueño

> Fecha: 2026-11-12. Referencias en REFERENCES.md.

## 1. Qué puede medir una muñeca

| Medida | Fiabilidad en consumo | En este proyecto |
|---|---|---|
| Periodo de sueño (inicio/fin) | Buena para inicio; peor para el final y la vigilia en cama | van Hees + recorte con `band_sleep_state`; corregible por el usuario |
| Tiempo total de sueño | Buena (sesgo a sobreestimar) | `tst_min` |
| Vigilia intra‑sueño (WASO) | Mala: los wearables infraestiman la vigilia quieta | *Stager* con 11 % de sensibilidad en vigilia (declarado) |
| Fases (ligero/profundo/REM) | Moderada a baja; κ 0,21–0,53 en dispositivos comerciales frente a PSG | κ 0,13 declarado en DREAMT, por debajo del rango comercial |
| Regularidad (SRI) | Buena si hay ≥ 7–30 días | `phillipsSri` |
| Horario (inicio, punto medio) | Buena | `sleep_onset_sec`, `midsleep_sec` |

**Regla:** las fases de un wearable no equivalen a polisomnografía. Para
tomar decisiones sirven duración, horario y regularidad mucho más que las fases.

## 2. Relación sueño ↔ recuperación

- La restricción de sueño eleva RHR y baja HRV al día siguiente en muchos
  sujetos, pero el efecto individual varía. Por eso la correlación debe
  medirse **en ti** (ALG‑R5) en lugar de asumirse.
- La regularidad de horario (SRI) se asocia a salud cardiometabólica y
  rendimiento (Phillips 2017; Lunsford‑Avery 2018), con independencia de la
  duración.
- La "necesidad de sueño" no se mide: se estima. El proyecto usa el p75 de
  noches libres (sin alarma) acotado a 7–9,5 h, y **no** inventa 8 h por
  defecto. Es una decisión honesta que retrasa el coach hasta tener ≥ 3 noches
  libres.

## 3. Hallazgos con tus datos

- 2 de 3 noches se cerraron con "I'm awake"; el inicio automático no se tocó
  en ninguna.
- La banda sigue en "dormido" 0,5–2,7 h después de pulsar "I'm awake": reposo
  en cama y sueño son indistinguibles por movimiento.
- REM entre 20 % y 34 % del TST en 3 noches: por encima del rango típico de
  adultos en PSG. Coherente con el bajo VPP de REM declarado.

## 4. Mejoras con base científica

1. **Priorizar duración, horario y regularidad** en la UI; fases como rango.
2. **SD de hora de acostarse/levantarse 7 d** mientras el SRI no tenga datos.
3. **Etiqueta de "noche libre"** explícita (sin alarma) en la tarjeta matinal
   para que la deuda de sueño se pueda calcular antes.
4. **Validación personal del final de la noche** (ALG‑S1).
5. **Comparar días de entreno vs descanso**: TST, eficiencia y RHR nocturna
   condicionados a la carga del día anterior (`session_cost` ya existe).
6. **Higiene circadiana**: hora de luz/actividad matinal vs inicio de sueño
   (requiere ≥ 30 días; `cosinor`, `circadianNonparametric` ya existen).
