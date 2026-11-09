# PROGRESS — personal fork of OpenStrap edge

Append new entries at the top of "Log". Keep "Status" current.

## Status

- **Phase:** A (foundation). Audit and docs done. CI-01 written, awaiting first run.
- **Base:** upstream `main` @ `38a83e9` (2026-11-09), app `0.11.3+78`,
  `kAlgoVersion 120`, `schemaVersion 58`.
- **Remotes:** `upstream` = github.com/OpenStrap/edge. `origin` =
  github.com/MarcoteRL/edge (private, standalone repo, not a GitHub fork).
- **In progress:** CI-01 (secretless unsigned IPA workflow).
- **Next:** check the first `test` + `ios-sideload` runs → AUD-01 baseline →
  sideload on device → BUG-566 / BUG-558 triage.
- **Blockers:** no Dart/Flutter toolchain in the Claude session (pub.dev +
  Flutter SDK host blocked), so analyze/test only run on CI or your PC.
  No macOS. Hardware checks need you.

## Known bugs (see TECHNICAL_AUDIT.md)

| ID | Pri | State |
|---|---|---|
| F-01 release pipeline unusable in personal repo | P1 | fixed by CI-01 (unverified until first run) |
| F-02 / #601 sync deadlock on pre-2023 records (gen4) | P1 | open |
| F-03 dummy Firebase options target a real-format 3rd-party project | P2 | open: keep telemetry OFF in self-builds |
| F-05 upstream cron/secret workflows in personal repo | P2 | open: disable in GitHub UI |
| F-04 stale phosphor comment in test.yml | P3 | open |
| Upstream #566, #558, #471, #450, #277, #186, #593 | — | reported upstream, not reproduced |

## Latest validation

| Date | Check | Result |
|---|---|---|
| 2026-11-09 | `flutter --version`, `pub get`, `analyze`, `test` | **not run**: toolchain unreachable in session |
| 2026-11-09 | `actionlint` 1.7.12 + shellcheck on `ios-sideload.yml` | clean |
| 2026-11-09 | `actionlint` on upstream `build.yml`/`test.yml` | 1 shellcheck info (SC2086) in upstream `build.yml`. Pre-existing, not touched |
| — | `ios-sideload` run on GitHub | pending (needs your repo) |
| — | Install + pair + sync on device | pending |

## Log

### 2026-11-09 — Pushed to own repo (CI-02)
- Owner created private `MarcoteRL/edge`. Pushed full upstream history
  (2,757 commits) + one commit with the fork docs and
  `.github/workflows/ios-sideload.yml` (now in place).
- Disabled `star-history`, `soak`, `pr-agent` via the Actions API (owner
  approved). Private repo: macOS minutes bill at 10×, so prefer manual runs.

### 2026-11-09 — Setup, audit, docs, CI-01
- No fork existed (`MarcoteRL/edge` not found). Per owner: cloned upstream
  locally into `Proyectos/openstrap-edge` with `upstream` remote only.
- Upstream already has `AGENTS.md` (kept unedited) and the `ponytail` skill.
- Added: `CLAUDE.md`, `PROGRESS.md`, `docs/development/{SKILLS_AUDIT,
  ARCHITECTURE,TECHNICAL_AUDIT,PLANNING,FEATURE_PROPOSALS,IOS_BUILD_PIPELINE}.md`,
  `.github/workflows/ios-sideload.yml` (delivered to the PC as
  `docs/development/ios-sideload.yml`, pending a manual move).
- No app code changed. No commits made.
- Chose CI-01 over a code fix: without any toolchain, a Dart fix couldn't be
  analyzed or tested, and CI is the validation path for everything after it.
