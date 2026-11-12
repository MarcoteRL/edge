# Investigación: recuperación (recovery / readiness)

> Fecha: 2026-11-12. Referencias completas en REFERENCES.md. Separa **lo que
> se sabe** (literatura), **lo que hace WHOOP** (público, sin fórmula) y **lo
> que hace este proyecto** (código).

## 1. Qué mide realmente un "recovery" de muñeca

Un recovery de wearable no mide recuperación muscular ni glucógeno. Mide el
**estado autonómico nocturno** (HRV, RHR) y algunos marcadores de estrés
sistémico (frecuencia respiratoria, temperatura de piel) **frente a tu
propia norma**. La literatura de monitorización (Plews, Buchheit, Vesterinen)
apoya usar lnRMSSD frente a una media móvil personal para guiar la intensidad,
no para predecir rendimiento puntual. WHOOP lo describe igual: recovery refleja
el sistema cardiovascular y nervioso, no las agujetas.

## 2. Utilidad de cada señal

| Señal | Evidencia | Disponible en tu banda | Uso actual | Recomendación |
|---|---|---|---|---|
| HRV (lnRMSSD nocturno) | Fuerte para tendencias individuales; ruido noche a noche alto (usar media 7 d y SWC) | Sí, RR ~93 % de la noche | Entrada principal (bloque autonómico) | Mantener; añadir CV 7 d (ALG‑H1) |
| RHR nocturna | Fuerte; sube con fatiga, enfermedad, alcohol, calor | Sí | Entrada (bloque autonómico) | Mantener |
| Frecuencia respiratoria | Muy estable intra‑individuo; sube con infección | Sí (RSA) | 0,20 | Mantener; buen detector de enfermedad |
| Temperatura de piel | Útil como desviación (fiebre, ciclo menstrual); muy sensible a ambiente | Sí, en °C | **Nunca entra en gen5** (Q‑02) | ALG‑R3, luego ALG‑R4 |
| SpO2 | Relativo y ruidoso en muñeca; útil para apnea en tendencia | **No** en gen5 (rechazado por el pipeline) | — | No perseguir con este hardware |
| Sueño (duración/rendimiento) | Influye en HRV/RHR; WHOOP lo incluye en recovery | Sí | No entra | Mostrar como pilar separado (ALG‑R5) |
| Tendencias individuales | Las normas poblacionales de HRV son casi inútiles para un individuo | — | Todo es z personal | Mantener |

## 3. Lo que hace WHOOP (público)

- Entradas: HRV, RHR, sueño y frecuencia respiratoria (fuentes oficiales en
  REFERENCES.md).
- Escala 0–100 % con verde/amarillo/rojo.
- HRV ponderada hacia el sueño profundo (afirmación de marketing; sin fórmula).
- Pesos y normalización: **no publicados**. Cualquier "replicación exacta" es
  imposible; este proyecto no lo intenta y lo dice.

## 4. Lo que hace este proyecto (ver ALGORITHMS.md §2)

Composite de z robustos con pesos publicados, HRV y RHR fusionados en un bloque
para no contar dos veces la misma señal, renormalización sin imputar, puertas de
dispersión mínima y calibración personal de la escala. Es **más transparente**
que WHOOP y más estricto en el arranque.

## 5. Mejoras con base científica

1. **SWC en vez de umbrales fijos.** Plews/Buchheit: un cambio < 0,5 × SD
   intra‑individual de lnRMSSD es ruido. El código ya tiene MDC; usarlo en la
   UI ("sin cambio relevante") en lugar de colorear cualquier delta.
2. **Media móvil de 7 días** como señal de decisión además del valor de hoy
   (Plews 2014: valores aislados predicen peor que medias semanales).
3. **CV de 7 días** como indicador de inestabilidad (Plews 2012).
4. **Contexto en la explicación:** si ayer hubo sesión intensa, alcohol
   etiquetado o mala noche, decirlo junto al número (los *drivers* ya existen;
   falta el contexto de comportamiento).
5. **Validación personal:** preguntar cada mañana "¿cómo te sientes? (1–5)"
   durante 4–6 semanas y medir la concordancia (Spearman) con readiness.
   Sin esto, cualquier ajuste de pesos es opinión.

## 6. Qué no hacer

- No calibrar los pesos para "parecerse a WHOOP": no hay verdad de referencia.
- No inferir causas ("es el alcohol") de una firma autonómica: el código ya lo
  prohíbe (`event_detection.dart`).
- No convertir recovery en predicción de lesión.
