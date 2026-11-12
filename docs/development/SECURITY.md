# Seguridad y privacidad (fork)

> Fecha: 2026-11-12. El `SECURITY.md` de la raíz es la política de reporte de
> upstream. Este documento es el análisis del fork. Base: TECHNICAL_AUDIT.md
> §Security + revisión estática de esta sesión.

## 1. Modelo de amenazas resumido

Datos de salud sensibles, 100 % en el móvil. Las superficies son: (a) el
fichero SQLite y sus exportaciones, (b) llamadas de red opcionales, (c) BLE,
(d) la cadena de suministro (dependencias, siblings por SHA, CI).

## 2. Hallazgos

| ID | Área | Situación | Riesgo | Recomendación |
|---|---|---|---|---|
| SEC‑01 | Base local | `sqflite` sin cifrado en reposo; protegida por el sandbox del SO | Medio si el dispositivo se compromete | Aceptable. En iOS, confirmar la clase de *Data Protection* del fichero |
| SEC‑02 | Exportación de base | "Exportar base de datos" produce un `.db` **en claro** (tu exportación lo era) | Alto si se comparte por error | Ofrecer por defecto el backup cifrado (ya existe, AES‑GCM con passphrase en `lib/import/backup_crypto.dart`); avisar al exportar en claro |
| SEC‑03 | Claves BYOK / ChatGPT | `flutter_secure_storage` (`lib/coach/coach_config.dart`, `coach_chatgpt.dart`); tokens de ChatGPT verificados contra JWKS (`coach_chatgpt_jwks.dart`) | Bajo | Mantener. Revisión completa pendiente (PLANNING SEC‑01) |
| SEC‑04 | Coach con LLM | El coach solo lee vistas `v_*` con lista blanca y guardia (invariante 13), pero lo que lee se envía al proveedor de IA elegido | Privacidad | Dejar claro en la UI qué se envía; desactivado por defecto |
| SEC‑05 | Firebase | Opciones "dummy" con formato real de un proyecto de terceros (F‑03) | Medio si activas telemetría | **Mantener telemetría desactivada** en builds propias |
| SEC‑06 | BLE | Comandos peligrosos nunca automáticos (invariante 15); vinculación estándar | Bajo | Mantener |
| SEC‑07 | Firmware | Firmware ≥ 50.43 requiere token firmado (#673) | Pérdida de compatibilidad | No usar la app oficial |
| SEC‑08 | CI | Workflows con `permissions` mínimos y `persist-credentials: false`; siblings por SHA con guardia | Bajo | Mantener; `star-history.yml` con `contents: write` desactivado en tu repo (F‑05) |
| SEC‑09 | Documentación y análisis | Riesgo de filtrar biometría en Markdown | Medio | Regla en AGENT_GUIDE.md: solo agregados; scripts sin datos; exportaciones fuera del repo. **`.gitignore` no ignora `*.db`** (comprobado con `git check-ignore`): añadir `*.db` y `*.db-*` (backlog SEC‑09) |

## 3. Reglas para agentes

1. Nunca subir una exportación `.db` al repo ni a servicios externos.
2. Nunca copiar valores biométricos individuales a documentación, issues o PRs.
3. Trabajar siempre sobre una copia y en modo `?mode=ro`.
4. No activar telemetría ni cambiar `lib/firebase_options.dart` sin decisión
   explícita del propietario.
