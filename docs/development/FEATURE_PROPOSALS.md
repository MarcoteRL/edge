# Feature proposals

Checked against `docs/FEATURES.md` and open upstream issues (2026-11-09), so
nothing here duplicates what exists. Already shipped, so **not** proposed:
DB export, scheduled backups, CSV export, GPX export, HealthKit export of
sleep/RHR/HRV/energy/workouts, widgets, Live Activities, Shortcuts, firmware
access warning (#680).

Ranked by value × feasibility ÷ maintenance cost.

**Status (2026-11-09):** FP-01 done. Physiological age (WHOOP Age-style) done
as a fork module, see `lib/compute/healthspan.dart`. FP-04 (skin temperature
export) rejected for now: wrist skin temperature is not body temperature and
the sleeping-wrist HealthKit type appears to be Apple-only. Streak calendars
rejected: the design system bans streaks on purpose.

| Rank | ID | Name | Value | Feasibility | Cx | Priority |
|---|---|---|---|---|---|---|
| 1 | FP-01 | Sideload expiry warning | High (you) | High | S | P2 |
| 2 | FP-02 | Automated upstream-sync PR | High (fork) | High | S | P2 |
| 3 | FP-03 | Beat-to-beat HR export to Apple Health | High | Medium | M | P2 |
| 4 | FP-04 | Skin-temperature export | Medium | Medium | M | P3 |
| 5 | FP-05 | Sync diagnostics screen | Medium | High | M | P3 |
| 6 | FP-06 | On-device Apple Foundation Models coach | Medium | Low–Med | L | P3 |

Not proposed: new device integrations. Each needs owned hardware, protocol
work in the sibling repo, and long-term upkeep, and AGENTS.md forbids
deriving metrics from unowned hardware.

---

### FP-01 — Sideload expiry warning
- **Description:** read `ExpirationDate` from the bundle's
  `embedded.mobileprovision` (Sideloadly embeds it) and show a banner plus a
  local notification ~24 h before the app stops launching.
- **Benefit:** free-Apple-ID installs die after 7 days. Background sync silently
  stops and a night of data waits in the band until you re-sign.
- **Feasibility:** native Swift plist parse (CMS-wrapped plist), one method
  channel, `NotificationCenter.emit` for the notification. App Store/TestFlight
  builds have no such file, so the feature turns itself off.
- **Dependencies:** none. **Risks:** low. Keep it iOS-only and fail-silent.
- **Acceptance:** a sideloaded build shows the correct expiry. TestFlight/source
  builds show nothing. One notification per expiry (fired-keys guard).

### FP-02 — Automated upstream-sync PR
- **Description:** weekly workflow on your repo: fetch `upstream/main`, and if
  it's ahead, open a PR merging it into `main`. Then `test.yml` runs on it.
- **Benefit:** stay current without remembering to, and see upstream breakage
  before it reaches the IPA.
- **Feasibility:** plain git + `gh pr create` with `GITHUB_TOKEN`.
- **Risks:** merge conflicts need manual resolution (the PR just fails to open
  cleanly). **Acceptance:** a PR appears within a week of an upstream commit.

### FP-03 — Beat-to-beat HR export to Apple Health (upstream #599)
- **Description:** write overnight R-R beats as `HKHeartbeatSeriesSample` so
  other Health apps can compute RMSSD.
- **Benefit:** your best signal becomes usable outside OpenStrap.
- **Feasibility:** `health` plugin lacks this type, so it needs a small Swift
  writer like the existing `HealthKitSleepWriter.swift`. Data is in `decoded_rr`.
- **Risks:** HealthKit write volume. Must respect the export idempotency rules.
  Triage BUG-558 first, since they share code.
- **Acceptance:** one series per night, idempotent on re-derive, visible in
  Health → Heart → HRV data sources.

### FP-04 — Skin-temperature export (upstream #245)
- **Description:** export nightly skin-temperature deviation where the band
  measures it.
- **Feasibility:** HealthKit has `appleSleepingWristTemperature`, but writing
  it may be restricted to Apple. Verify writability first.
- **Risks:** "never fabricate": export only measured values.
- **Acceptance:** measured nights only, none on absent data.

### FP-05 — Sync diagnostics screen
- **Description:** read-only view of the last N sync sessions: records ACKed,
  drops by reason (below floor, dedupe), empty-sync streak, last HISTORY_END
  verdict.
- **Benefit:** makes #601-class stalls visible instead of a vague status line.
- **Feasibility:** counters already exist (`droppedBelowFloor`,
  `EmptySyncTracker`, `TrimAckVerdict`). This is mostly persisting them plus UI.
- **Risks:** must not add a write on the ACK hot path before commit.
- **Acceptance:** a stuck sync shows the blocking reason.

### FP-06 — Apple Foundation Models coach provider (upstream #368)
- **Description:** iOS 26+ on-device LLM as a coach provider. No key, no network.
- **Feasibility:** Swift-only API, needs a bridge, and tool calling must go
  through the existing allow-listed views guard.
- **Risks:** device/OS gating, model quality, upkeep as the API evolves.
- **Acceptance:** works offline on a supported device. Hidden elsewhere.
