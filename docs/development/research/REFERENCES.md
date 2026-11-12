# Referencias

> Fecha: 2026-11-12. **V** = enlace/identificador comprobado en esta sesión
> mediante búsqueda web. **C** = citado en la cabecera de un archivo del
> código (`openstrap_analytics` o `lib/compute/healthspan.dart`); no se volvió a
> comprobar aquí. **G** = referencia clásica conocida, sin comprobar en esta
> sesión: verificar el DOI antes de citarla en una decisión.

## Producto WHOOP (fuentes oficiales o semioficiales)

| Ref | Qué aporta | Estado |
|---|---|---|
| WHOOP, "How Does WHOOP Recovery Work" — https://www.whoop.com/us/fr/thelocker/how-does-whoop-recovery-work-101/ | Recovery usa HRV, RHR, sueño y frecuencia respiratoria | V |
| WHOOP Developer, "WHOOP 101" — https://developer.whoop.com/docs/whoop-101 | Recovery 0–100 %; usa datos del día previo y del sueño | V |
| WHOOP, "How Does WHOOP Strain Work" — https://whoop.com/thelocker/how-does-whoop-strain-work-101 | Escala 0–21 inspirada en Borg; carga cardiovascular + muscular | V |
| WHOOP Podcast 26, "Understanding Strain" — https://www.whoop.com/gl/en/thelocker/podcast-26-understanding-strain/ | Origen Borg del 0–21 | V |
| WHOOP, "The Advantage of Continuous Physiological Monitoring" (2018) — https://discover.whoop.com//wp-content/uploads/2018/04/The-Advantage-of-Continuous-Physiological-Monitoring.pdf | Strain como carga cardiovascular normalizada, incluida la no deportiva | V |

## HRV, recuperación y monitorización

| Ref | Uso en el proyecto | Estado |
|---|---|---|
| Plews DJ et al. (2012) *Eur J Appl Physiol*, doi:10.1007/s00421-012-2354-4 — "Heart rate variability in elite triathletes, is variation in variability the key…" | CV de lnRMSSD (ALG‑H1) | V |
| Plews DJ (2014) Tesis AUT — http://hdl.handle.net/10292/7122 | lnRMSSD, medias móviles de 7 d, cumplimiento mínimo | V |
| Plews DJ et al. (2013) *Sports Med* — "Training adaptation and heart rate variability in elite endurance athletes" | `readinessLnRmssd` | C |
| Vesterinen V et al. (2016) *MSSE* 48(7):1347‑54, doi:10.1249/MSS.0000000000000910 | Prescripción guiada por HRV | V |
| Nakamura FY et al. (2015) *J Sports Sci Med* 14:602 | HRV ultra‑corta sensible a la carga | V |
| Buchheit M (2014) *Front Physiol* 5:73, "Monitoring training status with HR measures" | Marco general HR/HRV | G |
| Hopkins WG (2004/2000) Smallest worthwhile change | Puerta SWC | C |
| Lipponen JA & Tarvainen MP (2019) *J Med Eng Technol* | Corrección de artefactos RR | C |
| Task Force ESC/NASPE (1996) *Circulation* 93:1043 | Estándares HRV | G |
| Baevsky RM & Berseneva AP (2008) | Índice de estrés | C |
| Bauer A et al. (2006) *Lancet* | PRSA (DC/AC) | C |
| Alavi A et al. (2022) *Nat Med* | CUSUM de RHR para infección (NightSignal) | C |
| Mishra T et al. (2020) *Nat Biomed Eng* | Detección presintomática con wearables | C |
| Kräuchi K (2007) | Gradiente distal‑proximal de temperatura | C |

## Carga de entrenamiento

| Ref | Uso | Estado |
|---|---|---|
| Banister EW (1991) / Morton RH (1990) | TRIMP y modelo fitness‑fatiga | C |
| Edwards S (1993) *The Heart Rate Monitor Book* | TRIMP por zonas (ALG‑L3) | C |
| Foster C et al. (2001) *J Strength Cond Res* 15(1):109‑15, "A new approach to monitoring exercise training" | sRPE (ALG‑L2) | G |
| Lolli L et al. (2019) "Mathematical coupling causes spurious correlation within the conventional ACWR" — https://core.ac.uk/download/322320894.pdf | Crítica ACWR (D‑05) | V |
| Impellizzeri FM et al. (2021) *Sports Med* 51:581‑592, doi:10.1007/s40279-020-01378-6 | "Time to dismiss ACWR" | V |
| Impellizzeri FM et al. (2020) *J Athl Train* 55(9):893‑901, doi:10.4085/1062-6050-501-19 | Errores metodológicos en carga‑lesión | V |
| Karvonen MJ (1957); ACSM (umbral 40 % FCR) | %FCR y suelo de intensidad moderada | C |
| Keytel LR et al. (2005) *J Sports Sci* | Calorías por FC | C |
| Tudor‑Locke C et al. (2019) CADENCE‑Adults | METs por cadencia | C |

## Sueño y ritmos

| Ref | Uso | Estado |
|---|---|---|
| Phillips AJK et al. (2017) *Sci Rep* 7:3216, doi:10.1038/s41598-017-03171-4 | Sleep Regularity Index | V |
| Lunsford‑Avery JR et al. (2018) *Sci Rep* 8:14158, doi:10.1038/s41598-018-32402-5 | Validación SRI y riesgo cardiometabólico | V |
| Robbins R et al. (2024) *Sensors* — comparación Oura/Fitbit/Apple vs PSG (resumen del fabricante: https://ouraring.com/blog/es/2024-sensors-oura-ring-validation-study/) | Rango de precisión de fases en consumo | V (vía nota de prensa; leer el artículo original) |
| van Hees VT et al. (2015, 2018) | Ventana de sueño por ángulo z | C |
| Rosenblum Y et al. (2024) | Ciclos de sueño por método fractal | C |
| Wittmann M & Roenneberg T (2006); MCTQ | Jet lag social, cronotipo | C |
| Hayano J et al. | CVHR para cribado de apnea | C |
| DREAMT (dataset de muñeca con PSG) | Validación del *stager* (κ 0,132) | C |

## Notas de verificación

- Ninguna fórmula propietaria de WHOOP es pública. Todo lo marcado
  [WHOOP‑LIKE] en ALGORITHMS.md es una aproximación propia.
- Las cifras de validación del *stager* las publica el propio código; no se
  han reproducido en esta sesión.
