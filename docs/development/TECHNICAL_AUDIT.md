# Technical audit

Baseline: upstream `main` @ `38a83e9` (2026-11-09). Auditor: Claude, in a
session **without a Dart/Flutter toolchain** (pub.dev and the Flutter SDK
host are blocked), so no finding below was found or verified by running
the app or its tests. Every finding cites static evidence.

## Executive summary

A mature, unusually well-documented codebase: 306 Dart files (~197k lines),
618 test files, 15 written invariants, CI with pin-drift and version guards.
The main risks are concentration (five files carry ~48k lines and most fix
churn) and BLE sync edge cases that only show up on real hardware. For this
fork the immediate blocker was operational, not code: **the upstream release
pipeline cannot build in a personal repo** (F-01), which left a Windows
developer with no way to validate changes or get an IPA. That is now addressed
by a separate workflow.

Overall health: **good**. Treat it as "correct until proven otherwise", and
prove things on CI and hardware, not by reading.

## Structure and architecture

See ARCHITECTURE.md. Clean three-repo split (protocol / analytics / edge).
Strong pure-policy seams (`ble_state.dart`, `sync_policy.dart`) that make BLE
logic unit-testable. Weak points: god-objects `data/db.dart` (15.7k lines),
`compute/derivation_engine.dart` (11.4k), `ble/ble_engine.dart` (10.4k),
`state/app_state.dart` (6k). AGENTS.md already flags them as bug hotspots. Not
worth refactoring in a fork: it would make every upstream merge conflict.

## Dependencies

- Flutter pinned to **3.41.6** in all workflows. pubspec: `sdk ^3.11.4`.
- Siblings pinned to commit SHAs, guarded by `.github/scripts/check_sibling_pins.sh`.
- Privacy-relevant: four Firebase packages (core, crashlytics, performance,
  analytics). Collection is off at native level and in Dart until consent.
- `workmanager` is kept only to cancel legacy tasks (documented).
- `flutter pub outdated` / advisories: **not run** (no toolchain). Pending
  as PLANNING AUD-03.

## Testing

618 `*_test.dart` files. CI runs `flutter analyze` + `flutter test
--concurrency=1`, then the timezone-dependent goldens under two more zones.
Two derivation-replay tests skip on CI (golden capture is not committed).
Nightly soak workflow for DB growth. **Baseline result in this session: not
executed.** The first push of your repo with `test.yml` enabled establishes it.

## Build

- Android: `build.yml` needs a release keystore. A debug APK builds locally
  without secrets.
- iOS: `build.yml` ios job is correct for upstream. For a personal repo see F-01.

## Findings

### F-01 — Upstream release pipeline cannot build in a personal repo · Confirmed · P1 · **Fixed (CI-01)**

- **Evidence:** `.github/workflows/build.yml` triggers only on `push: tags: ['v*']`.
  The ios job's "Mount Firebase Secrets" step runs
  `echo "$FIREBASE_OPTIONS_DART_B64" | base64 -d > lib/firebase_options.dart`.
  With the secret unset that writes an empty file over the committed dummy, and
  `lib/telemetry/firebase_bridge.dart` imports it (`DefaultFirebaseOptions`),
  so the Dart compile fails. The preflight job also requires the tag to match
  pubspec and a strictly increasing versionCode.
- **Fix:** new `.github/workflows/ios-sideload.yml` (secretless, manual or push
  to main, artifact only). `build.yml` is untouched.
- **Test:** actionlint 1.7.12 + shellcheck clean. First real run pending on your repo.

### F-02 — Sync deadlock when band flash holds pre-2023 records (upstream #601) · Reported upstream, code path confirmed present · P1 · Open

- **Evidence:** `kMinPlausibleUnix = 1700000000` (`lib/sync/sync_policy.dart`).
  `TrimAckVerdict.blockedNoDurableProgress` (`lib/ble/ble_state.dart`). Auto-continue
  requires `recordsThisOffload > 0 && lastTrimAdvanced` (`lib/ble/ble_engine.dart`,
  `_onOffloadFinished`). A burst made entirely of below-floor records is never
  ACKed, so the band re-offers it forever. A second variant: event-only batches
  (e.g. 0x32 console logs) never count as productive, so the sync stops early.
- **Repro:** WHOOP 4.0 with records from before Nov 2023 still in flash
  (secondhand or revived band). Needs hardware or a recorded capture.
- **Fix direction:** treat "every drop is below the floor and archived to
  `raw_archive`" as durable progress, and count an ACKed cursor-advancing batch
  as progress. **Touches invariant #1** (commit before ACK), so it needs a
  regression test against a synthetic burst plus a hardware check.
- **Relevance to you:** your WHOOP 5.0 (fw 50.38.1.0) is a gen5 band. #601 is
  reported on gen4. Not urgent for your strap.

### F-03 — Committed "dummy" Firebase options point at a real-format third-party project · Potential · P2 (privacy) · Open

- **Evidence:** `lib/firebase_options.dart` is headed "Dummy version" but holds
  well-formed API keys/app ids for project `portofliowebsite-387909`
  (iOS bundle `wtf.openstrap`). Release CI replaces it. Self-builds,
  including this fork's IPA, ship it as-is.
- **Risk:** `Firebase.initializeApp` will probably *succeed* against that
  project (not verified at runtime). Nothing is sent while consent is off
  (`*_collection_enabled=false` natively + `enforceCollectionOffUntilConsent()`),
  but if you enable diagnostics in a self-built app, crash/analytics data could
  go to a project neither you nor (necessarily) upstream controls.
- **Recommendation:** in self-built apps, leave diagnostics/telemetry OFF.
  Upstream fix: replace with values that fail `initializeApp` *gracefully*.
  An invalid `GOOGLE_APP_ID` can raise a native exception on iOS, so this needs
  a device test. Worth an upstream issue rather than a silent fork change.

- **Status 2026-11-14 (PRIV-01):** still the same project id on upstream
  `main`. Fork mitigation stands: `telemetryConsent` defaults to `false`
  (`AppState`), so nothing is collected unless the owner turns diagnostics on
  in a self-built app — leave it off. No code change in the fork without a
  device test (an invalid app id can throw natively on iOS).
- **Draft for an upstream issue (not posted; the owner decides):**
  > *Self-built apps ship working-looking Firebase options.*
  > `lib/firebase_options.dart` says "dummy" but carries well-formed keys and
  > app ids for project `portofliowebsite-387909`. Release CI replaces the
  > file; anyone building from source (sideload IPA, debug APK) does not, and
  > `Firebase.initializeApp` likely succeeds against that project. Collection
  > is off until consent, so nothing leaks by default, but a self-builder who
  > enables diagnostics would send crash/analytics data to a project they do
  > not control. Proposal: ship options that make `initializeApp` fail
  > gracefully (already handled in `main()`), verified on an iOS device, or
  > gate the bridge on a build-time define that self-builds leave unset.

### F-04 — Stale reason in `test.yml` for the Flutter pin · Confirmed · P3 · Fixed in the fork 2026-11-14 (CI-03)

`test.yml` says the repo can't move past 3.41.x because `phosphor_flutter`
extends `IconData`. `pubspec.yaml` no longer depends on phosphor (lib/ui2 uses
Lucide). The other stated blocker (CupertinoPageTransitionsBuilder imports)
may still hold. The pin is still correct. Only the stated reason is out of date.

### F-05 — Upstream scheduled/secret workflows misbehave in a personal repo · Confirmed · P2 (ops) · Open (UI action)

- `star-history.yml`: weekly cron with `contents: write`, commits a regenerated
  SVG of *upstream's* stars into your `main`.
- `soak.yml`: nightly cron (Ubuntu minutes).
- `pr-agent.yml`: needs `PR_AGENT_API_KEY`. It reports "no review performed"
  without it.
- **Action:** disable these three in GitHub → Actions → (workflow) → "Disable
  workflow". No file change, so upstream merges stay clean.

## Upstream-reported bugs (not reproduced here)

Open on OpenStrap/edge as of 2026-11-09: #566 "Not sleep" correction lost
after reanalysis (WHOOP 5.0), #558 HR not sent to Apple Health, #471 strain
shows 0, #450 wear time halts, #277 workouts bypass Health export, #186 smart
alarm doesn't fire, #593 sleep missing awake points, #538 iOS uninstall
unpairs ring (ASK). #566 and #558 are the most relevant to an iPhone + WHOOP 5
user. Triage them first (PLANNING BUG-566, BUG-558).

## Security

No secrets in the repo apart from F-03's Firebase identifiers (client
identifiers by design, not credentials). Workflows use `persist-credentials:
false` and least-privilege `permissions`. The coach reads only allow-listed SQL
views behind an adversarially-tested guard. A full security review of BYOK key
storage (`flutter_secure_storage`) and the ChatGPT OAuth flow is pending (SEC-01).

## Performance

Not measured (needs a device). Design already isolates heavy compute
(`Isolate.run`, 17 call sites) and caps the image cache. iOS migrations run under
the launch watchdog, so keep them cheap (invariant 11).

## Main risks

1. Changes to BLE/sync without hardware: permanent data loss if ACK ordering breaks.
2. Firmware drift: WHOOP 50.43+ requires a signed token (upstream #673).
   **Never let the official app touch your band.**
3. Merge pain if the fork edits the five hotspot files casually.
4. Free Apple ID sideloads expire every 7 days. App Groups (widget, Live
   Activity) may not work.
