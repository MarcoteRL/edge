# PROGRESS — personal fork of OpenStrap edge

Append new entries at the top of "Log". Keep "Status" current.

## Status

- **Phase:** iteration 2 (foundations) closed 2026-11-12; next is iteration 3 (`docs/development/ITERATION_PLAN.md`).
- **Base:** upstream `main` @ `38a83e9` (2026-11-09), app `0.11.3+78`,
  `kAlgoVersion 120`, `schemaVersion 58`.
- **Remotes:** `upstream` = github.com/OpenStrap/edge. `origin` =
  github.com/MarcoteRL/edge (private, standalone repo, not a GitHub fork).
- **In progress:** CI-01 (secretless unsigned IPA workflow).
- **Next:** sideload the IPA on device → BUG-566 / BUG-558 triage.
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
| AUD-01 8 l10n/gallery failures | P2 | fixed (CI-05) |
| Upstream #566, #558, #471, #450, #277, #186, #593 | — | reported upstream, not reproduced |

## Latest validation

| Date | Check | Result |
|---|---|---|
| 2026-11-09 | `flutter --version`, `pub get`, `analyze`, `test` | **not run**: toolchain unreachable in session |
| 2026-11-09 | `actionlint` 1.7.12 + shellcheck on `ios-sideload.yml` | clean |
| 2026-11-09 | `actionlint` on upstream `build.yml`/`test.yml` | 1 shellcheck info (SC2086) in upstream `build.yml`. Pre-existing, not touched |
| 2026-11-09 | `ios-sideload` run 42655280078 (macOS, 55d56bb) | **success**: 11 min total, artifact `openstrap-edge-0.11.3-55d56bb-unsigned.ipa` (20 MB) |
| 2026-11-09 | `test` run 42655279966 (Ubuntu, 55d56bb): pin guard, `pub get`, `flutter analyze` | **pass** (analyze clean) |
| 2026-11-09 | same run, `flutter test --concurrency=1` | **7010 pass, 28 skip, 8 fail** in 90 min. Zone-dependent step skipped (runs only if tests pass). **All 8 pre-existing upstream**, see AUD-01 baseline below |
| — | Install + pair + sync on device | pending |

## AUD-01 baseline: pre-existing failures (upstream `38a83e9`)

Commit `55d56bb` adds only docs + a workflow, no Dart/ARB, so these come from
upstream main. Mostly from #680 (WHOOP firmware warning) landing without
translations or a gallery entry:

- `settings_report_l10n_test.dart` ×4 (es, fr, hi, zh): `reportContactLabel`,
  `reportContactHint` untranslated
- `ui2_tokens_test.dart` "every component is in the gallery": `WhoopFirmwareWarning` missing
- `russian_localization_test.dart`, `thai_l10n_test.dart`: `whoopFirmwareWarning*` keys missing
- `russian_review_findings_test.dart` "category search accepts original and
  Russian blurb": finds 0 widgets with text "Bluetooth-датчик пульса"

Any failure outside this list after a change is a regression.

## Log

### 2026-11-14 — PR #4 merged to `main` (`759a19a`), on the owner's instruction

- Basis: the owner's local `flutter gen-l10n`, `flutter analyze` and the PR's touched-file tests, reported as all passing (no counts received). Full suite not re-run. No CI test run.
- ios-sideload **43587926781** launched by the merge: **success** (finished 2026-11-14T11:09Z). Unsigned IPA of `759a19a` available as the run's artifact. Not hardware-validated.

### 2026-11-13 — ITER-5b: recommendation log (`schemaVersion` 58 → 59) — PR #4

- Owner-approved table `recommendation_log` (`day_id` PK, `tier`, `readiness`, `algo_version`, `logged_at`): the day's training call as first shown. Written by the live Home (`_logCall`, unawaited, today + final recovery only — DecisionLine's own condition, D-19), INSERT OR IGNORE so a later re-derive never moves it (D-23).
- AGENTS §3 invariant 11: additive, `CREATE TABLE IF NOT EXISTS`, one `if (oldV < 59)` step, same creator on fresh install and in `_repairOpenSchema`. Wired into `_salvageTables`, `_restoreTables`, `deleteDays`, the per-day export (whose file gets the table from `_repairOpenSchema`) and `kSliceTables`.
- No derived output changes: no `kAlgoVersion` bump, no pin change. The coach's `v_*` views do not include the table (invariant 13 untouched).
- UI: `RecommendationLogScreen` behind a door at the foot of the weekly report; `decisionCall(tier)` is now the one source of the call's words. 4 l10n keys × 8 ARBs.
- Tests (not run): migration + first-write-wins + delete-with-day + idempotent reopen in `db_migration_ladder_test.dart`; `recommendationRow` in `lab_report_test.dart`.
- Independent review pass (CLAUDE.md, invariant-touching change), read-only, nothing compiled: no blocking finding. Its two minor findings fixed: a restore no longer lets the backup's row overwrite the local one (`_restoreEditedKeys`, local wins), and `schemaHealth` now requires the table.
- Owner's local check: `flutter gen-l10n`, `flutter analyze`, `flutter test --concurrency=1 test/restore_keeps_newer_edits_test.dart test/db_migration_ladder_test.dart test/startup_and_rebuild_recovery_test.dart test/issue_report_test.dart test/lab_report_test.dart test/ui2_tokens_test.dart test/home_guidance_test.dart test/ui2_home_day_switcher_test.dart`. Not hardware-validated.

### 2026-11-13 — PR #3 and PR #2 merged to `main` (`6adce27`), on the owner's instruction

- PR #3 (`iter5/lab-report`) into `fix/naps-inside-sleep`, then PR #2 into `main`: one push, one IPA. Merge commits by the owner's account; no reset, no force-push.
- ios-sideload **43523169294** launched by that push: **success** (finished 2026-11-13T23:01Z). Unsigned IPA of `6adce27` available as the run's artifact.
- Basis for merging: the owner's local `flutter analyze` and touched-file tests (entries below). The full suite was **not** re-run after these two branches. Not hardware-validated.
- The owner approved the new table for the recommendation log (ITER-5b). Not started: it is a schema migration (`schemaVersion` 58 → 59) and gets its own branch, migration test and review.

### 2026-11-13 — Iteration 4 leftovers, iteration 5 (lab, weekly report), iteration 6 (static review) — branch `iter5/lab-report`

- Stacked on `fix/naps-inside-sleep` (PR #2). Written with no Flutter in the session: nothing below has been compiled. No CI run launched (Actions budget).
- **P-02:** `WeekTrendLine` under the three Health trend cards (live screen only): the week's verdict from `TrendService`, a change only beyond max(MDC, SWC). `TrendCard` untouched.
- **P-05:** Sleep detail shows "Against your usual" before "Stages". **P-07:** Workout shows "Training load" right under the quick tiles.
- **How it is computed:** each metric says what today's number stands on (`howTodayOf(HomeData)` → own data / estimate "H of N nights" / nothing).
- **Period lab (ALG-P1, D-20):** `periodChange` (pure), `TrendService.periods` (`Isolate.run`), `PeriodLabScreen` (metric, 7/14/28 days, split date). **Weekly report (D-21):** `weeklyReportRows` / `weeklyReportText` (pure), `WeeklyReportScreen`, shared as a `.md` through the system sheet only. Two doors at the end of Home.
- **Review fix (R6-1):** `HomeEvolution` and `WeekTrendLine` use `RevisionReload`; before, a new night never reached a card already on screen.
- No `day_result`/`metric_series` output changes, no schema change, no pin change: no `kAlgoVersion` bump. 32 new l10n keys in the 8 ARBs.
- New tests (not run): `test/lab_report_test.dart`; `periodChange` group in `test/fork_trends_test.dart`; `_notComponents` in `test/ui2_tokens_test.dart` gains `WeekTrendLine`, `PeriodLabScreen`, `WeeklyReportScreen`.
- **Known risks of writing blind:** analyzer infos; Home is two rows longer (tests that scroll to its end); the Health live screen now mounts a loader per trend card; the false-positive bound in the new `periodChange` noise test (< 30 of 200) is a calculation, not an observed count.
- **Evidence (owner's Windows PC, 2026-11-13):** after `flutter gen-l10n` (the generated l10n is not committed and `flutter test` does not regenerate it), first run of `lab_report_test`, `fork_trends_test`, `home_guidance_test`, `ui2_tokens_test`, the es/ru/th l10n tests, `ui2_workout_first_load_test` and `ui2_home_day_switcher_test`: +95 −6, the 6 all in `lab_report_test.dart` (test binding not initialised; fixed in `acdde83`). Re-run of `flutter analyze` and the tests after the fix: reported by the owner as all passing, **no counts received**. No CI run. Not hardware-validated; the new screens have not been seen on a phone.

### 2026-11-13 — BUG-N01 (naps inside the night), Windows test portability — branch `fix/naps-inside-sleep`, **not in `main`**

- **BUG-N01** [Comprobado en la exportación, agregados]: a sync in the middle of the night proposes the hours slept so far as a possible nap; once the morning derive stores the night the detector stops offering the span, so `ActivityStore.reconcile` never revisits the row and it stayed pending for 7 days. Pre-existing (the row is in the export taken before the update). Fix: `ActivityStore.retireNapsInsideSleep()` (pending naps of the shown week that overlap a stored main sleep → `superseded`, same any-overlap rule as `overlapsMainSleep`), called in `_derivePreparedDay` right after `putDayResult`. No output of `day_result` changes: no `kAlgoVersion` bump. The existing phantom rows go on the next derive after the update (every sync derives today). Test: `activity_review_regression_test.dart` "a nap proposed mid-night is retired once the night is stored".
- **Windows portability of tests** (owner's full local run: +7128 −28, log from failure 10 on). None weakened: CRLF checkouts (`reset_generation_rule`, `reset_quiesces_ingest`, `reset_sensor_leftovers`, `awake_tap_provenance`, `app_state_shortcut_sync`, `garmin_sync_fixes` now read sources with LF), backslash paths (`substrate_admission`, `one_band_event_switch`, `scan_lock_entry_points`, `import_container`), POSIX `setenv` in `setUpAll` (`luteal_flags_dst`, `band_step_spans_local_hour`, `day_window_dst`: skipped on Windows like upstream's own DST test), and `month_grid_test` stepping back 24 h at a time across the 25-hour autumn day (now calendar days).
- **Not known:** failures 1–9 of that run are not in the log received. The six files fixed without a log line (`awake_tap_provenance`, `app_state_shortcut_sync`, `garmin_sync_fixes`, `band_step_spans_local_hour`, `day_window_dst`) are a reasoned guess at them, not a confirmed list.
- **State of `main`:** the owner merged iterations 2–4 himself (PR #1, `6bf7cd7`, 2026-11-12); ios-sideload **43327489818** built that IPA. This entry's changes wait on their own branch for his local run; nothing pushed to `main`, no CI run launched.
- **Evidence (owner's Windows PC, 2026-11-13, `flutter test --concurrency=1` over the 15 files touched):** `+172 ~12: All other tests passed!` — 172 pass, 0 fail, 12 skipped (the POSIX-only DST tests self-skip on Windows, so those are not exercised there). `flutter analyze` result not reported for this branch. No CI run. Unit-tested on the files touched; full suite not re-run; not hardware-validated.

### 2026-11-12 — Iteration 4 (Home guidance) written, **NOT analyzed and NOT run** — branch `iter4/home-guidance`
- Owner's instruction: write the code first, he tests on his PC (Actions budget). **Nothing in this entry has passed an analyzer or a test.** Expect compile or lint errors on the first local run; they are mine to fix.
- P-01 `DecisionLine`, P-03 `HomeEvolution`/`EvolutionCard` (via `TrendService`), P-08 `dataFreshnessLine` in Health/Workout/Sleep, `HowComputedScreen`, the grey-estimate note in `firstWeekCard` (P-04), the week's muscular load in Home's training block (P-07, partial), 37 new strings in the 8 ARBs. New file `lib/ui2/screens/home_guidance.dart`; new test `test/home_guidance_test.dart`. Decisions D-18, D-19. What was NOT done and why: UI_UX_AUDIT.md §9.
- To validate locally (Flutter 3.41.6), on `iter4/home-guidance`, which contains the two unmerged branches below it:
  1. `flutter pub get && flutter analyze`
  2. `flutter test --concurrency=1 test/home_guidance_test.dart test/fork_trends_test.dart test/archive_rederive_test.dart test/ui2_tokens_test.dart test/ui2_component_sweep_test.dart test/ui2_contrast_test.dart test/spanish_l10n_test.dart test/russian_localization_test.dart test/thai_l10n_test.dart test/home_redesign_test.dart`
  3. `flutter test --concurrency=1` (full suite, ~90 min) before any merge to `main`.

### 2026-11-12 — DATA-02 follow-up (off the UI isolate, no suggestions) and iteration 3 first half — **on branches, not in `main`**
- **CI budget:** the owner's account is at ~90 % of its 2,000 Actions minutes (resets 2026-12-01). From here: targeted runs only, no full suite, and **no push of code to `main`** (it would build an IPA, ~130 billed minutes). Nothing below is merged.
- **Branch `iter2/rederive-off-ui`** (on top of `main`): an archived day's substrate is now built in a worker isolate — the database isolate only fetches each bucket's bytes; decode, merge, row maps and accumulation run in `rehydratedSubstrateOf`, through `pageDecodedRange`, the page loop extracted verbatim from `_loadSubstrateRange` and shared with the live load. A day re-derived from the archive no longer reconciles activity suggestions (pinned in `archive_rederive_test`). Evidence: run **43273419312** — analyze clean; archive, WHOOP freeze goldens (no diff: the shared loop is byte-identical), multi-device, result-protection, tonight-pending, activity-review and archive-db tests, +134 ~2, all passed. CI cost of an archived day: ~9.4 s read+prepare, ~20 s total (was ~10 s / ~25 s). **Not run: the full suite, and the `tz=Europe/Madrid` cases on this branch.**
- **Branch `iter3/fork-trends`** (on top of the above): `lib/compute/fork/trends.dart` (ALG-T1 `trendOf`, ALG-H1 `lnRmssdCv7`, ALG-S3 `scheduleSdMin`), `fork/load.dart` (ALG-L2 sRPE and tonnage, ALG-L3 Edwards), `fork/trend_service.dart` (Isolate.run + cache). Pure, read-time, not persisted, not wired to any screen (D-15, D-17). Evidence: run **43305607581** — analyze clean + `test/fork_trends_test.dart`, all passed (step, ramp, white noise called a change in under 5 % of 200 series, gaps, duplicate days, clock change). Synthetic only.
- **Offline scripts** (no CI): `analysis/fpcal_agreement.py` (ALG-R1) and `analysis/awake_tap_error.py` (ALG-S1). Run on the owner's export: both report "not enough data" (0 nights with a real readiness; 2 taps of the 10 needed).
- **Owner's two exports around the re-derive** (DATA_ANALYSIS.md §8, aggregates): 3 archived days brought to v121, 1 kept (`before_archive`), 0 read failures, `substrate_archive_failures` untouched, no new activity suggestion; the only series that changed on those days is `irregular_rhythm_flag` (ALG-C1's intended effect). ~6 s per archived day on the iPhone for two partial days (from `computed_at`). No readiness exists yet, so no readiness delta.
- **Correction of iteration 1:** `light_range_sec` / `deep_range_sec` / `rem_range_sec` do exist, as fields of the sleep candidate's payload (not columns). Docs fixed.
- Unit-tested, not hardware-validated.

### 2026-11-12 — Iteration 2: DATA-02, awake-tap rule, T-02 (no kAlgoVersion bump)
- **Full suite left open by the previous entry:** run 43233915353 hit the 90-min limit at 615 of 631 files with +6940 ~28 and no failure; run **43250024942** (the remaining 17 files, on `main`) passed. ALG-L1/ALG-C1 are therefore covered by the whole suite.
- **DATA-02** (`_rederiveArchivedPass` in `derivation_engine.dart`, `RehydratedSubstrate` in `substrate_archive.dart`): a heavy or forced foreground pass brings days the prune has passed up to `kAlgoVersion` from `substrate_archive`, read back in memory (archive ∪ live, live wins), oldest first, 4 days per pass. A complete current-version row is never derived over. Failures go to `archive_rederive_failures`, never to `substrate_archive_failures`. Stands down with a pending timezone change or an active wearable. State and aggregate report: `compute_freshness.archive_rederive`. No day's output changes: no bump, freeze goldens untouched.
- **Awake-tap rule** documented (ALGORITHMS.md §4, D-12) with its two limits; `test/awake_tap_provenance_test.dart`.
- **T-02** `test/payload_contract_test.dart` + `test/fixtures/day_payload_contract.json` (262 paths, `tool/payload_contract.py`).
- `test-files.yml` takes an optional `tz`. `CLAUDE.md` aligned with the runbook and the iteration workflow.
- Independent review (read-only subagent): no P0; four P1 fixed before merge (outcome judged by the stored row, timezone guard, hole check counted like `worn_min`, wearable days stand down). Left open, written in IMPLEMENTATION_LOG.md: holes inside a night smaller than its time awake; row maps built on the UI isolate; the one-shot readiness backfill can stamp archived days first.
- Evidence (branch `iter2/foundations`): **43255670024** — analyze clean + awake-tap, contract and archive tests, UTC (12 pass, 2 skipped: the clock-change cases); **43255676974** — archive tests under `tz=Europe/Madrid`, 5 pass, including the 23 h and 25 h days, byte-identical; full suite in two halves **43260273913** (+3792 ~12, analyze clean) and **43260295892** (+3334 ~18): all passed. CI-measured cost of one archived day: ~10 s read+prepare, ~25 s total on the runner. Unit-tested, not hardware-validated; time and memory on the iPhone are unmeasured.

### 2026-11-12 — Iteration 1: audit contrasted with the code, iteration plan (docs only)
- Read the audit docs in order and checked their claims against `main` @ `cb3bbbeb` (`kAlgoVersion 121`, `schemaVersion 58`) and analytics @ `3a7ca34d`. Result: `docs/development/AUDIT_VERIFICATION.md`. Plan: `docs/development/ITERATION_PLAN.md` (**awaiting owner approval**, three open questions Q1–Q3). Resume point: `docs/development/IMPLEMENTATION_LOG.md`.
- Corrected stale docs: stage ranges and the RPE prompt already exist; `putDayResult` REPLACEs a same-version row; CTL/ATL abstains since 121; D-05/06/09/11 accepted, D-12…D-16 added.
- **Correction to the entry below:** ALG-L1/ALG-C1 are in `main`, but the full-suite run 43233915353 was still `in_progress` (1 h 21 min of a 90-min limit) when they were merged. Its result is not recorded yet.
- No code change, no tests run. Branch `iter1/audit-contrast`. Evidence: `gh run list -R MarcoteRL/edge` (2026-11-12).

### 2026-11-12 — SEC-09, ALG-L1, ALG-C1 (kAlgoVersion 120 → 121)
- **SEC-09:** `*.db`, `*.db-wal`, `*.db-shm`, `*.sqlite` ignored (verified with `git check-ignore`; no tracked file matched).
- **ALG-L1:** `_loadWithCoverage` (`lib/compute/crossday_pipeline.dart`) — CTL/ATL/TSB abstain with `need_baseline:have=H,need=N` until max(14, 80 % of the last 42 calendar days) carry a measured TRIMP. Test `rest days are 0-load impulses` now models rest as measured 0; two new cases (real-export shape 3/15 → `have=3,need=14`; 32/42 abstains, 34/42 reports).
- **ALG-C1:** `irregularRhythmFlag` (`lib/compute/onehz_pipeline.dart`) — published flag needs the sleep-window screen too; no scored night ⇒ null. New `test/irregular_flag_corroboration_test.dart` (3).
- Freeze goldens checked by reading: their `load` note (`have=3,need=14`) and every `irregular_rhythm_flag` (0.0, sleep screen present) are unchanged by the logic; only `algo_version` 120 → 121 moves, so they need `GENERATE_GOLDEN=1` with owner approval and a diff limited to that field.
- Dropped DATA-06 (no code needed) and most of FI-B4 (journal already has the ratings).
- Branch `audit/2026-11-12`. Evidence (CI_RUNBOOK.md): test-files **43231936403** — analyze clean ("No issues found"), crossday_pipeline/irregular/findings/freshness/serve-version/coach/two-device all pass; only the WHOOP freeze goldens failed, on `algo_version: got 121, golden 120` (first and only mismatch). Goldens updated mechanically (54 lines, `"algo_version": 120` → `121`, nothing else); **43232851823** — freeze goldens + crossday + irregular: all 58 pass, so no WHOOP number moved. Full suite: **43233915353** (result in the next entry). Unit-tested, not hardware-validated.

### 2026-11-12 — AUD-04: full audit and permanent docs (no code change)
- Read the fork at `15d791a0`, analytics `3a7ca34`, protocol `b4fde6a`, and a
  real WHOOP 5.0 DB export (read-only copy, 3 nights, 4 live days). New docs
  in `docs/development/` (index `README.md`, `AGENT_GUIDE.md`,
  `AUDIT_SUMMARY.md` + 30 more) and offline scripts in `analysis/`.
- Verified on real data: RHR, RMSSD (±3 %), TRIMP and quiet level recompute
  from raw. Found: CTL/ATL counts unworn days as rest (Q-05); irregular-rhythm
  screen flags 3/3 daytime-only days, 0/4 nights (Q-04); gen5 skin temp never
  enters readiness (Q-02); both `manual` sleep overrides are "I'm awake" taps
  (offset == created_at), indistinguishable from edits (DATA-06); `*.db` not in
  .gitignore (SEC-09).
- Every cited path/symbol grepped against the tree after the owner's pull.
  No tests run (no toolchain in session). No biometric values in the docs.

### 2026-11-09 — Physiological age rebuilt on WHOOP's nine contributors
- Owner asked for "the same as WHOOP". Rebuilt `lib/compute/healthspan.dart`
  on WHOOP's published structure (nine contributors, six months, break-even
  at the guideline, Gompertz years, Pace of Ageing -1..3x). WHOOP's formulas
  are not published; every curve is cited in the file header: Windred 2024,
  Cappuccio 2010, Lee 2022 (zones), Momma 2022 (strength), Banach 2023
  (steps), FRIEND/Kodama (VO2max), Zhang 2016 (RHR).
- No runs needed: without a GPS VO2max in 90 days it uses the Jackson 1990
  non-exercise model, PA-R scored from measured zone minutes. Resting HR is
  included and flagged as leaning young (night reading). Lean mass stays
  absent until a body-composition scale exists.
- Data loading in `lib/data/healthspan_inputs.dart` (zones and strength from
  sessions; weekly minutes over worn days only, absent under 14).
- Validated: test-files run 42691158015 (136 tests + analyze).

### 2026-11-09 — FP-01 sideload expiry + FP-HS physiological age (merged)
- **FP-01** (`feat/sideload-expiry`): `ProvisioningBridge` in
  `ios/Runner/AppDelegate.swift` reads `ExpirationDate` from
  `embedded.mobileprovision`; `lib/platform/provisioning.dart` decides
  (card inside 48 h, one notification per expiry inside 24 h via
  `NotificationCenter.emit`, hooked into the foreground cadence check and both
  background-sync exits). Tests: `sideload_expiry_test` (run 42686340140).
  Swift compiled by `ios-sideload` run 42686373738 (success). Not exercised on
  a device yet.
- **FP-HS** (`feat/healthspan`): estimated physiological age, fork module
  `lib/compute/healthspan.dart` + `HealthspanScreen` behind a Health-tab row.
  Pillars and sources: VO2max vs FRIEND 2015 p50 (RR 0.87/MET, Kodama 2009);
  SRI vs UK Biobank median 81 (RR 0.813/SD, Windred 2024); sleep length
  (<6 h RR 1.12, >=9 h RR 1.30, Cappuccio 2010); years = 8·log2(RR) (Gompertz).
  RHR and steps deliberately excluded. Computed on read, not persisted, no
  kAlgoVersion bump. Owner chose edge over an analytics fork. Tests:
  `healthspan_test` (runs 42687628989 then 42688204660, 139 pass).
- **Not done, with reasons:** FP-03 skin temperature to Apple Health (wrist
  skin temp is not body temperature; Apple's sleeping-wrist type appears to
  be Apple-generated; would need a device test to even try). Habit
  streaks (the design system bans streaks on purpose; 14-day consistency
  already exists). Multi-signal illness alert (already exists as the
  Mahalanobis overnight-anomaly finding beside the RHR CUSUM).

### 2026-11-09 — UX-01 first-run Home (branch `fix/first-run-home-copy`, merged)
Owner report: on a first connection Home said "Crunching last night's
numbers" (es "Calculando los números de anoche") and the Recovery ring showed
`no readiness inputs present — "—" (never imputed)`.
- Root causes: (1) the derive card used "last night" copy for EVERY derive,
  including first-run and mid-day passes; (2) `whyFromNote` passed the
  analytics composite's developer note through verbatim.
- Fix: neutral title "Updating your numbers"; first-run variant (no night
  scored yet) explaining that sleep/recovery need a night with the band;
  `whyFromNote` maps the no-input note to a plain sentence, translated in all
  locales; derive card shows "Day X of N" from `DeriveCoordinator.progress`
  (reset in `finally`).
- Validated: test-files runs 42683191519 (142 tests + analyze), 42684463978
  (211 tests). New tests: `first_run_home_copy_test`, `derive_progress_test`,
  extra case in `absence_reason_test`. UI only: no metric/derive/schema
  change, no kAlgoVersion bump. Not hardware-validated.

### 2026-11-09 — CI-05 + ES-01 (branch `fix/ci-05-l10n-gallery`, merged to main)
- **CI-05 fixed** the 8 pre-existing failures: translated
  `whoopFirmwareWarning*` (7 locales) and `reportContact*` (es, fr, hi, zh),
  added `WhoopFirmwareWarning` to the gallery, gave the ru device-picker
  search test a tall view (root cause: the firmware warning pushed the row out
  of the lazy list). Validated with `test-files` runs 42676487905 (analyze +
  7 files, 71 tests) and 42677071191 (gallery/sweep files): all pass.
- **ES-01**: Spanish had 621 English-fallback strings. All translated,
  validated by script (keys, placeholders, plural/select structure, no
  existing value changed) and by run 42677830073 (analyze clean + 10 l10n
  files, 140 tests pass). New fork-only guard `test/spanish_l10n_test.dart`.
- **BUG-566** (WHOOP 5 "Not sleep" lost after reanalysis, reported on 0.10.0):
  not reproduced. Upstream since then made `_reanalyzeForOverride` wait for a
  running derive instead of dropping the edit, with tests
  (`sleep_override_rederive_test.dart`, `sleep_correction_sticks_test.dart`).
  Likely fixed; verify on device.
- Unit-tested only. Not hardware-validated.

### 2026-11-09 — Tests move to local (decision)
- Repo stays private (owner's choice). Full suite costs ~90 quota min/run, so
  `test` workflow disabled via the Actions API (file unchanged). Tests run
  locally on Windows: Flutter 3.41.6, `flutter test --concurrency=1`. The
  zone-dependent goldens (+05:30, -04:00) can't be forced via `TZ` on Windows
  and skip locally.
- `ios-sideload` still runs on push to `main` (~110 quota min each). Option:
  switch it to manual-only if the quota gets tight.

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

## 2026-11-09 — CI-07: fork branding on the sideload IPA

- `ios-sideload.yml` gains a "Fork branding" step running
  `.github/scripts/fork_branding.py` on the CI checkout before the build:
  home-screen name `Edge Dev`, icon hue +150° (red/magenta). Both are
  `workflow_dispatch` inputs. Nothing upstream is edited; bundle id untouched,
  so an over-install keeps its data.
- Verified locally: script rewrites `CFBundleDisplayName` and all 21 AppIcon
  PNGs (1024 marketing icon stays alpha-free). iOS build: pending CI run.
- Run #7 (d0c0902) had been cancelled with "job was not acquired by Runner"
  (macOS capacity); re-run succeeded.

## 2026-11-09 — UX-02: Home redesign, part 1 (branch `feat/home-redesign`)

- Rings in day order (sleep · recovery · strain), recovery larger in the
  middle, reading drawn inside the dial, arcs sweep in once (`Motion.sweep`).
- Strain ring draws the coach's `strain_target` low–high as a band on the
  same 0–21 dial (`Ring.bandFrom/bandTo`); nothing drawn without a real pair.
- Vitals row under the rings: HRV, resting HR, breathing rate, each with an
  arrow and "Usual …" against the 28 days before (`usualBefore`, abstains
  under `kUsualMinDays` = 14, the app-wide threshold). HRV/breathing ride the
  overnight gate with sleep. Resting HR left the glance (no number twice);
  its absence card stays there.
- Sections rise in once per screen lifetime (`_Rise`, `Motion.entrance`);
  all motion collapses under reduced motion. Sync + battery share one
  wrapping line. `Pressable` gives a selection haptic.
- No new dependencies: Flutter's implicit animations cover it.
- Evidence: test-files run 42708664184 (analyze + 29 home/ui2/l10n files,
  574 tests passed), run 42709538906 (`test/home_redesign_test.dart`, 9 new).
  Unit-tested, not hardware-validated; IPA from ios-sideload on the branch.

## 2026-11-09 — UX-03: redesign part 2, merged to main

- `Rise`/`risen()`/`SweepIn`/`tintedCard()` moved into grammar.dart (gallery
  entries added). `detailScaffold` (19 screens) and the embedded Sleep tab
  stagger their sections in, keyed by position+type so a reload plays nothing
  and a loading placeholder's replacement does. Semantics kept during fades.
- Recovery detail: ring sweeps in; a final score tints its card with the
  band hue (provisional stays plain). Home's ring card does the same.
- Home "Activities": the day's finished sessions (`sessionsOfDay`, local
  midnight → next local midnight built from the calendar, DST-safe), oldest
  first, strain when scored; rows open the hour-by-hour day view.
- Evidence: test-files run 42712259267 — analyze clean, 156 ui2/l10n test
  files, +1767 ~5 (skips pre-existing), incl. 14 cases in
  `test/home_redesign_test.dart`. Unit-tested, not hardware-validated.

## 2026-11-10 — BUG-T01: tonight's open rest block is not today's night

- Reported on device: Sleep showed "2h 38m, 20:57 → now" while the user was
  awake at a desk. Cause: the live-edge day's search slice stops at the data
  edge, so a still block begun this evening and still open there was cut at
  "now" and owned by today (its cut end lands in today). The analytics'
  `recordContinues` (unfinished-night deferral) was never wired in edge; it is
  not used as-is because it also drops a real night begun before midnight
  that is in progress at a morning sync.
- Fix (`lib/compute/substrate.dart`): `tonightStillGoing` — live-edge slice,
  block still open within `kUnfinishedNightEdgeSec` of the edge, onset on this
  day at/after the stager's daytime-band start (11:00) → auto window dropped
  for this day; the day it ends owns it.
- No `kAlgoVersion` bump: only the live-edge day's output changes, and that
  day re-derives on every sync; once the edge passes midnight the old code
  already cut the slice at midnight and gave the block to the next day, so no
  finalized row holds the bad window.
- Not fixed here (analytics, sibling repo): the HR confirmation compares the
  block against the median HR of the same slice, so quiet sitting passes; and
  the real night may still bridge to an evening still block ≤ 90 min before
  it, pulling onset early. Workaround: edit the night's times on Sleep.
- Evidence: test-files 42717737790 (+1195, 0 failures, cut at the 45-min cap
  inside derive_tonight_pending_test) + 42723979505 (the remaining 4 files,
  +10). New `test/tonight_not_today_test.dart` (8). test-files timeout → 90 min.
  Unit-tested, not hardware-validated.

## 2026-11-10 — UX-04: a morning check sees its own night

- Reported on device: after a full night Sleep showed the night but Home and
  Health were empty ("still being worked out") — nothing appears until the
  data edge runs 60 min past the wake; a first-week user has no older night
  to show meanwhile.
- `kWakeConfirmMarginSec` 30 → 15 min. `getToday` now serves today's own
  bundle as the overnight as soon as `recovery_state == provisional`
  (`status.overnight_provisional`), ahead of any held-over prior night; the
  readiness headline keeps its provisional path (greyed, never pinned) and the
  freeze/pin still waits for the settle hour, as does the recovery push.
- "I'm awake" on Home while `night_in_progress`: `AppState.markAwakeNow` saves
  the detected onset → now as a manual window; `overnightSettled(userSet:)`
  settles a SLEEP_MANUAL window once the band edge is within the confirm
  margin of its wake.
- §4.2 hotspot (readiness/recompute): pin and push paths untouched; only the
  read seam and the state machine's margin moved. Not independently reviewed.
- Evidence: test-files 42779064344 — analyze clean, 70 files, +617 ~2.
  New cases in `overnight_settled_test` (4) and `recovery_states_test` (2).
  Unit-tested, not hardware-validated.

## 2026-11-10 — FP-CAL, FP-GEM, FP-HEVY

- Calibration (owner decision, deliberately softer than AGENTS §3.3 and
  labelled as such everywhere): `compute/calibration_estimate.dart`. Recovery
  estimate = the composite's own inputs/signs/weights against a centre and
  spread that blend a generic adult reference (worth 3 nights) with the user's
  nights; oriented z capped at ±2; logistic. Strain estimate = the real
  net-TRIMP scorer priced at the population quiet level, over the stored
  1-min HR curve minus the sleep window. Computed in `getToday` only when the
  real metric is absent with `need_baseline:`; shown greyed with
  "Calibrating · n of 14" / "Calibrating". Not in metric_series, day_result,
  pins, notifications or charts; no pipeline change, so no kAlgoVersion bump
  and the WHOOP freeze goldens are untouched. Note: the real Recovery needs 14
  nights per input (readinessCompositeMinBaseline), not 4.
- Gemini: `kGeminiBaseUrl` (OpenAI-compatible), default `gemini-3.8-flash`
  (GA 2026-09-02), fallback `gemini-3.5-flash-lite`. `CoachConfig.fallbackModel`
  (prefs), `postChat` retries once on the fallback for 404/429/5xx only;
  `geminiRejectsSampling` strips temperature/top_p/top_k for gemini ≥ 3.
- Hevy: `import/hevy_import.dart` (GET /v1/workouts, `api-key` header, Hevy
  Pro). Key in the keychain. First sync 90 days, then from last sync − 3 days;
  newest-first walk stops at the cutoff. Re-sync replaces a workout's sets
  (`LocalDb.replaceStrengthSets`), never duplicates; a session with
  hand-logged sets is left alone. Auto-sync from cadence checks every 4 h.
  New coach view `v_strength_sets` (allow-listed; reads strength_set +
  sessions, private sessions excluded). Settings → Your data → Bring data in
  → Hevy.
- Evidence: test-files 42813853531 (analyze clean, 192 files, +2234 ~5 -4;
  the 4 were coach_setup_api_test's lazy-list harness, fixed by a taller test
  view) and 42816248437 (all coach tests + tokens, +400). Unit-tested, not
  hardware-validated; Hevy not exercised against the live API (no key here).

## 2026-11-10 — UX-05: quiet loading on Home

- Owner: the "Updating your numbers" card on every open read as amateur.
  Over a screen that already has numbers, sync/derive is now said in the
  header line (`_syncLine`: small spinner + "Syncing…/Updating…/
  Connecting…", cross-faded with "Synced through …"); the card stays only on
  the bare path (nothing to show yet). Ring arcs glide old → new value
  (implicit tween on the value, not a 0→1 sweep), numbers cross-fade.
- Evidence: test-files 42819433586 — analyze clean, 21 files, +275.
  Unit-tested, not hardware-validated.

## 2026-11-10 — UX-06: Home "B+" (owner's pick from the concepts artifact)

- RingTrio's default layout is now the B headline: recovery in F.n72 with
  "▲/▼ n vs yesterday" (metricValueOn, final scores only) or "Best this
  week" (≥ 3 of the 6 prior days), then recovery / sleep / strain as bars
  (`HomeBarPainter`; strain target zone; values glide). The recovery number
  is shown once. Accessibility layout (big text) keeps the ring rows.
- Coach card near the top: the morning briefing (already generated once the
  night is final) — one-liner typed once, first lines, the inputs as chips;
  pending / connect states. The duplicate briefing row in the plan is gone.
  The morning briefing's inputs now include the strength log.
- Day strip: night band, sessions and the HR curve (`getDayTimeline`), with a
  placeholder of the same size while it loads.
- Training block: `data/strength_summary.dart` (last session's top sets and
  records vs earlier sessions, working sets per muscle group over 7 days,
  calendar days since each group, most-rested group + a recovery-band clause
  only on a final score). Hevy sync stores lift muscles from
  /v1/exercise_templates/{id} in exercise_def.
- Evidence: test-files 42828079164 (analyze clean, 164 files, +1854 -4),
  42830207591 (app_state_regressions passes alone: timing-flaky, untouched
  code), 42830765178 (the 3 real ones fixed: calendar days; day-switcher test
  now ensureVisible before tap). Unit-tested, not hardware-validated.

## 2026-11-10 — BUG-L01: coach in English; last workout without its day

- The coach chat, briefings and journal never named a reply language, so a
  Spanish app got English. `CoachEngine.withReplyLanguage` (applied in
  `_postChatOnce`, the one provider call) states the app language
  (`LocaleController.displayLanguageCode`) in the system message, keeping
  parsed formats (separators, JSON keys, tool names) unchanged; idempotent
  across the fallback retry. Tests: `test/coach_language_test.dart` (5).
- Home training block: the last session's time now says its day (Today /
  Yesterday / weekday / date).
- Evidence: test-files 42834007272 (coach/briefing/journal + new, +439),
  42834756701 (home tests, +67). Unit-tested, not hardware-validated.
