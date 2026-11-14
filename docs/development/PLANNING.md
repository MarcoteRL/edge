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
| AUD-04 | Full audit: code + real DB export + algorithms + UX + roadmap (docs/development/AUDIT_SUMMARY.md) | DEBT | P1 | L | — | done (2026-11-12): docs only, no code change |
| SEC-09 | `*.db`/`*.db-wal`/`*.db-shm`/`*.sqlite` in .gitignore | DEBT | P0 | S | — | done (`git check-ignore` verified) |
| ALG-L1 | CTL/ATL abstain until 80 % of last 42 days have a measured TRIMP (`_loadWithCoverage`); kAlgoVersion 121 | BUG | P0 | M | — | in `main` (runs 43231936403, 43232851823; full suite 43233915353 + 43250024942, no failure) |
| ALG-C1 | irregular_rhythm_flag needs the sleep-window screen to agree (`irregularRhythmFlag`); same bump 121 | BUG | P1 | S | — | in `main` (same runs) |
| DATA-06 | Dropped: an I'm-awake tap is already recognisable (offset_ts ≈ created_at) | — | — | — | — | won't do |
| FI-B4 | Morning ratings already exist in the journal; only a "no alarm" night flag is missing | ENH | P2 | S | — | todo |
| ITER-1 | Audit contrasted with the code; iteration plan (AUDIT_VERIFICATION.md, ITERATION_PLAN.md) | DEBT | P1 | M | — | done; plan approved by the owner 2026-11-12 |
| DATA-02 | Re-derive pruned days from `substrate_archive` (read-only, oldest first, no bump) | ENH | P0 | L | — | done (runs 43255670024, 43255676974; full suite 43260273913 + 43260295892); device check pending |
| T-02 | `payload_json` contract test | DEBT | P2 | S | — | done (run 43255670024) |
| AWAKE | "I'm awake" provenance rule documented and pinned | DEBT | P1 | S | — | done (run 43255670024) |
| DATA-02b | Archive re-derive off the UI isolate; no activity suggestions for re-derived days | BUG | P1 | M | — | done on branch `iter2/rederive-off-ui` (run 43273419312); **not merged**: full suite not run (Actions budget) |
| ALG-T1/H1/S3/L2/L3 | Fork read-time modules (`lib/compute/fork/`) | ENH | P1 | M | D-15 | done on branch `iter3/fork-trends` (run 43305607581), synthetic only; not wired to UI; **not merged** |
| ALG-R1 / ALG-S1 | Offline scripts written; wait for data (10 nights with readiness / 10 taps) | ENH | P1 | S | owner export | blocked on data |
| ITER-2/3/4 merge | `iter2/rederive-off-ui`, `iter3/fork-trends`, `iter4/home-guidance` in `main` | — | P1 | — | — | done: owner merged PR #1 (`6bf7cd7`, 2026-11-12); IPA run 43327489818; owner's local full suite +7128 −28 (the 28: Windows portability, see BUG-N01 entry in PROGRESS.md) |
| ITER-4b | P-02 (`WeekTrendLine` under Health trends), P-05 (sleep order), P-07 (Workout: load first), "how it is computed" says what today stands on | ENH (UX) | P1 | M | ITER-4 | done, in `main` (`6adce27`; owner's local analyze + touched tests, 2026-11-13, reported passing); device check pending |
| ITER-5a | Period lab (ALG-P1, D-20) and weekly report (D-21) | ENH | P1 | M | ALG-T1 in main | done, in `main` (`6adce27`; owner's local run, 2026-11-13, reported passing; synthetic data only); device check pending |
| ITER-5b | Recommendation log | ENH | P2 | M | new table + `schemaVersion` | done, in `main` (`759a19a`, schema 59, D-23; owner's local analyze + touched tests 2026-11-14, reported passing); device check pending |
| ITER-5c | N-of-1; validation against WHOOP | ENH | P2 | M | journal in use; official export ZIP | blocked on data (journal has 0 rows; no ZIP) |
| ITER-6 | Static review (TECHNICAL_DEBT.md §5) and FINAL_PRODUCT_REPORT.md | DEBT | P2 | M | — | done as far as it goes without a device: pattern sweeps + fork code; BLE, latches and battery **not reviewed** |
| NEXT | Owner installs the IPA of `759a19a` and checks BUG-N01, the new screens and the recommendation log on the phone; Hevy: confirm whether recent Hevy workouts exist and whether "Sync now" works | — | — | — | — | open |

**CI-01 detail.** *Motivation:* a Windows developer needs CI to get any IPA or
validation. *Acceptance:* (1) a manual "Run workflow" on your repo finishes
green; (2) the artifact `openstrap-edge-<ver>-<sha>-unsigned.ipa` downloads;
(3) Sideloadly signs and installs it; (4) the app launches, pairs your WHOOP,
syncs. *Testing:* actionlint (done), then the run itself, then the device.

## Phase B — Stability and bug fixing

| ID | Task | Type | Pri | Cx | Deps | Status |
|---|---|---|---|---|---|---|
| BUG-601 | Sync deadlock on below-floor/event-only bursts (F-02) | BUG | P1 | M | AUD-01, capture or gen4 band | todo |
| BUG-566 | WHOOP 5 "Not sleep" correction lost after reanalysis | BUG (upstream) | P1 | M | AUD-01, triage | likely fixed upstream after 0.10.0 (edit now waits for a running derive); verify on device |
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
| CI-06 | Run tests locally on Windows (Flutter 3.41.6); confirm the local baseline matches AUD-01 | DEBT | P1 | S | todo (owner) |
| CI-05 | Fix the 8 pre-existing l10n/gallery test failures (upstream main), upstream PR | BUG | P2 | S | done (runs 42676487905, 42677071191); upstream PR: todo |
| FP-01 | Sideload expiry warning (card + notification) | ENH | P2 | S | done (runs 42686340140, 42686373738); device check pending |
| FP-HS | Estimated physiological age (fork module) | ENH | P2 | M | done (run 42688204660) |
| UX-01 | First-run Home: honest derive copy, no developer note on empty Recovery, day-by-day derive progress | BUG (UX) | P1 | S | done (runs 42683191519, 42684463978) |
| UX-06 | Home B+: headline + bars, coach card, day strip, training block (Hevy muscles) | ENH (UX) | P1 | M | done (runs 42828079164, 42830765178) |
| UX-05 | Quiet loading: header status line instead of a card over the numbers; values glide | ENH (UX) | P1 | S | done (run 42819433586) |
| FP-CAL | Calibration estimates: greyed Recovery from night 1 / Strain from day 1 while the real ones need 14 nights / 3 days (read-time, never stored) | ENH (owner request) | P1 | M | done; device check pending |
| FP-GEM | Coach: Gemini preset (gemini-3.8-flash → gemini-3.5-flash-lite fallback), fallback model on 404/429/5xx, Gemini 3+ sampling stripped | ENH | P2 | S | done |
| FP-HEVY | Hevy import: sets into strength_set, attached to the overlapping band session or logged as a band-scored weight-training session; v_strength_sets for the coach | ENH | P2 | M | done; needs a Hevy Pro key to verify |
| UX-04 | Morning check: last night visible 15 min after waking (provisional), "I'm awake" button closes and scores the night at once | ENH (UX) | P1 | S | done (run 42779064344: analyze + 70 files, 617 passed); device check pending |
| BUG-T02 | Sleep scrub card printed the relative skin-temp curve in raw stored units ("+61,2" = +0.61 °C on gen5); now °C for gen5, no number otherwise | BUG (honesty) | P1 | S | written 2026-11-14 on `fix/skin-temp-scrub-unit`; **not analyzed, not run** |
| BUG-N01 | A possible nap proposed mid-night stays pending after the night is stored over it (3 phantom naps inside the main sleep); `ActivityStore.retireNapsInsideSleep` after `putDayResult` | BUG | P1 | S | done, in `main` (`6adce27`; owner's local run 2026-11-13: 15 touched files, +172 ~12, 0 failures); device check pending |
| BUG-T01 | Evening stillness at the data edge published as today's night ("2h 38m from 20:57" while awake); `tonightStillGoing` defers it to the day it ends | BUG | P1 | S | done (runs 42717737790: +1195 before the 45-min cap, 42723979505: remainder); device check pending |
| UX-02 | Home redesign, part 1: day-order hero rings (reading inside, strain target band, sweep-in), vitals row vs 28-day usual, staggered entrance, compact header, haptics | ENH (UX) | P1 | M | done (runs 42708664184: 574 tests; 42709538906: home_redesign_test); device check pending |
| UX-03 | Home redesign, part 2: Activities list, recovery-tinted heroes, shared entrance on every detail screen (detailScaffold + Sleep tab), Recovery ring sweep | ENH (UX) | P2 | M | done (run 42712259267: analyze + 156 ui2/l10n files, 1767 passed); device check pending |
| ES-01 | Translate the 621 missing Spanish strings + coverage guard | ENH | P1 | M | done (run 42677830073) |
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
