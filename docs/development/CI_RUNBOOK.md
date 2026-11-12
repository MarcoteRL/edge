# CI runbook: tests e IPA

> Instrucciones del propietario (2026-11-12). **En la sesión de agente no hay
> Flutter: todo se ejecuta en GitHub Actions con `gh`.** Seguir siempre este
> documento para validar cambios.

## Tests (workflow `test-files.yml`, lanzamiento manual)

- Sube primero la rama: `git push origin <rama>`.
- Tests concretos:
  ```bash
  gh workflow run test-files.yml -R MarcoteRL/edge --ref <rama> \
    -f files="test/a_test.dart test/b_test.dart" -f analyze=true
  ```
- Suite completa (~60-80 min):
  ```bash
  gh workflow run test-files.yml -R MarcoteRL/edge --ref <rama> \
    -f files="$(git ls-files 'test/*_test.dart' 'test/**_test.dart' | sort -u | tr '\n' ' ')"
  ```
- Suite completa **partida en dos** (el job corta a los 90 min): reparte la
  lista anterior en dos mitades y lanza un run por mitad; `analyze=true` solo
  en una.
- Zona horaria (tests de días que cruzan dos días UTC o de cambio de hora):
  añade `-f tz=Europe/Madrid`. Sin él, el run va en UTC y esos casos se
  saltan.
- Seguimiento:
  ```bash
  gh run list  -R MarcoteRL/edge -w test-files.yml -L 1
  gh run watch <id> -R MarcoteRL/edge
  gh run view  <id> -R MarcoteRL/edge --log-failed
  ```
- El analizador tiene que salir **limpio**: avisos de tipo info o privados sin
  usar ya hacen fallar el run.
- Si la suite completa tiene fallos, separa los que ya fallaban antes de tu
  cambio. El caso "banked tail" de `app_state_regressions_test` es inestable y
  pasa si se ejecuta solo.
- Apunta el id del run como prueba en `PROGRESS.md`. Nunca escribas
  "validado en hardware".

## IPA (workflow `ios-sideload.yml`, sin firmar)

- Se lanza solo con cada push a `main`, salvo que el push toque únicamente
  `.md` o `docs/`. A mano:
  ```bash
  gh workflow run ios-sideload.yml -R MarcoteRL/edge --ref main
  ```
- Si el job se cancela con "The job was not acquired by Runner" (no hay Macs
  ARM libres), relánzalo en Intel:
  ```bash
  gh workflow run ios-sideload.yml -R MarcoteRL/edge --ref main -f runner=macos-15-intel
  ```
- Tarda unos 20-30 min. Descarga el IPA con
  `gh run download <id> -R MarcoteRL/edge -D ./ipa`, o pasa al usuario el
  enlace del run: el IPA está en *Artifacts*.
- Cada push a `main` cancela el build en curso. Agrupa los cambios y no
  generes un IPA por cada cambio pequeño: en un repo privado, cada minuto de
  Mac cuenta como 10.
- Nunca subas el IPA al repo.
