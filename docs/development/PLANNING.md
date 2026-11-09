# Development plan

Priorities: P0 critical · P1 high · P2 medium · P3 low. Type: **BUG**
(confirmed), **DEBT**, **ENH** (optional). Status: todo / in-progress /
done (with evidence) / blocked. Complexity: S / M / L.

## Phase A — Foundation (this fork)

| ID | Task | Type | Pri | Cx | Deps | Status |
|---|---|---|---|---|---|---|
| SETUP-01 | Local clone, `upstream` remote, docs scaffold | DEBT | P1 | S | — | done (2026-11-09) |
| CI-01 | Secretless unsigned-IPA workflow `ios-sideload.yml` | BUG (F-01) | P1 | S | — | done on CI (run 42655280078, IPA built); device install pending |
| CI-02 | Create your GitHub repo, push, disable star-history/soak/pr-agent | DEBT (F-05) | P1 | S | SETUP-01 | done (2026-11-09): MarcoteRL/edge |
| AUD-01 | Record test/analyze baseline from first `test.yml` run | DEBT | P1 | S | CI-02 | done (2026-11-09): run 42655279966, 8 pre-existing l10n/gallery failures (PROGRESS.md) |
| AUD-02 | Deep bug sweep of hotspots (db, derivation, ble_engine, app_state) | DEBT | P2 | L | AUD-01 | todo |
| AUD-03 | `flutter pub outdated` + advisory check, no upgrades | DEBT | P2 | S | toolchain | todo |

**CI-01 detail.** *Motivation:* a Windows developer needs CI to get any IPA or
validation. *Acceptance:* (1) a manual "Run workflow" on your repo finishes
green; (2) the artifact `openstrap-edge-<ver>-<sha>-unsigned.ipa` downloads;
(3) Sideloadly signs and installs it; (4) the app launches, pairs your WHOOP,
syncs. *Testing:* actionlint (done), then the run itself, then the device.

## Phase B — Stability and bug fixing

| ID | Task | Type | Pri | Cx | Deps | Status |
|---|---|---|---|---|---|---|
| BUG-601 | Sync deadlock on below-floor/event-only bursts (F-02) | BUG | P1 | M | AUD-01, capture or gen4 band | todo |
| BUG-566 | WHOOP 5 "Not sleep" correction lost after reanalysis | BUG (upstream) | P1 | M | AUD-01, triage | todo: reproduce first |
| BUG-558 | HR not exported to Apple Health | BUG (upstream) | P1 | M | CI-01 (device) | todo: reproduce first |
| BUG-186 | Smart alarm not firing | BUG (upstream) | P2 | M | device | todo |
| PRIV-01 | Inert Firebase options for self-builds (F-03), propose upstream | DEBT | P2 | S | device test | todo |

**BUG-601.** *Motivation:* permanent stuck sync on revived gen4 bands.
*Acceptance:* a burst whose every record is below `kMinPlausibleUnix` is
archived and ACKed. An ACKed cursor-advancing event-only batch counts as
progress for auto-continue. `syncClockLost` isn't raised for that case.
Invariant #1 holds (commit before ACK). *Testing:* extend the
`TrimAckPolicy` unit tests in `test/ble_safe_trim_test.dart` and
`test/ack_commit_sync_full_test.dart` with synthetic bursts. Hardware note:
your band is gen5, so validation needs a gen4 capture. Upstream PR candidate.

**BUG-566 / BUG-558.** *Motivation:* affect your exact setup (iPhone + WHOOP
5). *Acceptance:* written repro, then a failing test, then the fix. *Testing:*
unit test where the logic is pure. Device check on the sideloaded build.

## Phase C — Testing and CI

| ID | Task | Type | Pri | Cx | Status |
|---|---|---|---|---|---|
| CI-03 | Fix stale phosphor reason in `test.yml` comment (F-04), upstream PR | DEBT | P3 | S | todo |
| CI-05 | Fix the 8 pre-existing l10n/gallery test failures (upstream main), upstream PR | BUG | P2 | S | todo |
| CI-04 | Cache CocoaPods in `ios-sideload.yml` once the first run shows build time | ENH | P3 | S | todo |

## Phase D — iOS / Android

| ID | Task | Type | Pri | Cx | Status |
|---|---|---|---|---|---|
| IOS-01 | Document App Group behaviour under Sideloadly on a real device | DEBT | P2 | S | todo |
| IOS-02 | Optional paid-team signing path (keeps widgets/Watch) | ENH | P3 | M | todo |
| AND-01 | Secretless debug-APK job (only if you use Android) | ENH | P3 | S | todo |

## Phase E — Performance, UX, features

Pick from FEATURE_PROPOSALS.md only after Phase B's P1s. Top three there:
FP-01 sideload-expiry warning, FP-02 automated upstream-sync PR, FP-03
beat-to-beat export to Apple Health (overlaps BUG-558).

## Phase F — Release preparation

| ID | Task | Type | Pri | Cx | Status |
|---|---|---|---|---|---|
| REL-01 | Tag a known-good build (`fork-stable-YYYYMMDD`) after a week of daily use | DEBT | P2 | S | todo |
| REL-02 | Monthly `git fetch upstream` + merge, re-run CI | DEBT | P2 | S | recurring |

## Fork strategy

- `main` tracks upstream via merges (not rebase, so history stays stable
  for your remote). Keep fork-only files to `CLAUDE.md`, `PROGRESS.md`,
  `docs/development/`, and `.github/workflows/ios-sideload.yml`, so merges don't
  conflict.
- One branch per fix (`fix/601-below-floor-ack`). Fixes that upstream wants
  become PRs from that branch, so the fork carries nothing upstream rejects
  without a reason written in PROGRESS.md.
- Experiments go behind a branch, never in `main` until they've run on your band.
- Licence: AGPL-3.0. Private personal use is fine. If you distribute a
  modified build, publish its source.
