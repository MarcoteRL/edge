# Scripts de auditoría de la base de datos

Solo lectura (`?mode=ro`). No contienen datos. Uso:

```bash
python3 profile.py  <ruta/export.db>                 # esquema, nulos, rangos por columna
python3 cov.py      <ruta/export.db> [Europe/Madrid] # huecos, cobertura por día, calidad de señal
python3 validate.py <ruta/export.db> [Europe/Madrid] # reproduce RHR/RMSSD, compara ventana de sueño con band_sleep_state
python3 trimp.py    <ruta/export.db> [Europe/Madrid] # reproduce TRIMP y nivel de reposo, simula strain
python3 fpcal_agreement.py <ruta/export.db>          # ALG-R1: estimación gris frente al readiness real (≥ 10 noches)
python3 awake_tap_error.py  <ruta/export.db>          # ALG-S1: pulsaciones de "Ya estoy despierto" frente a la banda (≥ 10)
```

Requisitos: Python 3.10+, pandas, numpy. La salida es para el analista:
**no pegues valores individuales en Markdown** (ver AGENT_GUIDE.md, privacidad).
Resultados agregados de la última ejecución: DATA_ANALYSIS.md.
