import '../../l10n/date_text.dart';
// HOME — decision-oriented. "What matters today?"
//
// Three rings that decide the day — what the night gave back, what the day has
// cost, what the night was made of — three signals worth a glance under them,
// and the small set of things the app can honestly say are worth doing. The
// hard part is not the circles: readiness exists on 71 % of days and needs
// four prior nights before it exists at all, so what a ring does with nothing
// in it is the design. See [RingTrio]. No insight feed and no general
// health-observation card: those are OBSERVATION, and observation lives on
// Health. A home screen that also observes is a dashboard, and a dashboard is
// what this rebuild is replacing.
//
// ONE NAMED EXCEPTION, and it is deliberately not a crack in that rule: the
// illness watch ([_bodyWatch]). It is not a feed and it cannot grow into one —
// exactly one detector may render here, it renders only when its own state is
// amber or red, and it is silent on every ordinary day. The reason it earns
// Home is timing rather than importance: the watch is at its most useful when
// it first goes amber, and amber has no notification, so before this the
// earliest signal the app produces could only be found by opening Health and
// scrolling. A signal that arrives too late to act on is not worth computing.
// If a second observation ever wants this slot, the answer is no — build the
// feed on Health where the others already live.
//
// This file also carries the plumbing every screen in this folder shares —
// navigation, the repo handle, and the three ways a value arrives from the
// data layer. They live here rather than in a fourth file because there are
// only three of them and they are read together.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../ai/briefing.dart'
    show Briefing, BriefingPeriod, BriefingStore, currentBriefingPeriod, resolveBriefingToShow;
import '../../compute/findings.dart'
    show
        isRecentFindingDate,
        kReadinessEasyBelow,
        kReadinessGoodFrom,
        kReadinessRestBelow;
import '../../data/day_label.dart' show todayLabel, calendarDaysBetween, dayLabelOf;
import '../../platform/provisioning.dart'
    show Provisioning, sideloadExpiryNotice;
import '../../compute/onehz_pipeline.dart'
    show readinessInputShortfallNote, readinessUnstableBaselineNote;
import '../../data/db.dart' show DbRebuild, LocalDb;
import '../../data/journal_fields.dart' show formatMinuteOfDay;
import '../../data/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/presentation_text.dart';
import '../../l10n/display_text.dart';
import '../../l10n/decimal_text.dart';
import '../../state/locale_controller.dart';
import 'package:intl/intl.dart';
import 'package:openstrap_analytics/onehz.dart'
    show quietHrrMinDays, readinessCompositeMinBaseline;
import '../../models/metric.dart';
import '../../models/payloads.dart' show todayHeadlineOf;
import '../../notify/notification_prefs.dart' show NotificationPrefs;
import '../../state/app_state.dart';
import '../../state/clock_format.dart' show formatClockOf;
import '../../state/units_controller.dart';
import '../../theme/theme_switcher.dart' show themedRoute;
import '../activity/catalogue.dart' show activityByName, catalogueName;
import '../activity/day_strain.dart' show DayStrainDetail;
import '../profile/alarm.dart'
    show AlarmArmState, alarmArmOf, alarmDoor, alarmGlanceCard;
import '../profile/devices.dart' show RePair, formatDayTime;
import '../profile/profile.dart';
import '../profile/wearable_numbers.dart'
    show WearableCells, kHomeWearableRows;
import '../ui2.dart';
import 'ai_briefing.dart' show AiBriefingScreen;
import 'coach.dart';
import 'detected_activities.dart';
import 'day_timeline.dart' show DayTimelineScreen;
import '../../coach/coach_config.dart' show CoachConfig;
import '../../data/strength_summary.dart';
import 'metric_detail.dart';
import 'readiness_detail.dart';
import 'sleep_detail.dart';

// ═══════════════════ shared plumbing ═══════════════════

/// Page padding. The bottom inset clears the shell's floating nav.
const pad = EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x16 + S.x8);

/// Push a detail screen. Every drill-down in ui2 goes through here.
///
/// This was a raw `PageRouteBuilder` with its own fade+slide, which silently
/// killed the iOS edge-swipe-back on all ~20 screens it pushes — a
/// PageRouteBuilder has no interactive back-gesture machinery. The app's own
/// transition is registered in the theme instead (see page_transitions.dart),
/// so a plain route gets the fade-through on Android and the Cupertino slide
/// WITH swipe-back on iOS. [themedRoute] also keeps the pushed screen
/// re-colouring on an appearance change and names the route for Crashlytics.
void go(BuildContext c, Widget w) => Navigator.of(c)
    .push(themedRoute((_) => w, name: w.runtimeType.toString()));

/// The repo, or null when there is no AppState above us — which is the case in
/// every golden. A screen with no repo renders its absent states, which is
/// exactly what we want a golden to capture.
LocalRepository? repoOf(BuildContext c) {
  try {
    return c.read<AppState>().repo;
  } catch (_) {
    return null;
  }
}

/// The user's unit system, or null in a golden. A screen that cannot reach it
/// renders what the store holds, which is metric.
UnitsController? unitsOf(BuildContext c) {
  try {
    return c.watch<UnitsController>();
  } catch (_) {
    return null;
  }
}

/// "72.4 kg" → `('72.4', 'kg')`. [UnitsController] owns every conversion and
/// hands back one string; this only puts the two halves in the two slots a
/// row has. Never convert in a screen.
(String, String) splitUnit(String s) {
  final i = s.lastIndexOf(' ');
  return i < 0 ? (s, '') : (s.substring(0, i), s.substring(i + 1));
}

/// The band-sync trigger, or null when there is no AppState above us. Every
/// "Sync the band" CTA in this folder goes through here — a call to action
/// with no action behind it is worse than no call to action.
VoidCallback? syncOf(BuildContext c) {
  try {
    final app = c.read<AppState>();
    return app.syncNow;
  } catch (_) {
    return null;
  }
}

/// The card Home shows instead of "Sync the band" when no band is paired, or
/// null when one is (or there is no AppState above us). Onboarding's "Skip for
/// now" opens the app with nothing paired; a sync then returns at once, the
/// tap grace held "Connecting to your band" up for 20 s over nothing, and
/// nothing on Home pointed at pairing.
Widget? noBandCard(BuildContext c, AppLocalizations? l) {
  try {
    if (c.read<AppState>().isPaired) return null;
  } catch (_) {
    return null;
  }
  return StatusCard(
    l?.devicesNoBandPaired ?? 'No band is paired',
    l?.pairingSkipNote ??
        'The app opens without a band. Nothing is measured until one is paired.',
    fix: l?.devicesPairABand ?? 'Pair a band',
    icon: LucideIcons.watch,
    onFix: () => goto(c, const RePair()),
  );
}

/// Whether the database had to be rebuilt to start this launch, or null in a
/// golden. Same shape as [repoOf] and [syncOf].
DbRebuild? dbRebuildOf(BuildContext c) {
  try {
    return c.read<AppState>().dbRebuild;
  } catch (_) {
    return null;
  }
}

/// The armed alarm and its state, or null when there is no AppState above us
/// (every golden). Read-only: Home never arms or re-arms anything.
(DateTime?, AlarmArmState)? alarmArmOfContext(BuildContext c) {
  try {
    return c.select<AppState, (DateTime?, AlarmArmState)>(alarmArmOf);
  } catch (_) {
    return null;
  }
}

/// Whether a live workout is open, or false in a golden. `select`, not
/// `watch`: AppState ticks at ~1 Hz while a session is live, and this screen
/// only cares about the bool flipping. The bare-day card branches on it — see
/// [workoutHoldCard].
bool workoutLiveOf(BuildContext c) {
  try {
    return c.select<AppState, bool>((a) => a.activeWorkout != null);
  } catch (_) {
    return false;
  }
}

/// Whether cycle tracking is on, or false in a golden. `select` for the same
/// reason as its neighbours.
bool cycleTrackingOf(BuildContext c) {
  try {
    return c.select<AppState, bool>((a) => a.cycleTrackingEnabled);
  } catch (_) {
    return false;
  }
}

/// Whether the band is actively sending data right now, or false in a
/// golden. Same shape and same reasoning as [workoutLiveOf] — `select`
/// because this only cares about the bool flipping, not AppState's ~1 Hz
/// heartbeat.
bool syncingNowOf(BuildContext c) {
  try {
    return c.select<AppState, bool>((a) => a.syncingNow);
  } catch (_) {
    return false;
  }
}

/// Whether a derive job is running or about to (the backlog just landed and
/// today's numbers are being worked out), or false in a golden.
/// How far the data we hold actually reaches — the band's OWN clock on the
/// newest record BANKED, not when the BLE frame arrived and not when the app
/// last talked to the strap. Null in a golden and before any record exists.
///
/// `select`, like its neighbours: this rebuilds when the data edge moves, not
/// on AppState's ~1 Hz heartbeat.
DateTime? lastDataAtOf(BuildContext c) {
  try {
    return c.select<AppState, DateTime?>((a) => a.lastRecordAt);
  } catch (_) {
    return null;
  }
}

/// "Synced through 11:06" — the one line that answers "how far are we?".
///
/// It reads the BAND's clock, so it says how far the DATA reaches. That is a
/// different number from "last contact" and only this one is the question a
/// sync status has to answer: a connection that transfers nothing is not
/// progress, and a status built on contact time would report it as progress.
///
/// [todayId] is the `YYYY-MM-DD` the screen is ALREADY showing, not
/// `DateTime.now()`. A clock read during `build` decides "is this today?" once
/// and then goes stale — sitting on Home across midnight with no new record,
/// last night's 23:50 would keep rendering as a bare "23:50" and read as
/// tonight. Keying off the rendered day cannot contradict the date line
/// directly above it, whatever the hour. Null (no day on screen yet) ⇒ always
/// dated, which is the honest answer when we do not know what "today" is.
///
/// Bare clock time for the day on screen, the full "Fri 4 Sep, 07:12"
/// otherwise — a lone "07:12" against a strap not worn since Friday is the
/// most misleading thing this line could say.
String syncedThroughLabel(DateTime? at, String? todayId,
    [AppLocalizations? l]) {
  if (at == null) return l?.homeSyncedNever ?? 'No band data yet';
  final today = todayId == null ? null : DateTime.tryParse(todayId);
  final isToday = today != null &&
      at.year == today.year &&
      at.month == today.month &&
      at.day == today.day;
  final when = isToday ? formatClockOf(at) : formatDayTime(at, l);
  return l?.homeSyncedThrough(when) ?? 'Synced through $when';
}

/// The band's battery, straight off the same [DeviceState] devices.dart
/// already reads (`app.device.batteryPct`/`.charging`) — never a second poll.
/// Null when unpaired or the strap hasn't reported a level yet, which this
/// deliberately renders as nothing rather than a placeholder.
(double, bool)? deviceBatteryOf(BuildContext c) {
  try {
    return c.select<AppState, (double, bool)?>((a) {
      final pct = a.device.batteryPct;
      final charging = a.device.charging;
      // Both or neither — a known level with an unknown charging state must
      // not fall back to `false`, which would draw a plain (or worse, red)
      // icon over a charging state we simply haven't heard yet.
      return (pct == null || charging == null) ? null : (pct, charging);
    });
  } catch (_) {
    return null;
  }
}

/// Draining, not charging, at or under the same default the low-battery
/// notification uses ([NotificationPrefs.batteryPctDefault]) — this reads the
/// shared constant rather than the user's live pref, since a color hint on
/// Home is not worth an async prefs read on every build.
bool lowBattery(double pct, bool charging) =>
    // Strict `<`, matching device_alerts.dart's own `fireLow` comparison —
    // the color hint should agree with the alert at the boundary, not just
    // near it.
    !charging && pct < NotificationPrefs.batteryPctDefault;

/// "78%" with a battery glyph, next to the sync line — the one place that
/// already used a battery icon as an unrelated recovery-ring metaphor, but
/// this is the actual reading. Mirrors devices.dart's `SourceRow` battery
/// chip (same icon swap, same 13px size) rather than inventing a new look.
Widget? batteryLine(BuildContext c) {
  final battery = deviceBatteryOf(c);
  if (battery == null) return null;
  final (pct, charging) = battery;
  final p = P.of(c);
  final color = lowBattery(pct, charging) ? p.on(C.red) : p.ink3;
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(charging ? LucideIcons.batteryCharging : LucideIcons.battery,
        size: 13, color: color),
    const SizedBox(width: 3),
    Text('${pct.round()}%', style: F.cap.copyWith(color: color)),
  ]);
}

/// The status line as Home renders it, so the loading / failed / bare paths
/// show it too. It answers "how far are we?", and the moment that question is
/// loudest is the one where there is no day to show.
Widget syncedThroughLine(BuildContext c, String? todayId,
    [AppLocalizations? l]) {
  return Text(
    syncedThroughLabel(lastDataAtOf(c), todayId, l),
    style: F.cap.copyWith(color: P.of(c).ink3),
  );
}

bool derivingOf(BuildContext c) {
  try {
    return c.select<AppState, bool>((a) => a.deriving || a.derivePending);
  } catch (_) {
    return false;
  }
}

/// "Day 3 of 12." for a derive pass spanning more than one day, else null. A
/// first sync of a band that holds days of history can take minutes, and a
/// card that only spins for that long reads as stuck.
String? deriveProgressLine(BuildContext c, AppLocalizations? l) {
  final ({int done, int total}) p;
  try {
    p = c.select<AppState, ({int done, int total})>((a) => a.deriveProgress);
  } catch (_) {
    return null;
  }
  if (p.total <= 1 || p.done <= 0) return null;
  return l?.homeAnalyzingProgress(p.done, p.total) ??
      'Day ${p.done} of ${p.total}.';
}

/// Read a metric envelope. `_scalarMetric` writes the literal string `'—'` for
/// an absent value, so this must never be replaced by `map['value'] as num`.
Metric metricOf(Object? raw) => Metric.parse(raw);

/// WHICH SENSOR counted the steps, in the two words a card has room for — or
/// null when nothing counted (and on days derived before the ladder existed,
/// whose envelopes name no sensor).
///
/// Read off `inputs_used`, which names the sensor rather than the table the
/// count was stored in. The strap's 100 Hz pedometer and its on-chip counter
/// are BOTH "Strap" here: they are genuinely different measurements, but that
/// difference is a density-3 fact and it is spelled out on Nerd stats. What
/// this must never blur is strap versus phone — a card that lets the phone's
/// count read as the wrist's, or the other way round, defeats the whole point
/// of resolving the day per window.
String? stepSensorLabel(Metric m, [AppLocalizations? l]) {
  final used = m.inputsUsed;
  final strap = used.contains('band_pedometer_100hz') ||
      used.contains('band_step_counter');
  final phone = used.contains('phone_pedometer');
  if (strap && phone) return l?.homeStepSensorStrapPhone ?? 'Strap + phone';
  if (strap) return l?.homeStepSensorStrap ?? 'Strap';
  if (phone) return l?.homeStepSensorPhone ?? 'Phone';
  return null;
}

/// The inner object of an envelope whose `value` is a MAP, not a number —
/// every cross-day metric is one of these (`regularity.value.sri`,
/// `sleep_coach.need.value.need_sec`). `Metric.parse` reads those as absent,
/// because a map is not a num, so the object has to come out by hand.
Map<String, dynamic>? envValue(Object? raw) {
  if (raw is! Map) return null;
  final v = raw['value'];
  return v is Map ? v.cast<String, dynamic>() : null;
}

/// The night the overnight block in a `getToday()` result actually came from,
/// when that is NOT today's — otherwise null.
///
/// `getToday` holds the last scored night over until today's settles, which is
/// every morning before the first sync and the whole of any gap after one.
/// Readiness, sleep, resting HR, HRV and skin temperature then all describe
/// that night while steps and active energy describe today.
///
/// WHAT THIS IS STILL FOR, now that no screen prints its numbers as today's
/// (see [overnightMetric]): naming WHICH NIGHT, and opening it. A screen that
/// is explicitly about a dated night — Sleep, with a day stepper over it —
/// wants this, because the night it should open is the last one that scored,
/// not a calendar day with no sleep in it. Every screen resolves that night
/// HERE so Home, Readiness, Sleep and Health cannot each answer "which night?"
/// differently.
String? heldOverNightOf(Map<String, dynamic> today) {
  final st = today['status'];
  if (st is! Map) return null;
  return st['showing_prior_overnight'] == true
      ? st['overnight_day']?.toString()
      : null;
}

/// Why today has no overnight figures, or null when it has its own.
///
/// Two absences that are not interchangeable, both read straight off
/// `status.overnight_state`:
///
///   * `building` — today's records HAVE reached the app and the night has not
///     finished being worked out. It resolves on its own and there is nothing
///     to ask anyone to do.
///   * anything else — nothing from last night has arrived. Syncing is the
///     thing that changes it.
///
/// Prose, not a `key:arg` token, so `whyFromNote` passes it through as the
/// sentence it already is.
String? staleOvernightNote(Map<String, dynamic> today, [AppLocalizations? l]) {
  if (heldOverNightOf(today) == null) return null;
  final st = today['status'];
  return (st is Map ? st['overnight_state']?.toString() : null) == 'building'
      ? l?.homeOvernightBuilding ?? 'Last night is still being worked out.'
      : l?.homeOvernightNothingYet ??
          'Nothing from last night has reached the app yet.';
}

/// An overnight envelope, REFUSED when the night behind it is not today's.
///
/// This reverses a decision that was made deliberately and was wrong on a
/// phone. `getToday` serves the last scored night whenever today's has not
/// settled, and the old argument for printing it was that the number is real
/// and the most recent one there is, so naming its night is enough. It is not:
/// a figure in the today slot is read as today's before anything under it is,
/// so a morning the strap was never worn showed last week's sleep as this
/// morning's, and the caption saying otherwise sat below three rings nobody
/// reads past. A stale number is a worse answer than an honest gap.
///
/// So the numbers stop here and the reason travels in their place. The night
/// itself is not lost — [heldOverNightOf] still names it, and the screens that
/// are ABOUT a dated night still open it.
Metric overnightMetric(Map<String, dynamic> today, Object? raw,
    [AppLocalizations? l]) {
  final why = staleOvernightNote(today, l);
  return why == null ? metricOf(raw) : Metric(note: why);
}

/// A scalar lifted out of an object-valued envelope, wearing that envelope's
/// honesty (tier, confidence, note) so `StatusCard.forMetric` still works on
/// it.
Metric envMetric(Object? raw, num? scalar, {String? unit}) {
  final m = raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};
  final env = Metric.parse({...m, 'value': scalar});
  return scalar == null && env.note == null
      ? Metric(unit: unit, note: m['note']?.toString())
      : Metric(
          value: scalar,
          unit: unit ?? env.unit,
          confidence: env.confidence,
          tier: env.tier,
          inputsUsed: env.inputsUsed,
          note: env.note,
        );
}

/// One stored chart point: `t` is the epoch SECONDS `getChart` stamps on it
/// (local noon of the day the value was derived on), `v` the value.
typedef ChartPoint = ({int t, double v});

/// A `[{t, v}]` point list from `getChart`, timestamps INTACT.
///
/// [seriesOf] drops `t`, and everything downstream then labelled its x axis off
/// the ARRAY INDEX — `'Today'`, `'N days ago'`, weekday letters. `metric_series`
/// stores one row per DERIVED day, not one per calendar day, so after a sync gap
/// the newest stored point is days old and was still being called "Today".
/// Anything that draws a dated axis reads this.
List<ChartPoint> pointsOf(Object? chart) {
  final pts = chart is Map ? chart['points'] : null;
  if (pts is! List) return const [];
  return [
    for (final e in pts)
      if (e is Map && e['v'] is num && e['t'] is num)
        (t: (e['t'] as num).round(), v: (e['v'] as num).toDouble()),
  ];
}

/// The bare values of a point list, for statistics — a mean, a last reading,
/// an [AxisSpec]. NEVER for a painter: a compacted list is the bug, because it
/// lets 22 stored days masquerade as 30 continuous ones.
List<double> valuesOf(List<ChartPoint> pts) => [for (final p in pts) p.v];

/// [pts] laid out DENSE: one slot per calendar day, [days] slots long, ending
/// today. A day `metric_series` has no row for is `null`, which the painter
/// draws as a break rather than joining across.
///
/// This is the shape every chart in this app takes. `metric_series` gets a row
/// only on a day that derives, so the stored list is already compacted: after a
/// four-day sync gap the newest point sat at the right-hand edge under the
/// label "Today", and the line ran straight through the missing week as though
/// it had been measured.
List<double?> denseDays(List<ChartPoint> pts, int days) {
  final out = List<double?>.filled(days, null);
  for (final p in pts) {
    final behind = daysBehind(p.t);
    if (behind == null || behind < 0 || behind >= days) continue;
    out[days - 1 - behind] = p.v;
  }
  return out;
}

/// A `[{t, v}]` point list from `getChart` as a plain series.
///
/// Values only — the caller cannot tell WHEN any of them was recorded. Use
/// [pointsOf] for anything that labels, spans or dates the series; this is for
/// sparklines, which claim nothing about time.
List<double> seriesOf(Object? chart) => valuesOf(pointsOf(chart));

/// An x-axis label for a stored point: [todayWord] when the point really is
/// today's, otherwise "N days ago" counted from the point's OWN date.
///
/// The same vocabulary the axes already spoke. What changed is where N comes
/// from: it used to be the point's position in the array, and `metric_series`
/// holds one row per DERIVED day, so a thirty-point series can span two months
/// and both its edges were labelled as though it spanned thirty days.
String axisDay(int? epochSec,
    {String todayWord = 'Today', String unitWord = 'days'}) {
  final behind = daysBehind(epochSec);
  if (behind == null) return '';
  if (behind <= 0) return todayWord;
  return '$behind $unitWord ago';
}

/// Whole calendar days between a stored point and today, or null when there is
/// no point. Anything above zero means the number drawn is not today's, and a
/// card that presents it as today's has to say so.
int? daysBehind(int? epochSec) {
  if (epochSec == null) return null;
  return calendarDaysBetween(
      DateTime.fromMillisecondsSinceEpoch(epochSec * 1000), DateTime.now());
}

/// The withheld-rollup reason inside a `getInsights()` result, or null when the
/// result is real (or simply empty).
Map<String, dynamic>? staleReasonOf(Map<String, dynamic> insights) =>
    insights['stale'] is Map
        ? (insights['stale'] as Map).cast<String, dynamic>()
        : null;

/// The cross-day rollup was WITHHELD: `getInsights` returned the reason it
/// refused instead of the numbers (`LocalRepositoryImpl.crossDayStaleReason`).
///
/// Every screen that reads the rollup renders this rather than quietly showing
/// nothing — "you have no drivers yet" and "we have drivers we will not stand
/// behind" are different states, and the cold-start copy is a wrong answer to
/// the second one.
/// The database could not be opened on this launch and was rebuilt.
///
/// This is the loudest thing this screen can say, and it should be: the old
/// file is parked on disk and only what `salvaged` lists came back. A rebuild
/// the user never hears about is indistinguishable from their data quietly
/// vanishing — which is the one thing a local-first app must never do.
///
/// The counts are stated per table rather than summed. "1,204 rows recovered"
/// reads as reassurance; "nutrition 0" is the sentence that actually tells
/// someone their food log is gone.
StatusCard? dbRebuiltCard(DbRebuild? r, [AppLocalizations? l]) {
  if (r == null) return null;
  final saved = r.salvaged.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final lost = r.salvaged.entries.where((e) => e.value == 0).toList();
  final savedList = saved.map((e) => '${e.key} ${thousands(e.value)}').join(' · ');
  final lostList = lost.map((e) => e.key).join(' · ');
  return StatusCard(
    l?.homeDbRebuiltTitle ?? 'Your database was rebuilt to start the app',
    '${r.cause}\n\n'
        '${saved.isEmpty ? (l?.homeDbRebuiltNothingRecovered ?? 'Nothing could be read back.') : (l?.homeDbRebuiltRecovered(savedList) ?? 'Recovered: $savedList.')}'
        '${lost.isEmpty ? '' : ' ${l?.homeDbRebuiltEmpty(lostList) ?? 'Empty: $lostList.'}'}'
        '\n\n${l?.homeDbRebuiltKept(r.quarantinePath) ?? 'The original file is kept at ${r.quarantinePath} — nothing was deleted.'}',
    icon: LucideIcons.databaseBackup,
  );
}

/// The bare day during a live workout — missing COMPUTE, not data. A live
/// session holds derivation (`DeriveScheduler.setWorkoutActive`), so nothing
/// lands in `day_result` until it ends: the band keeps recording, the sync
/// keeps landing records, and "Sync the band" is a false answer — the sync
/// completes and changes nothing on this screen. The true remedy is finishing
/// the session, and its bar is pinned right below this card, so the card
/// points there rather than duplicating the door.
StatusCard workoutHoldCard([AppLocalizations? l]) => StatusCard(
      l?.homeWorkoutHoldTitle ?? 'A workout is still running',
      l?.homeWorkoutHoldBody ??
          'Today is paused while a workout runs. The band keeps recording; finish the workout from the bar below and today fills in.',
      icon: LucideIcons.timer,
    );

StatusCard? staleInsightsCard(
    Map<String, dynamic>? reason, VoidCallback? onSync, [AppLocalizations? l]) {
  final s = reason;
  if (s == null) return null;
  final built = s['built_for_day']?.toString();
  return StatusCard(
    l?.homeInsightsRebuildingTitle ?? 'Your cross-day insights are being rebuilt',
    switch (s['kind']) {
      'algo_version' => l?.homeInsightsRebuildingAlgoVersion ??
          'How these are computed changed with the last update.',
      'stale' => built == null || built.isEmpty
          ? (l?.homeInsightsStaleOverWeek ??
              'Your trends were last updated over a week ago. Sync the band to bring them up to date.')
          : (l?.homeInsightsStaleOnDay(prettyDay(built, l)) ??
              'Your trends were last updated on ${prettyDay(built, l)}. Sync the band to bring them up to date.'),
      _ => l?.homeInsightsNoVersionStamp ?? 'Your trends are being updated. This takes a minute after a sync.',
    },
    fix: onSync == null ? '' : (l?.homeSyncBand ?? 'Sync the band'),
    icon: LucideIcons.refreshCw,
    onFix: onSync,
  );
}

// ── formatting ──

String hm(num? minutes) {
  if (minutes == null) return '';
  final m = minutes.round();
  final l = lookupAppLocalizations(
    Locale(LocaleController.displayLanguageCode),
  );
  return m < 60
      ? l.supplementMinutesValue('$m')
      : l.supplementHoursMinutesValue(
          '${m ~/ 60}',
          (m % 60).toString().padLeft(2, '0'),
        );
}

String thousands(num? v) => v == null
    ? ''
    : NumberFormat.decimalPattern(
        LocaleController.displayLanguageCode,
      ).format(v.round());

/// A metric value at the precision its unit actually carries.
///
/// ONE rule, so the same reading is not `71.6` on the detail screen and `72`
/// on the card that links to it. A tenth of a bpm on a nocturnal minimum — or
/// of a millisecond on beat timing recovered from 1 Hz records — is precision
/// the measurement does not have, and a number printing more digits than it
/// knows reads as a more careful measurement than it is. Unitless scores keep
/// a decimal only while they are small enough for one to mean something.
String metricValue(String unit, num? value) {
  if (value == null) return '';
  final v = value.toDouble();
  switch (unit) {
    case 'min':
      return hm(v);
    case 'steps':
    case 'kcal':
      return thousands(v);
    case 'bpm':
    case 'ms':
    case '%':
      return v.round().toString();
    case 'br/min':
    case '°':
      return displayFixed(v, 1);
  }
  if (v.abs() >= 100) return v.round().toString();
  if (v.abs() >= 10) return displayFixed(v, v == v.roundToDouble() ? 0 : 1);
  return displayFixed(v, 1);
}

/// The unit to print BESIDE [metricValue]'s output, which is empty when the
/// format already carries it: `metricValue('min', 443)` is "7h 23m", and a
/// `min` label next to that reads "7h 23m min".
String unitBeside(String unit) => unit == 'min'
    ? ''
    : localizedText(
        lookupAppLocalizations(Locale(LocaleController.displayLanguageCode)),
        unit,
      );

/// Minute-of-day → "10:40 PM".
///
/// ONE clock format in the app. This used to render 24-hour while Wellness
/// rendered the same field 12-hour, so a target bedtime read `22:40` on Home
/// and `10:40 PM` two screens away. Both now go through the journal layer's
/// [formatMinuteOfDay], which follows the user's 12/24-hour choice
/// (`state/clock_format.dart`).
String clock(num? minOfDay) =>
    minOfDay == null ? '' : formatMinuteOfDay(minOfDay.round());

/// Epoch seconds → "11:08 PM" / "23:08" in the device zone.
String clockOfTs(num? ts) {
  if (ts == null) return '';
  return formatClockOf(DateTime.fromMillisecondsSinceEpoch(ts.round() * 1000));
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String monthName(int month, AppLocalizations? l) {
  if (l == null) return _months[month - 1];
  return [
    l.homeMonthJanuary, l.homeMonthFebruary, l.homeMonthMarch,
    l.homeMonthApril, l.homeMonthMay, l.homeMonthJune,
    l.homeMonthJuly, l.homeMonthAugust, l.homeMonthSeptember,
    l.homeMonthOctober, l.homeMonthNovember, l.homeMonthDecember,
  ][month - 1];
}

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Abbreviated month for "Thu 4 Sep" date chips.
String monthShortName(int month, AppLocalizations? l) {
  if (l == null) return _monthsShort[month - 1];
  return [
    l.homeMonthJanuaryShort, l.homeMonthFebruaryShort, l.homeMonthMarchShort,
    l.homeMonthAprilShort, l.homeMonthMayShort, l.homeMonthJuneShort,
    l.homeMonthJulyShort, l.homeMonthAugustShort, l.homeMonthSeptemberShort,
    l.homeMonthOctoberShort, l.homeMonthNovemberShort, l.homeMonthDecemberShort,
  ][month - 1];
}

const _weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Abbreviated weekday for `DateTime.weekday` (1 = Monday), e.g. "Thu 4 Sep"
/// date chips. Reuses the `wellness*` short-day keys — they're already
/// translated everywhere and mean the same three letters here.
String weekdayShortName(int weekday, AppLocalizations? l) {
  if (l == null) return _weekdaysShort[weekday - 1];
  return [
    l.wellnessMon, l.wellnessTue, l.wellnessWed,
    l.wellnessThu, l.wellnessFri, l.wellnessSat, l.wellnessSun,
  ][weekday - 1];
}

/// 'YYYY-MM-DD' → "Saturday, 20 May".
String prettyDay(String? dayId, [AppLocalizations? l]) {
  final d = dayId == null ? null : DateTime.tryParse(dayId);
  if (d == null) return '';
  return localizedDate(
    d,
    l?.localeName ?? LocaleController.displayLanguageCode,
    weekday: true,
  );
}

/// The readiness band. `readiness_glassbox` carries no label of its own, so the
/// banding is ours and lives in one place — this one.
///
/// [tier] is that same banding in a form the native surfaces can read.
/// `WidgetService.push` publishes it as `readiness_tier` (and [label] as
/// `readiness_band`) so the widget, the Watch and Siri paint it in their own
/// palettes instead of each keeping a private copy of the cut-offs. They did,
/// and a 65 rendered green on the phone, orange on the widget and yellow on
/// the wrist. -1 = not scored.
///
/// THE CUT-OFFS ARE THE SCORE'S OWN QUANTILES, NOT ROUND NUMBERS (issue #250).
/// `readinessComposite` is `100 / (1 + exp(-z̄))` with no scale parameter, and
/// z̄ is a weight-renormalised mean of per-input robust z's — each ~N(0,1)
/// against that person's OWN baseline. So the score is a percentile of self
/// whose CENTRE IS 50 BY CONSTRUCTION: a night exactly at personal median
/// scores 50, and the old 40/60/80 bands filed that median night under "Take it
/// easy". Roughly a quarter of all nights fell under "Rest today" and 1.7 %
/// could ever reach "Good to go" — it needed every input ~1.4 SD above median
/// at once. A warning that fires on the typical night is not a warning.
///
/// z̄'s own SD is NOT 1: averaging the disclosed weights (.40/.30/.20/.10,
/// renormalised over present inputs) gives σ ≈ 0.55-0.60 if the inputs were
/// independent, ~0.70 at the positive correlation HRV/RHR/RR actually have.
/// σ ≈ 0.65 is the middle of that, and the cut-offs below are its quantiles:
///
///   score = 100 / (1 + exp(-0.65 · Φ⁻¹(p)))
///     p=.05 → 26   p=.20 → 37   p=.75 → 61
///
/// (`kReadinessRestBelow` / `kReadinessEasyBelow` / `kReadinessGoodFrom` in
/// findings.dart, shared with the push and the log), which lands 5 % of nights
/// on "Rest today", 15 % on "Take it easy", 55 % on "Steady" and 25 % on
/// "Good to go". The median night is now the neutral band,
/// which is the whole point. Under the old cut-offs the same distribution read
/// 27 / 47 / 25 / 2.
///
/// σ is the one soft number here — it is a property of how correlated a given
/// person's four inputs are, and it moves with how many of them are present.
/// Re-derive it from a real `metric_series` readiness distribution when there
/// is one long enough to measure; do not nudge the cut-offs by feel.
({String label, Color color, int tier}) readinessBand(num? v,
    [AppLocalizations? l]) {
  if (v == null) {
    return (label: l?.homeReadinessNotScored ?? 'Not scored', color: C.n400, tier: -1);
  }
  if (v >= kReadinessGoodFrom) {
    return (label: l?.homeReadinessGoodToGo ?? 'Good to go', color: C.green, tier: 3);
  }
  if (v >= kReadinessEasyBelow) {
    return (label: l?.homeReadinessSteady ?? 'Steady', color: C.green, tier: 2);
  }
  if (v >= kReadinessRestBelow) {
    return (label: l?.homeReadinessTakeItEasy ?? 'Take it easy', color: C.orange, tier: 1);
  }
  return (label: l?.homeReadinessRestToday ?? 'Rest today', color: C.red, tier: 0);
}

/// Glass-box driver keys are the pipeline's own short names.
const driverLabels = {
  'hrv': 'HRV',
  'rhr': 'Resting heart rate',
  'resp': 'Breathing rate',
  'temp': 'Skin temperature',
};

/// A pipeline key the map does not cover is HUMANISED, never printed raw. The
/// glass-box emits whatever inputs the composite used, so a new one used to
/// surface on Home as `resp_rate_slope`.
String driverLabel(Object? key, [AppLocalizations? l]) {
  final k = key?.toString() ?? '';
  final known = switch (k) {
    'hrv' => l?.homeDriverHrv ?? driverLabels['hrv'],
    'rhr' => l?.homeDriverRhr ?? driverLabels['rhr'],
    'resp' => l?.homeDriverResp ?? driverLabels['resp'],
    'temp' => l?.homeDriverTemp ?? driverLabels['temp'],
    _ => null,
  };
  if (known != null) return known;
  if (k.isEmpty) return '';
  final words = k.replaceAll('_', ' ').trim();
  return words.isEmpty
      ? ''
      : '${words[0].toUpperCase()}${words.substring(1)}';
}

/// The three rings, and what each one does when its metric is not there.
///
/// A ring is a shape that always renders, and this data frequently is not
/// there: readiness exists on 71 % of days and needs four prior nights before
/// it exists at all. So the absent states ARE the design here rather than an
/// error branch bolted onto three pretty circles. Each ring has four:
///
///   * MEASURED — an arc, the number, and what the number is out of.
///   * CALIBRATING — a muted arc at nights-banked over nights-needed, with the
///     count under it. Visibly progress towards a real ring; an arc at zero
///     would read as a bad score, which is the lie this exists to avoid. It is
///     drawn only for a `need_baseline` note, the one absence that IS progress.
///   * MEASURED, UNSCALED — sleep with no computed need behind it. The number
///     is real and the fraction is not known, so the track draws empty and the
///     line under it says there is no target yet. Filling it against the
///     hardcoded 480 would be inventing the user's sleep need.
///   * ABSENT — the track alone, the absence in words where the number goes,
///     and the PIPELINE'S OWN reason on a row under the trio which is also the
///     door into the screen that can say more. Three [StatusCard]s is not a
///     home screen; a ring with nothing in it and no reason is worse than one.
///
/// Every ring opens something: recovery → [ReadinessDetail], strain →
/// [DayStrainDetail], sleep → [SleepDetail].
class RingTrio extends StatelessWidget {
  final HomeData d;

  /// Push the ring's own screen. Null in a gallery, where there is no navigator
  /// worth pushing onto.
  final void Function(HomeRingKind)? onOpen;

  const RingTrio({super.key, required this.d, this.onOpen});

  /// Whether ANY of the three has something to draw. When none do, the screen
  /// owes the user one written absence, not three empty circles.
  static bool has(HomeData d) =>
      HomeRingKind.values.any((k) => _ringOf(k, d, null).why == null);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    // The day in the order it happened: the night, what it gave back, what
    // the day has spent since. Recovery sits in the middle, larger, because
    // it is the number the morning is about.
    final rings = [for (final k in kHomeRingOrder) _ringOf(k, d, l)];
    final byKind = {for (final r in rings) r.kind: r};
    final gaps = rings.where((r) => r.why != null).toList();
    // THERE IS NO "THESE TWO ARE FROM SATURDAY" LINE ANY MORE, and there is
    // nothing left for one to explain. Recovery and sleep used to be served
    // from the last scored night whenever today's had not settled, and this
    // card carried one sentence naming that night. Read on a phone, the
    // sentence lost: a number inside a ring is today's, and a caption under
    // three rings does not undo it. The loader refuses the older night now
    // ([overnightMetric]), so a ring with no night behind it is a gap row with
    // the reason in it — same place every other absence on this screen goes.

    // A final recovery washes the card in its band's hue, faintly: the state
    // reads before the number does. Provisional, sleeping and absent stay
    // plain — there is no state to colour yet.
    final rv = d.readiness.value;
    final tint = rv != null && d.recoveryState != 'provisional' &&
            d.recoveryState != 'night_in_progress'
        ? readinessBand(rv, l).color
        : null;
    return Surface(
      elevation: 2,
      color: tintedCard(p, tint),
      child: Column(children: [
        if (bigText(c))
          // Past ~1.3× a 100 pt column cannot hold the word "Recovery" on one
          // line and there is nowhere for it to wrap to. The ring keeps its
          // size and the type gets the width instead.
          for (var i = 0; i < rings.length; i++) ...[
            if (i > 0) const SizedBox(height: S.x2),
            _RingRow(rings[i], onTap: _open(rings[i].kind)),
          ]
        else ...[
          // The morning's number, large, and how it moved since yesterday;
          // then the three as bars on one scale each, so they compare at a
          // glance. The recovery bar carries no second copy of the number.
          _HeroLine(byKind[HomeRingKind.recovery]!, d: d,
              onTap: _open(HomeRingKind.recovery)),
          const SizedBox(height: S.x4),
          for (final k in kHomeBarOrder) ...[
            if (k != kHomeBarOrder.first) const SizedBox(height: S.x3),
            _BarRow(byKind[k]!,
                showValue: k != HomeRingKind.recovery, onTap: _open(k)),
          ],
        ],
        for (final r in gaps) ...[
          const SizedBox(height: S.x2),
          Divider(color: p.line, height: 1),
          _GapRow(r, onTap: _open(r.kind)),
        ],
        if (recoveryUpdatedLine(d.readinessUpdate, l) case final note?) ...[
          const SizedBox(height: S.x2),
          Text(note, style: F.cap.copyWith(color: p.ink3)),
        ],
        if (d.readiness.value != null && d.drivers.isNotEmpty) ...[
          const SizedBox(height: S.x3),
          Divider(color: p.line, height: 1),
          const SizedBox(height: S.x3),
          Pressable(
            onTap: _open(HomeRingKind.recovery),
            // Top-aligned: at an accessibility size the driver list is three
            // lines and "Why?" was centred against the middle of them.
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l?.homeWhyLabel ?? 'Why?', style: F.cap.copyWith(color: p.ink3)),
              const SizedBox(width: S.x2),
              Expanded(
                child: Text(
                  d.drivers
                      .take(3)
                      .map((e) => driverLabel(e['label'], l))
                      .join(' · '),
                  style: F.cap.copyWith(color: p.ink2),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 15, color: p.ink3),
            ]),
            ),
          ],
        ],
      ),
    );
  }

  VoidCallback? _open(HomeRingKind k) {
    final f = onOpen;
    return f == null ? null : () => f(k);
  }
}

String _fixed1OrEmpty(Object? v) => v is num ? displayFixed(v, 1) : '';

/// "Updated 8:12 · 2 → 28" off a `todayHeadlineOf` `recovery_update`, or null.
String? recoveryUpdatedLine(Object? update, AppLocalizations? l) {
  if (update case {
    'from': final int from,
    'to': final int to,
    'at': final int at,
  }) {
    final time = formatClockOf(DateTime.fromMillisecondsSinceEpoch(at));
    return l?.homeRecoveryUpdated(time, from, to) ??
        'Updated $time · $from → $to';
  }
  return null;
}

/// The short line every screen showing today's recovery puts beside it when
/// it is not simply final: still asleep, finishing up, or changed since shown.
/// Read off one `todayHeadlineOf` result so Home, Readiness and Health agree.
String? recoveryStateLine(Map<String, dynamic> head, AppLocalizations? l) =>
    switch (head['recovery_state']) {
      'night_in_progress' => l?.homeRecoverySleeping ?? 'Sleeping…',
      'provisional' => l?.homeRecoveryFinishingUp ?? 'Finishing up',
      _ => recoveryUpdatedLine(head['recovery_update'], l),
    };

/// Which ring. The three the app can stand behind on a home screen: what the
/// night gave back, what the day has cost, and what the night was made of.
enum HomeRingKind { recovery, strain, sleep }

/// The bars under the headline, top to bottom.
const kHomeBarOrder = [
  HomeRingKind.recovery,
  HomeRingKind.sleep,
  HomeRingKind.strain,
];

/// The order the three are drawn in, left to right.
const kHomeRingOrder = [
  HomeRingKind.sleep,
  HomeRingKind.recovery,
  HomeRingKind.strain,
];

/// One ring's resolved state — the only place a metric becomes a shape.
class _RingState {
  final HomeRingKind kind;
  final String label, value, sub;
  final IconData icon;
  final Color color;

  /// What to sweep, 0…1 — null when there is nothing honest to sweep.
  final double? frac;

  /// The arc is calibration progress, not the metric, and is drawn muted.
  final bool calibrating;

  /// Nights banked / nights needed, set only while [calibrating] — the
  /// dashed ring divides itself into exactly [need] beads and fills [have]
  /// of them, rather than approximating that count from [frac].
  final int? have, need;

  /// The absence's reason, as the pipeline gave it. Non-null only when the
  /// ring is [absent].
  final String? why;

  const _RingState(
    this.kind,
    this.label,
    this.icon,
    this.color, {
    required this.value,
    this.sub = '',
    this.frac,
    this.calibrating = false,
    this.have,
    this.need,
    this.why,
    this.provisional = false,
    this.bandFrom,
    this.bandTo,
  });

  /// The day's target zone on this ring, 0…1 of the circle (strain only).
  final double? bandFrom, bandTo;

  /// A number that may still move (the night is still draining), drawn grey.
  final bool provisional;

  /// A number the ring is actually reporting. Calibration is progress, not a
  /// reading, so it is not one.
  bool get measured => why == null && !calibrating;

  Color arc(P p) => calibrating || provisional ? p.ink3 : p.on(color);
  Color ink(P p) => measured && !provisional ? p.on(color) : p.ink3;

  String get spoken => [
        label,
        measured ? value : value.toLowerCase(),
        if (sub.isNotEmpty) sub,
        ?why,
      ].join('. ');
}

_RingState _ringOf(HomeRingKind k, HomeData d, AppLocalizations? l) {
  switch (k) {
    case HomeRingKind.recovery:
      final v = d.readiness.value;
      final band = readinessBand(v, l);
      if (d.recoveryState == 'night_in_progress') {
        return _RingState(k, l?.homeRingRecovery ?? 'Recovery',
            LucideIcons.batteryCharging, C.green,
            value: l?.homeRecoverySleeping ?? 'Sleeping…',
            why: l?.homeRecoveryAfterWake ??
                'Recovery is scored after you wake.');
      }
      if (d.recoveryState == 'provisional' && v != null) {
        return _RingState(k, l?.homeRingRecovery ?? 'Recovery',
            LucideIcons.batteryCharging, band.color,
            value: '${v.round()}',
            sub: l?.homeRecoveryFinishingUp ?? 'Finishing up',
            frac: v / 100,
            provisional: true);
      }
      // Still building the baseline: the greyed estimate, said to be one.
      if (d.readinessCalibrating case final cal? when v == null) {
        final have = cal.nights + 1;
        return _RingState(k, l?.homeRingRecovery ?? 'Recovery',
            LucideIcons.batteryCharging, readinessBand(cal.value, l).color,
            value: '${cal.value.round()}',
            sub: l?.homeCalibratingProgress(have, cal.need) ??
                'Calibrating · $have of ${cal.need}',
            frac: cal.value / 100,
            provisional: true);
      }
      return v == null
          ? _gap(k, l?.homeRingRecovery ?? 'Recovery', LucideIcons.batteryCharging,
              C.green, d.readiness, l?.homeReadinessNotScored ?? 'Not scored', l,
              // The same shortfall sentence the Readiness detail screen's
              // banner shows, off the SAME stored diagnostic — _gap's own
              // whyFromNote(m.note) doesn't recognise the need_inputs:
              // convention this composite uses (only need_baseline:), so
              // without this it fell through to the generic "nothing
              // recorded says why" even with a real, known reason on hand.
              // metricName: 'recovery' — this ring is labelled "Recovery",
              // not "Readiness", and the sentence should say what the ring
              // itself says. The second translator covers the z-cap absence
              // shape readinessInputShortfallNote alone doesn't (PR #510).
              fallbackWhy: readinessInputShortfallNote(d.absentDiag,
                      metricName: 'recovery') ??
                  readinessUnstableBaselineNote(
                      d.absentDiag?['note']?.toString(),
                      metricName: 'recovery') ??
                  '')
          : _RingState(k, l?.homeRingRecovery ?? 'Recovery',
              LucideIcons.batteryCharging, band.color,
              value: '${v.round()}', sub: band.label, frac: v / 100);
    case HomeRingKind.strain:
      final v = d.strain.value;
      if (d.strainCalibrating case final cal? when v == null) {
        return _RingState(k, l?.homeRingStrain ?? 'Strain', LucideIcons.zap,
            C.purple,
            value: displayFixed(cal, 1),
            sub: l?.homeCalibrating ?? 'Calibrating',
            frac: cal / 21,
            provisional: true);
      }
      // 0–21 is the scale's own ceiling, not a target invented here.
      return v == null
          ? _gap(k, l?.homeRingStrain ?? 'Strain', LucideIcons.zap, C.purple,
              d.strain, l?.homeRingNoStrain ?? 'No strain', l, unit: 'days')
          : _RingState(k, l?.homeRingStrain ?? 'Strain', LucideIcons.zap, C.purple,
              value: displayFixed(v, 1),
              sub: l?.homeStrainOf21 ?? 'of 21',
              frac: v / 21,
              // The target the plan already states, drawn where the strain
              // is: a band on the same 0–21 dial. Only a real low/high pair
              // from the coach block; nothing is drawn otherwise.
              bandFrom: switch (d.strainTarget?['low']) {
                final num lo => lo / 21,
                _ => null,
              },
              bandTo: switch (d.strainTarget?['high']) {
                final num hi => hi / 21,
                _ => null,
              });
    case HomeRingKind.sleep:
      final v = d.sleepMin.value;
      final need = d.sleepNeedMin.value;
      return v == null
          ? _gap(k, l?.homeRingSleep ?? 'Sleep', LucideIcons.moon, C.blue,
              d.sleepMin, l?.homeRingNoSleep ?? 'No sleep', l,
              fallbackWhy: l?.homeSleepGapFallback ??
                  'No night long enough to score was recorded.')
          : _RingState(k, l?.homeRingSleep ?? 'Sleep', LucideIcons.moon, C.blue,
              value: hm(v),
              // No computed need means no denominator. The hardcoded 480 in
              // the sleep bundle is not this user's need and must never be
              // shown as one, so the ring stays open and says so.
              sub: need == null
                  ? (l?.homeSleepNoTarget ?? 'No target yet')
                  : (l?.homeOfSpan(hm(need)) ?? 'of ${hm(need)}'),
              frac: need == null || need <= 0 ? null : v / need);
  }
}

/// The absent half: calibrating when the note says the gate is a baseline
/// still filling, otherwise the absence and its reason.
_RingState _gap(HomeRingKind k, String label, IconData icon, Color color,
    Metric m, String word, AppLocalizations? l,
    {String unit = 'nights', String fallbackWhy = ''}) {
  final counts = baselineCountsFromNote(m.note);
  if (counts != null) {
    return _RingState(k, label, icon, color,
        value: l?.homeCalibrating ?? 'Learning your usual',
        sub: unit == 'days'
            ? (l?.homeCalibratingDays(counts.have, counts.need) ??
                '${counts.have} of ${counts.need} days')
            : (l?.homeCalibratingNights(counts.have, counts.need) ??
                '${counts.have} of ${counts.need} nights'),
        frac: (counts.have / counts.need).clamp(0.0, 1.0),
        calibrating: true,
        have: counts.have,
        need: counts.need);
  }
  return _RingState(k, label, icon, color,
      value: word,
      // THE PIPELINE'S REASON FIRST. A sentence written here by someone who
      // never saw the day is the fallback, and where there is neither the ring
      // says it does not know rather than guessing a cause.
      why: whyFromNote(m.note, unit: unit) ??
          (fallbackWhy.isNotEmpty
              ? fallbackWhy
              : (l?.homeGapNoReason ?? 'Nothing recorded says why this is missing.')));
}

/// The dial itself. An empty [frac] draws the track and nothing else — which is
/// exactly what [Ring] already does with a zero sweep.
class _Dial extends StatelessWidget {
  final _RingState r;
  final double stroke, icon;

  const _Dial(this.r, {required this.stroke, required this.icon});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    // The arc GLIDES to its value: from empty on first paint, and from the
    // old value to the new one when a sync lands, instead of jumping.
    // Reduced motion gets the value straight away.
    final target = r.frac ?? 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: motion(c, Motion.sweep),
      curve: Curves.easeOutCubic,
      builder: (c, v, _) => Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: Size.infinite,
          // Calibrating draws as discrete dashes filling in night by night;
          // a finished (or absent-but-not-calibrating) ring draws the
          // continuous arc, solid only once it is an actual measurement.
          painter: r.calibrating
              ? DashedRing(r.frac ?? 0, r.arc(p), p.track,
                  stroke: stroke, segments: r.need ?? 24)
              : Ring(Motion.enabled(c) ? v : target, r.arc(p), p.track,
                  stroke: stroke,
                  solid: r.measured,
                  bandFrom: r.bandFrom,
                  bandTo: r.bandTo),
        ),
        Icon(r.icon, size: icon, color: r.ink(p)),
      ]),
    );
  }
}

/// The default: three across, the number under the ring rather than inside it.
/// Inside is where a duration overflows its own circle at the first
/// accessibility step, and nothing about "7h 45m" gets shorter.
/// The accessibility layout: ring left, type in the width it needs.
class _RingRow extends StatelessWidget {
  final _RingState r;
  final VoidCallback? onTap;

  const _RingRow(this.r, {this.onTap});

  @override
  Widget build(BuildContext c) => Pressable(
        onTap: onTap,
        semanticLabel: r.spoken,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: S.x2),
          child: Row(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: _Dial(r, stroke: 5, icon: 15),
            ),
            const SizedBox(width: S.x3),
            Expanded(child: _RingText(r, align: TextAlign.start)),
          ]),
        ),
      );
}

class _RingText extends StatelessWidget {
  final _RingState r;
  final TextAlign align;

  const _RingText(this.r, {required this.align});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final cross = align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(crossAxisAlignment: cross, children: [
      Text(r.label.toUpperCase(),
          style: F.over.copyWith(color: p.ink3), textAlign: align),
        const SizedBox(height: S.x1),
        // Absent reads as words, never as a dash and never as a zero — so it
        // takes the sentence weight rather than the numeral one.
        Text(
            presentationText(AppLocalizations.of(c), r.value),
            style: r.measured
                ? F.n24.copyWith(color: r.provisional ? p.ink3 : p.ink)
                : F.body.copyWith(color: p.ink2),
            textAlign: align,
          ),
        if (r.sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            presentationText(AppLocalizations.of(c), r.sub),
            style: F.cap.copyWith(color: p.ink3),
            textAlign: align,
          ),
        ],
      ],
    );
  }
}

/// WHY a ring is empty, on the row that also opens the screen which can say
/// more about it. The three parts of a [StatusCard] — what is missing, why,
/// what to do about it — at the size a home screen can afford to spend on an
/// absence.
class _GapRow extends StatelessWidget {
  final _RingState r;
  final VoidCallback? onTap;

  const _GapRow(this.r, {this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: S.x2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(r.icon, size: 15, color: p.ink3),
            const SizedBox(width: S.x2),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                TextSpan(
                    text: '${r.label} · ',
                    style: F.cap.copyWith(
                        color: p.ink2, fontWeight: FontWeight.w600)),
                    TextSpan(
                      text: presentationText(
                        AppLocalizations.of(c),
                        r.why ?? '',
                      ),
                      style: F.cap.copyWith(color: p.ink3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: S.x2),
            Icon(LucideIcons.chevronRight, size: 15, color: p.ink3),
          ],
        ),
      ),
    );
  }
}

/// The headline: the recovery figure as large as the screen allows, coloured
/// by its band, and beside it how it moved since yesterday — or, while there
/// is no figure, the words the ring state already has (sleeping, calibrating,
/// not scored).
class _HeroLine extends StatelessWidget {
  final _RingState r;
  final HomeData d;
  final VoidCallback? onTap;

  const _HeroLine(this.r, {required this.d, this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final v = d.readiness.value;
    final finalScore =
        r.measured && !r.provisional && v != null;
    final y = d.readinessYesterday;
    final delta = finalScore && y != null ? (v - y).round() : null;
    final best = finalScore &&
        d.readinessWeekMax != null &&
        v >= d.readinessWeekMax!;
    final numberish = r.measured;
    return Pressable(
      onTap: onTap,
      semanticLabel: r.spoken,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.label.toUpperCase(), style: F.over.copyWith(color: p.ink3)),
            const SizedBox(height: S.x1),
            AnimatedSwitcher(
              duration: motion(c, Motion.slow),
              child: numberish
                  ? Row(
                      key: ValueKey(r.value),
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              presentationText(l, r.value),
                              style: F.n72.copyWith(
                                  color: r.provisional ? p.ink3 : r.ink(p)),
                            ),
                          ),
                        ),
                        if (r.kind == HomeRingKind.recovery)
                          Text('%', style: F.head.copyWith(color: p.ink3)),
                      ],
                    )
                  : Text(presentationText(l, r.value),
                      key: ValueKey(r.value),
                      style: F.t2.copyWith(color: p.ink2)),
            ),
          ]),
        ),
        const SizedBox(width: S.x3),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(bottom: S.x2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (delta != null && delta != 0)
                Text(
                  delta > 0
                      ? (l?.homeVsYesterdayUp(delta) ?? '▲ $delta vs yesterday')
                      : (l?.homeVsYesterdayDown(-delta) ??
                          '▼ ${-delta} vs yesterday'),
                  textAlign: TextAlign.right,
                  style: F.body.copyWith(
                      color: delta > 0 ? p.on(C.green) : p.on(C.orange),
                      fontWeight: FontWeight.w700),
                ),
              if (best)
                Text((l?.homeBestThisWeek ?? 'Best this week').toUpperCase(),
                    textAlign: TextAlign.right,
                    style: F.over.copyWith(color: p.ink3))
              else if (r.sub.isNotEmpty)
                Text(presentationText(l, r.sub),
                    textAlign: TextAlign.right,
                    style: F.cap.copyWith(color: p.ink3)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// One of the three as a bar: name (and its sub-line), a bar filled to the
/// value on the scale the ring used, and the value. The strain bar carries
/// the day's target zone. Fill glides to a new value instead of jumping.
class _BarRow extends StatelessWidget {
  final _RingState r;
  final bool showValue;
  final VoidCallback? onTap;

  const _BarRow(this.r, {required this.showValue, this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final target = (r.frac ?? 0).clamp(0.0, 1.0).toDouble();
    return Pressable(
      onTap: onTap,
      semanticLabel: r.spoken,
      child: Row(children: [
        SizedBox(
          width: 104,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: F.cap.copyWith(color: p.ink2, fontWeight: FontWeight.w600)),
            if (showValue && r.sub.isNotEmpty)
              Text(presentationText(l, r.sub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: F.over.copyWith(color: p.ink3)),
          ]),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target),
            duration: motion(c, Motion.sweep),
            curve: Curves.easeOutCubic,
            builder: (c, v, _) => CustomPaint(
              size: const Size.fromHeight(10),
              painter: HomeBarPainter(
                Motion.enabled(c) ? v : target,
                r.arc(p),
                p.track,
                faint: r.calibrating || r.provisional,
                bandFrom: r.bandFrom,
                bandTo: r.bandTo,
              ),
            ),
          ),
        ),
        if (showValue) ...[
          const SizedBox(width: S.x3),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, maxWidth: 112),
            child: AnimatedSwitcher(
              duration: motion(c, Motion.slow),
              child: Text(
                presentationText(l, r.value),
                key: ValueKey(r.value),
                textAlign: TextAlign.right,
                maxLines: 2,
                style: r.measured
                    ? F.head.copyWith(
                        color: r.provisional || r.calibrating ? p.ink3 : p.ink)
                    : F.cap.copyWith(color: p.ink2),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// A rounded bar: track, an optional target zone (0…1) drawn as a lighter
/// band with edges, and the fill to [v] (0…1). [faint] draws the fill at half
/// strength — a value that is still provisional or calibrating.
class HomeBarPainter extends CustomPainter {
  final double v;
  final Color color, track;
  final bool faint;
  final double? bandFrom, bandTo;

  HomeBarPainter(this.v, this.color, this.track,
      {this.faint = false, this.bandFrom, this.bandTo});

  @override
  void paint(Canvas cv, Size s) {
    final h = s.height;
    final r = Radius.circular(h / 2);
    cv.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, r),
        Paint()..color = track);
    final bf = bandFrom, bt = bandTo;
    if (bf != null && bt != null && bt > bf) {
      final x0 = s.width * bf.clamp(0.0, 1.0), x1 = s.width * bt.clamp(0.0, 1.0);
      cv.drawRect(Rect.fromLTRB(x0, 0, x1, h),
          Paint()..color = color.withValues(alpha: .22));
      final edge = Paint()
        ..color = color.withValues(alpha: .7)
        ..strokeWidth = 1;
      cv.drawLine(Offset(x0, 0), Offset(x0, h), edge);
      cv.drawLine(Offset(x1, 0), Offset(x1, h), edge);
    }
    final w = s.width * v.clamp(0.0, 1.0);
    if (w > 0) {
      cv.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w < h ? h : w, h), r),
          Paint()..color = faint ? color.withValues(alpha: .5) : color);
    }
  }

  @override
  bool shouldRepaint(HomeBarPainter o) =>
      o.v != v ||
      o.color != color ||
      o.track != track ||
      o.faint != faint ||
      o.bandFrom != bandFrom ||
      o.bandTo != bandTo;
}

/// The coach's morning read, in the open: the briefing's one-liner as the
/// headline, the first lines of its breakdown, and the inputs it was given as
/// chips — so a sentence is never shown without what it was written from.
/// Written once a morning, after the night is final (see
/// AppState._maybeGenerateBriefing); before that, or without a model, it says
/// so in one line.
class _CoachCard extends StatelessWidget {
  final Briefing? briefing;
  final VoidCallback onOpen;

  const _CoachCard({required this.briefing, required this.onOpen});

  /// Briefings whose headline has already typed itself out this session.
  static final Set<String> _typed = {};

  static String _plain(String md) => md
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'^\s*([-*•]|\d+\.)\s*'), '').trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .take(2)
      .join(' ')
      .replaceAll('**', '')
      .replaceAll('__', '');

  static List<String> _chips(Map<String, dynamic> inputs, AppLocalizations? l) {
    String? n(String k, {int dp = 0}) {
      final v = inputs[k];
      return v is num ? v.toStringAsFixed(dp) : null;
    }
    return [
      if (n('readiness') case final v?) '${l?.homeRingRecovery ?? 'Recovery'} $v',
      if (n('hrv_rmssd') case final v?) '${l?.homeDriverHrv ?? 'HRV'} $v ms',
      if (n('resting_hr') case final v?) '${l?.homeDriverRhr ?? 'Resting heart rate'} $v',
      if (inputs['sleep_min'] is num) hm(inputs['sleep_min'] as num),
      if (inputs['last_strength_workout'] is String)
        l?.homeCoachChipTraining ?? 'Training log',
    ];
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final b = briefing;
    bool configured;
    String model;
    try {
      final cfg = c.watch<CoachConfig>();
      configured = cfg.configured;
      model = cfg.model;
    } catch (_) {
      configured = false;
      model = '';
    }
    final head = Row(children: [
      Icon(LucideIcons.sparkles, size: 14, color: p.on(C.blue)),
      const SizedBox(width: S.x2),
      Expanded(
        child: Text((l?.homeCoachTitle ?? 'Coach · today').toUpperCase(),
            style: F.over.copyWith(color: p.on(C.blue))),
      ),
      if (b != null)
        Text(
            [
              if (model.isNotEmpty) model,
              formatClockOf(
                  DateTime.fromMillisecondsSinceEpoch(b.generatedAtMs)),
            ].join(' · '),
            style: F.over.copyWith(color: p.ink3)),
    ]);
    if (b == null) {
      return Surface(
        onTap: onOpen,
        color: tintedCard(p, C.blue),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head,
          const SizedBox(height: S.x2),
          Text(
            configured
                ? (l?.homeCoachPending ??
                    'Your morning read is written once your night is final.')
                : (l?.homeCoachConnect ??
                    'Connect a model to get a short read of your day every morning.'),
            style: F.body.copyWith(color: p.ink2),
          ),
        ]),
      );
    }
    final key = '${b.day}:${b.period.name}:${b.generatedAtMs}';
    final animate = Motion.enabled(c) && !_typed.contains(key);
    _typed.add(key);
    final title = b.oneLiner == 'Nothing stood out tonight.'
        ? uiText(c, b.oneLiner)
        : b.oneLiner;
    final body = _plain(b.breakdownMd);
    final chips = _chips(b.inputs, l);
    return Surface(
      onTap: onOpen,
      color: tintedCard(p, C.blue),
      semanticLabel: '$title. $body',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        head,
        const SizedBox(height: S.x2),
        // Types itself out the first time this briefing is shown.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: animate ? 0 : 1, end: 1),
          duration: motion(c, Motion.sweep),
          builder: (c, t, _) => Text(
            title.substring(0, (title.length * t).round().clamp(0, title.length)),
            style: F.head.copyWith(color: p.ink),
          ),
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: S.x2),
          Text(body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: F.cap.copyWith(color: p.ink2)),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: S.x3),
          Wrap(spacing: S.x2, runSpacing: S.x2, children: [
            for (final ch in chips)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: S.x2, vertical: 3),
                decoration: BoxDecoration(
                    color: p.track,
                    borderRadius: R.rPill,
                    border: Border.all(color: p.line)),
                child: Text(ch, style: F.over.copyWith(color: p.ink2)),
              ),
          ]),
        ],
      ]),
    );
  }
}

/// The day as it happened, on one strip: the night as a band, each session
/// as a box, and the heart-rate curve over all of it. Read from the same
/// bundle the hour-by-hour screen uses; nothing is drawn where nothing was
/// recorded, and the strip is absent when the day has no curve at all.
class _DayStrip extends StatefulWidget {
  final String day;
  final HomeData data;
  final VoidCallback onOpen;

  const _DayStrip(
      {super.key, required this.day, required this.data, required this.onOpen});

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  Future<Map<String, dynamic>>? _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _f ??= _load();
  }

  @override
  void didUpdateWidget(_DayStrip old) {
    super.didUpdateWidget(old);
    // A reload hands a new HomeData: the day may have moved on.
    if (!identical(old.data, widget.data)) _f = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      final repo = context.read<AppState>().repo;
      if (repo == null) return const {};
      return await repo.getDayTimeline(widget.day);
    } catch (_) {
      return const {};
    }
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (c, snap) {
          final m = snap.data;
          final hr = [
            for (final e in (m?['hr'] as List?) ?? const [])
              if (e is Map && e['t'] is num && e['v'] is num)
                (t: (e['t'] as num).toInt(), v: (e['v'] as num).toDouble()),
          ];
          final start = (m?['day_start'] as num?)?.toInt();
          final p = P.of(c);
          final l = AppLocalizations.of(c);
          // While it loads the card keeps its place, so nothing below it
          // jumps when the curve arrives.
          if (snap.connectionState != ConnectionState.done) {
            return Surface(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    (l?.homeDayStripTitle ?? 'Your day, hour by hour')
                        .toUpperCase(),
                    style: F.over.copyWith(color: p.ink3)),
                const SizedBox(height: S.x3),
                Container(
                    height: 96,
                    decoration:
                        BoxDecoration(color: p.track, borderRadius: R.rSm)),
                const SizedBox(height: S.x6),
              ]),
            );
          }
          if (hr.length < 2 || start == null) return const SizedBox.shrink();
          final d0 = DateTime.fromMillisecondsSinceEpoch(start * 1000);
          final end = DateTime(d0.year, d0.month, d0.day + 1)
                  .millisecondsSinceEpoch ~/
              1000;
          List<(int, int)> spans(Object? list, String a, String b) => [
                for (final e in (list as List?) ?? const [])
                  if (e is Map && e[a] is num && e[b] is num)
                    ((e[a] as num).toInt(), (e[b] as num).toInt()),
              ];
          final sleep = [
            ...spans(m?['sleep'], 'onset_ts', 'wake_ts'),
            ...spans(m?['naps'], 'onset_ts', 'wake_ts'),
          ];
          final sessions = spans(m?['sessions'], 'start_ts', 'end_ts');
          return Surface(
            onTap: widget.onOpen,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                      (l?.homeDayStripTitle ?? 'Your day, hour by hour')
                          .toUpperCase(),
                      style: F.over.copyWith(color: p.ink3)),
                ),
                Icon(LucideIcons.chevronRight, size: 15, color: p.ink3),
              ]),
              const SizedBox(height: S.x3),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: motion(c, Motion.sweep),
                curve: Curves.easeOutCubic,
                builder: (c, t, _) => CustomPaint(
                  size: const Size.fromHeight(96),
                  painter: DayStripPainter(
                    start: start,
                    end: end,
                    hr: hr,
                    sleep: sleep,
                    sessions: sessions,
                    reveal: animate(c, t),
                    line: p.on(C.red),
                    sleepColor: p.on(C.blue),
                    sessionColor: p.on(C.purple),
                    grid: p.line,
                  ),
                ),
              ),
              const SizedBox(height: S.x1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final h in const [0, 6, 12, 18, 24])
                    Text(h.toString().padLeft(2, '0'),
                        style: F.over.copyWith(color: p.ink3)),
                ],
              ),
              const SizedBox(height: S.x2),
              Wrap(spacing: S.x3, runSpacing: S.x1, children: [
                if (sleep.isNotEmpty)
                  _legend(p, p.on(C.blue), l?.homeRingSleep ?? 'Sleep'),
                _legend(p, p.on(C.red), l?.homeHeartRate ?? 'Heart rate'),
                if (sessions.isNotEmpty)
                  _legend(p, p.on(C.purple),
                      l?.homeActivitiesTitle ?? 'Activities'),
              ]),
            ]),
          );
        },
      );

  static Widget _legend(P p, Color col, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: col, borderRadius: R.rSm)),
          const SizedBox(width: S.x1),
          Text(label, style: F.over.copyWith(color: p.ink2)),
        ],
      );
}

/// The day strip's drawing: x is the local day [start, end) in epoch seconds,
/// y the heart rate between the day's own low and high. [reveal] (0…1) draws
/// the curve left to right.
class DayStripPainter extends CustomPainter {
  final int start, end;
  final List<({int t, double v})> hr;
  final List<(int, int)> sleep, sessions;
  final double reveal;
  final Color line, sleepColor, sessionColor, grid;

  DayStripPainter({
    required this.start,
    required this.end,
    required this.hr,
    required this.sleep,
    required this.sessions,
    required this.reveal,
    required this.line,
    required this.sleepColor,
    required this.sessionColor,
    required this.grid,
  });

  @override
  void paint(Canvas cv, Size s) {
    final span = (end - start).toDouble();
    if (span <= 0 || hr.length < 2) return;
    double x(int t) => s.width * ((t - start) / span).clamp(0.0, 1.0);
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in const [.25, .5, .75]) {
      cv.drawLine(Offset(0, s.height * f), Offset(s.width, s.height * f), g);
    }
    // The night: a band along the bottom.
    for (final (a, b) in sleep) {
      cv.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(x(a), s.height - 10, x(b), s.height),
              const Radius.circular(3)),
          Paint()..color = sleepColor.withValues(alpha: .75));
    }
    // Sessions: a tinted box the height of the strip.
    for (final (a, b) in sessions) {
      final r = Rect.fromLTRB(x(a), 0, x(b) < x(a) + 3 ? x(a) + 3 : x(b), s.height);
      cv.drawRect(r, Paint()..color = sessionColor.withValues(alpha: .14));
      cv.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = sessionColor.withValues(alpha: .6));
    }
    var lo = hr.first.v, hi = hr.first.v;
    for (final p in hr) {
      if (p.v < lo) lo = p.v;
      if (p.v > hi) hi = p.v;
    }
    final range = (hi - lo) < 10 ? 10 : hi - lo;
    final top = 6.0, bottom = s.height - 14;
    double y(double v) => bottom - (bottom - top) * ((v - lo) / range);
    final cut = start + (span * reveal).round();
    final path = Path();
    var started = false;
    int? prevT;
    for (final p in hr) {
      if (p.t > cut) break;
      // A gap of more than ten minutes is a gap: the line lifts, it does not
      // draw a straight bridge across time nothing was recorded.
      final gap = prevT != null && p.t - prevT > 600;
      if (!started || gap) {
        path.moveTo(x(p.t), y(p.v));
        started = true;
      } else {
        path.lineTo(x(p.t), y(p.v));
      }
      prevT = p.t;
    }
    cv.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = line);
  }

  @override
  bool shouldRepaint(DayStripPainter o) =>
      o.reveal != reveal ||
      !identical(o.hr, hr) ||
      o.line != line ||
      o.grid != grid;
}

/// What was lifted: the last strength session's top sets (and records), the
/// week's working sets per muscle group, and the group rested longest. Only
/// with a strength log; nothing is shown before the first lifted set.
class _TrainingCard extends StatefulWidget {
  final HomeData data;
  final num? readiness;
  final bool final_;

  const _TrainingCard(
      {required this.data, required this.readiness, required this.final_});

  @override
  State<_TrainingCard> createState() => _TrainingCardState();
}

class _TrainingCardState extends State<_TrainingCard> {
  Future<StrengthSummary?>? _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  @override
  void didUpdateWidget(_TrainingCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.data, widget.data)) _f = _load();
  }

  Future<StrengthSummary?> _load() async {
    try {
      return await loadStrengthSummary();
    } catch (_) {
      return null;
    }
  }

  static String _group(MuscleGroup g, AppLocalizations? l) => switch (g) {
        MuscleGroup.chest => l?.muscleChest ?? 'Chest',
        MuscleGroup.back => l?.muscleBack ?? 'Back',
        MuscleGroup.legs => l?.muscleLegs ?? 'Legs',
        MuscleGroup.shoulders => l?.muscleShoulders ?? 'Shoulders',
        MuscleGroup.arms => l?.muscleArms ?? 'Arms',
        MuscleGroup.core => l?.muscleCore ?? 'Core',
      };

  /// "Today 18:10", "Yesterday 18:10", "Mon 18:10" within the week, else
  /// "3 Nov 18:10" — the block shows the last session of the past 7 days, so
  /// a bare clock would not say which day it was.
  static String _whenLifted(BuildContext c, DateTime at) {
    final l = AppLocalizations.of(c);
    final code = Localizations.localeOf(c).languageCode;
    final days = calendarDaysBetween(at, DateTime.now());
    String cap(String x) =>
        x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}';
    final day = switch (days) {
      0 => l?.logWorkoutToday ?? 'Today',
      1 => l?.logWorkoutYesterday ?? 'Yesterday',
      < 7 => cap(localizedDate(at, code, pattern: 'EEE')),
      _ => localizedDate(at, code, pattern: 'd MMM'),
    };
    return '$day ${formatClockOf(at)}';
  }

  static String _kg(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : displayFixed(kg, 1);

  @override
  Widget build(BuildContext c) => FutureBuilder<StrengthSummary?>(
        future: _f,
        builder: (c, snap) {
          final st = snap.data;
          if (st == null) return const SizedBox.shrink();
          final p = P.of(c);
          final l = AppLocalizations.of(c);
          final last = st.last;
          final week = st.weekSets.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final most = week.isEmpty ? 1 : week.first.value;
          final rested = mostRestedGroup(st.daysSince);
          final rv = widget.final_ ? widget.readiness : null;
          final clause = rv == null
              ? null
              : rv >= 67
                  ? (l?.homeTrainingGreen ?? 'Your recovery is up for it.')
                  : rv >= 34
                      ? (l?.homeTrainingYellow ??
                          'Keep the intensity moderate today.')
                      : (l?.homeTrainingRed ??
                          'Today, something light or rest is the better call.');
          return Padding(
            padding: const EdgeInsets.only(top: S.x3),
            child: Surface(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (last != null) ...[
                  Row(children: [
                    Expanded(
                      child: Text(
                          (last.source == 'hevy'
                                  ? (l?.homeTrainingLastHevy ??
                                      'Last workout · Hevy')
                                  : (l?.homeTrainingLast ?? 'Last workout'))
                              .toUpperCase(),
                          style: F.over.copyWith(color: p.ink3)),
                    ),
                    Text(
                        [
                          _whenLifted(c, DateTime.fromMillisecondsSinceEpoch(
                              last.startTs * 1000)),
                          if (last.durationMin != null) hm(last.durationMin!),
                          if (last.strain != null)
                            '${l?.homeRingStrain ?? 'Strain'} ${displayFixed(last.strain!, 1)}',
                        ].join(' · '),
                        style: F.over.copyWith(color: p.ink3)),
                  ]),
                  const SizedBox(height: S.x2),
                  for (final lift in last.lifts.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(
                          child: Text(lift.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: F.cap.copyWith(color: p.ink2)),
                        ),
                        Text(
                          lift.loadKg != null && lift.loadKg! > 0
                              ? '${lift.sets} × ${lift.reps ?? '–'} · ${_kg(lift.loadKg!)} kg'
                              : '${lift.sets} × ${lift.reps ?? '–'}',
                          style: F.cap.copyWith(
                              color: p.ink, fontWeight: FontWeight.w600),
                        ),
                        if (lift.pr) ...[
                          const SizedBox(width: S.x2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                                color: p.fill(C.yellow), borderRadius: R.rSm),
                            child: Text(l?.homeTrainingPr ?? 'PR',
                                style: F.over.copyWith(color: p.inkOnFill)),
                          ),
                        ],
                      ]),
                    ),
                ],
                if (week.isNotEmpty) ...[
                  if (last != null) ...[
                    const SizedBox(height: S.x3),
                    Divider(color: p.line, height: 1),
                    const SizedBox(height: S.x3),
                  ],
                  Text(
                      (l?.homeTrainingWeek ?? 'Working sets this week')
                          .toUpperCase(),
                      style: F.over.copyWith(color: p.ink3)),
                  const SizedBox(height: S.x2),
                  for (final e in week)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(
                          width: 84,
                          child: Text(_group(e.key, l),
                              style: F.cap.copyWith(color: p.ink2)),
                        ),
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: e.value / most),
                            duration: motion(c, Motion.sweep),
                            curve: Curves.easeOutCubic,
                            builder: (c, v, _) => CustomPaint(
                              size: const Size.fromHeight(7),
                              painter: HomeBarPainter(
                                  Motion.enabled(c) ? v : e.value / most,
                                  rested?.group == e.key
                                      ? p.on(C.yellow)
                                      : p.on(C.blue),
                                  p.track),
                            ),
                          ),
                        ),
                        const SizedBox(width: S.x3),
                        SizedBox(
                          width: 64,
                          child: Text(
                              l?.homeTrainingSets(e.value) ?? '${e.value} sets',
                              textAlign: TextAlign.right,
                              style: F.cap.copyWith(color: p.ink)),
                        ),
                      ]),
                    ),
                ],
                if (rested != null) ...[
                  const SizedBox(height: S.x3),
                  Divider(color: p.line, height: 1),
                  const SizedBox(height: S.x3),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(LucideIcons.dumbbell, size: 16, color: p.on(C.green)),
                    const SizedBox(width: S.x2),
                    Expanded(
                      child: Text(
                        [
                          l?.homeTrainingNext(
                                  _group(rested.group, l), rested.days) ??
                              'Next up: ${_group(rested.group, l)}, '
                                  '${rested.days} days since you last trained it.',
                          ?clause,
                        ].join(' '),
                        style: F.cap.copyWith(color: p.ink),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
          );
        },
      );
}

/// Last night's three vitals in one row under the rings: HRV, resting heart
/// rate, breathing rate — each with an arrow against the user's own usual and
/// the usual itself underneath, so the arrow is never a claim without its
/// reference. Only readings that exist are drawn; nothing renders when none
/// does (the glance below still owns the written absence of resting HR).
class _VitalsStrip extends StatelessWidget {
  final HomeData d;
  final void Function(String key) onOpen;

  const _VitalsStrip(this.d, {required this.onOpen});

  static bool has(HomeData d) =>
      !d.hrv.isEmpty || !d.rhr.isEmpty || !d.resp.isEmpty;

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final tiles = <Widget>[
      if (d.hrv.value case final v?)
        _Vital(
          label: l?.homeDriverHrv ?? 'HRV',
          value: '${v.round()}',
          unit: 'ms',
          usual: d.hrvUsual?.round().toString(),
          trend: _trend(v.toDouble(), d.hrvUsual, (d.hrvUsual ?? 0) * .05),
          good: _Good.up,
          onTap: () => onOpen('hrv'),
        ),
      if (d.rhr.value case final v?)
        _Vital(
          label: l?.homeDriverRhr ?? 'Resting heart rate',
          value: '${v.round()}',
          unit: 'bpm',
          usual: d.rhrUsual?.round().toString(),
          trend: _trend(v.toDouble(), d.rhrUsual, 2),
          good: _Good.down,
          onTap: () => onOpen('resting_hr'),
        ),
      if (d.resp.value case final v?)
        _Vital(
          label: l?.homeDriverResp ?? 'Breathing rate',
          value: displayFixed(v, 1),
          unit: 'br/min',
          usual: d.respUsual == null ? null : displayFixed(d.respUsual!, 1),
          trend: _trend(v.toDouble(), d.respUsual, .5),
          good: _Good.neither,
          onTap: () => onOpen('resp_rate'),
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: S.x2),
          Expanded(child: tiles[i]),
        ],
      ]),
    );
  }
}

enum _Good { up, down, neither }

/// +1 above the usual by more than [tol], -1 below it, 0 within it; null with
/// no usual to compare against.
int? _trend(double v, double? usual, double tol) {
  if (usual == null) return null;
  if (v - usual > tol) return 1;
  if (usual - v > tol) return -1;
  return 0;
}

class _Vital extends StatelessWidget {
  final String label, value, unit;
  final String? usual;
  final int? trend;
  final _Good good;
  final VoidCallback onTap;

  const _Vital({
    required this.label,
    required this.value,
    required this.unit,
    required this.usual,
    required this.trend,
    required this.good,
    required this.onTap,
  });

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final t = trend;
    final favourable = t == null || t == 0 || good == _Good.neither
        ? null
        : (t > 0) == (good == _Good.up);
    final arrowColor = switch (favourable) {
      true => p.on(C.green),
      false => p.on(C.orange),
      null => p.ink3,
    };
    final u = presentationText(l, unit);
    final usualText = usual == null
        ? null
        : (l?.homeVitalUsual('$usual $u') ?? 'Usual $usual $u');
    return Surface(
      onTap: onTap,
      pad: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x3),
      semanticLabel: [label, '$value $u', ?usualText].join('. '),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: F.over.copyWith(color: p.ink3)),
        const SizedBox(height: S.x1),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 3,
          children: [
            Text(value, style: F.n24.copyWith(color: p.ink)),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(u, style: F.cap.copyWith(color: p.ink3)),
            ),
            if (t != null && t != 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                    t > 0 ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                    size: 14,
                    color: arrowColor),
              ),
          ],
        ),
        if (usualText != null) ...[
          const SizedBox(height: 2),
          Text(usualText, style: F.cap.copyWith(color: p.ink3)),
        ],
      ]),
    );
  }
}

/// The day's sessions as a list, the way the day went: what, when, for how
/// long, and the strain it cost when the session has one. One card, rows
/// divided; any row opens the day's hour-by-hour view, where the session
/// sits on the timeline.
class _Activities extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final VoidCallback onOpen;

  const _Activities(this.sessions, {required this.onOpen});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    String clockAt(num ts) =>
        formatClockOf(DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000));
    return Surface(
      pad: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x1),
      child: Column(children: [
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) Divider(color: p.line, height: 1),
          Builder(builder: (c) {
            final s = sessions[i];
            final type = s['type']?.toString() ?? 'other';
            final a = activityByName(type);
            final name = a?.displayName(c) ?? catalogueName(l, type);
            final color = a?.color ?? C.purple;
            final mins = s['duration_min'] as num?;
            final strain = s['strain'] as num?;
            final when = [
              '${clockAt(s['start_ts'] as num)}–${clockAt(s['end_ts'] as num)}',
              if (mins != null && mins > 0) hm(mins),
            ].join(' · ');
            return Pressable(
              onTap: onOpen,
              semanticLabel: [
                name,
                when,
                if (strain != null) '${l?.homeRingStrain ?? 'Strain'} ${displayFixed(strain, 1)}',
              ].join('. '),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: S.x3),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .14),
                      borderRadius: R.rPill,
                    ),
                    child: Icon(a?.icon ?? LucideIcons.activity,
                        size: 18, color: p.on(color)),
                  ),
                  const SizedBox(width: S.x3),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: F.body.copyWith(
                                  color: p.ink, fontWeight: FontWeight.w600)),
                          Text(when, style: F.cap.copyWith(color: p.ink3)),
                        ]),
                  ),
                  if (strain != null) ...[
                    const SizedBox(width: S.x2),
                    Icon(LucideIcons.zap, size: 14, color: p.on(C.purple)),
                    const SizedBox(width: 2),
                    Text(displayFixed(strain, 1),
                        style: F.n17.copyWith(color: p.ink)),
                  ],
                  const SizedBox(width: S.x1),
                  Icon(LucideIcons.chevronRight, size: 15, color: p.ink3),
                ]),
              ),
            );
          }),
        ],
      ]),
    );
  }
}

// ═══════════════════ the screen ═══════════════════

/// Mean of the 28 measured days before [day] for [key], or null when there
/// are fewer than [kUsualMinDays] of them (or no database to ask).
Future<double?> usualBefore(String key, String? day) async {
  if (day == null) return null;
  try {
    final vs = await LocalDb.trailingSeriesValues(key, 28, before: day);
    if (vs.length < kUsualMinDays) return null;
    return vs.reduce((a, b) => a + b) / vs.length;
  } catch (_) {
    return null;
  }
}

/// The final recovery stored for the calendar day before [day], or null.
Future<double?> readinessOnDayBefore(String? day) async {
  final d = day == null ? null : DateTime.tryParse(day);
  if (d == null) return null;
  try {
    return await LocalDb.metricValueOn(
        dayLabelOf(DateTime(d.year, d.month, d.day - 1)), 'readiness');
  } catch (_) {
    return null;
  }
}

/// The best recovery of the six stored days before [day], or null with fewer
/// than three of them (a "best this week" out of one day says nothing).
Future<double?> readinessWeekMaxBefore(String? day) async {
  if (day == null) return null;
  try {
    final vs = await LocalDb.trailingSeriesValues('readiness', 6, before: day);
    return vs.length < 3 ? null : vs.reduce((a, b) => a > b ? a : b);
  } catch (_) {
    return null;
  }
}

/// The finished sessions that started on [day] (a LOCAL day label), oldest
/// first. The day runs local midnight to the next local midnight, built from
/// the calendar rather than by adding 86 400 s, so a DST day is its real
/// length. Empty on any failure: a list of workouts is not worth a broken Home.
Future<List<Map<String, dynamic>>> sessionsOfDay(
    LocalRepository repo, String? day) async {
  final start = day == null ? null : DateTime.tryParse(day);
  if (start == null) return const [];
  final end = DateTime(start.year, start.month, start.day + 1);
  try {
    final rows = await repo.getSessions(
        from: start.millisecondsSinceEpoch ~/ 1000,
        to: end.millisecondsSinceEpoch ~/ 1000 - 1,
        includeDetected: false);
    return [
      for (final r in rows)
        if (r['start_ts'] is num &&
            r['end_ts'] is num &&
            (r['start_ts'] as num) >= start.millisecondsSinceEpoch ~/ 1000)
          r,
    ]..sort((a, b) => (a['start_ts'] as num).compareTo(b['start_ts'] as num));
  } catch (_) {
    return const [];
  }
}

class HomeData {
  final String? name;
  final String? dayId;
  final Metric readiness;
  final List<Map<String, dynamic>> drivers;
  final Metric sleepMin, rhr, steps, calories, caloriesTotal;

  /// The day's 0–21 strain, read from the same `getToday` bundle the Workout
  /// tab reads. Nothing on this screen computes it.
  final Metric strain;

  final int stepGoal;
  final Metric sleepNeedMin;
  final Metric bedtime;
  final Map<String, dynamic>? strainTarget;

  /// Non-null when the cross-day rollup was withheld rather than absent — see
  /// [staleInsightsCard]. Drivers, sleep need and bedtime are all empty in that
  /// case, and the screen owes the user the reason.
  final Map<String, dynamic>? insightsStale;

  /// The last night that scored, when that is NOT today's — so the screen can
  /// say WHERE THE DATA STOPS on a day it has nothing of its own.
  ///
  /// It is no longer where readiness, sleep or resting heart rate come from:
  /// [overnightMetric] refuses those at the loader, and this is what is left
  /// of the held-over night once its numbers are gone. Its one job on this
  /// screen is the sentence in the nothing-today card — "the last night this
  /// app scored was Saturday" is a fact about coverage, not a reading dressed
  /// as one.
  final String? heldOverNight;

  /// The illness watch's own state — 'green' / 'amber' / 'red', or null before
  /// it has the 7 nights of baseline it needs. Home renders it only when it is
  /// amber or red; see the exception noted at the top of this file.
  final String? illnessState;

  /// The night the watch is ABOUT, and how far that night sat from this user's
  /// own baseline. `z` belongs to the latest night alone and can be negative
  /// while the run is still up, so the copy says which direction rather than
  /// implying the run reversed.
  final String? illnessDay;
  final double? illnessZ;

  /// `LocalDb.readinessAbsentDiag` off today's bundle — null unless
  /// [readiness] is absent. See `readiness_detail.dart`'s own copy of this
  /// field for why: this card's "not scored" explanation has to be built
  /// from the SAME diagnostic that screen's does, or the two can disagree.
  final Map<String, dynamic>? absentDiag;

  /// `todayHeadlineOf`'s recovery_state for today (null for a past day):
  /// night_in_progress → no number, provisional → greyed number, final.
  final String? recoveryState;

  /// `{from, to, at}` when today's final recovery changed after it was shown.
  final Map<String, dynamic>? readinessUpdate;

  /// Last night's HRV (RMSSD, ms) and breathing rate (breaths/min). Both come
  /// off the same night [sleepMin] does and are left empty whenever it is.
  final Metric hrv, resp;

  /// The mean of the 28 scored days BEFORE this one for HRV, resting HR and
  /// breathing rate — null until there are at least [kUsualMinDays] of them
  /// (the same abstention every "usual" in the app uses),
  /// so no arrow is drawn against a baseline that is not one yet.
  final double? hrvUsual, rhrUsual, respUsual;

  /// The day's finished sessions, oldest first (see [sessionsOfDay]).
  final List<Map<String, dynamic>> sessions;

  /// Greyed estimates while the real scores are still calibrating — see
  /// `compute/calibration_estimate.dart`. Only set when the real one is absent
  /// for a baseline shortfall; never stored, never notified.
  final ({double value, int nights, int need})? readinessCalibrating;
  final double? strainCalibrating;

  /// Yesterday's final recovery, and the best of the six days before this
  /// one (null under three of them) — the headline's "▲ 9 vs yesterday" and
  /// "best this week". Read from the stored series, never estimated.
  final double? readinessYesterday, readinessWeekMax;

  const HomeData({
    this.name,
    this.dayId,
    this.readiness = Metric.empty,
    this.drivers = const [],
    this.sleepMin = Metric.empty,
    this.rhr = Metric.empty,
    this.steps = Metric.empty,
    this.calories = Metric.empty,
    this.caloriesTotal = Metric.empty,
    this.strain = Metric.empty,
    this.stepGoal = kDefaultStepGoal,
    this.sleepNeedMin = Metric.empty,
    this.bedtime = Metric.empty,
    this.strainTarget,
    this.heldOverNight,
    this.illnessState,
    this.illnessDay,
    this.illnessZ,
    this.insightsStale,
    this.absentDiag,
    this.recoveryState,
    this.readinessUpdate,
    this.hrv = Metric.empty,
    this.resp = Metric.empty,
    this.hrvUsual,
    this.rhrUsual,
    this.respUsual,
    this.sessions = const [],
    this.readinessCalibrating,
    this.strainCalibrating,
    this.readinessYesterday,
    this.readinessWeekMax,
  });

  /// The three illness fields, replaced together. Test-facing sugar, and they
  /// travel as a set on purpose — they are read as one envelope, and setting
  /// one without the others describes a state the pipeline cannot produce.
  HomeData copyOrIllness(String? state, String? day, double? z) => HomeData(
        name: name,
        dayId: dayId,
        readiness: readiness,
        drivers: drivers,
        sleepMin: sleepMin,
        rhr: rhr,
        steps: steps,
        calories: calories,
        caloriesTotal: caloriesTotal,
        strain: strain,
        stepGoal: stepGoal,
        sleepNeedMin: sleepNeedMin,
        bedtime: bedtime,
        strainTarget: strainTarget,
        heldOverNight: heldOverNight,
        illnessState: state,
        illnessDay: day,
        illnessZ: z,
        insightsStale: insightsStale,
        absentDiag: absentDiag,
        recoveryState: recoveryState,
        readinessUpdate: readinessUpdate,
        hrv: hrv,
        resp: resp,
        hrvUsual: hrvUsual,
        rhrUsual: rhrUsual,
        respUsual: respUsual,
        sessions: sessions,
        readinessCalibrating: readinessCalibrating,
        strainCalibrating: strainCalibrating,
        readinessYesterday: readinessYesterday,
        readinessWeekMax: readinessWeekMax,
      );

  /// A day OTHER than today, for the Home day switcher.
  ///
  /// Deliberately thin next to [load]: everything [load] does beyond the six
  /// headline numbers below (frozen-morning-headline pin, the illness watch,
  /// sleep coach need/bedtime, readiness drivers, the stale-rollup notice) is
  /// about the ambiguity of an in-progress "today" — a past day already
  /// settled, so there is nothing there to resolve. Reuses the same
  /// date-parameterized getters the strain/sleep detail screens already read
  /// ([LocalRepository.getDayStrain]/[getDaySleepV2]) plus the one figure
  /// neither carries ([getDayOverview]'s readiness/resting_hr).
  static Future<HomeData> loadForDay(LocalRepository repo, String date,
      [AppLocalizations? l]) async {
    final profile = await repo.getProfile();
    // The three getters read the same stored day: decode it once, not three
    // times per arrow tap.
    final (overview, strain, sleep) = await repo.sharingDayReads(() async => (
          await repo.getDayOverview(date),
          await repo.getDayStrain(date),
          await repo.getDaySleepV2(date),
        ));
    final readiness = metricOf(overview['readiness']);
    // Same lookup [load] does for today, for the same reason: the ring's
    // shortfall explanation needs the stored diagnostic, and a day the
    // switcher stepped onto can be absent too, not just today (PR #510).
    final absentDiag = readiness.value != null
        ? null
        : await LocalDb.readinessAbsentDiag(date);
    return HomeData(
      name: profile['name']?.toString(),
      dayId: date,
      readiness: readiness,
      absentDiag: absentDiag,
      rhrUsual: await usualBefore('rhr', date),
      sessions: await sessionsOfDay(repo, date),
      rhr: metricOf(overview['resting_hr']),
      strain: metricOf(strain['strain']),
      steps: metricOf(strain['steps']),
      calories: metricOf(strain['calories']),
      caloriesTotal: metricOf(strain['calories_total']),
      sleepMin: metricOf(sleep['duration_min']),
      // The learned need `getDaySleepV2` already carries (absent until one is
      // learned). Left unset, the ring told a user who has a need that there
      // was "No target yet" on every day but today.
      sleepNeedMin: metricOf(sleep['need_min']),
      stepGoal: (profile['step_goal'] as num?)?.toInt() ?? kDefaultStepGoal,
    );
  }

  static Future<HomeData> load(LocalRepository repo, [AppLocalizations? l]) async {
    final today = await repo.getToday();
    final cd = await repo.getInsights();
    final profile = await repo.getProfile();

    final daily = today['daily'];
    final sleep = today['sleep'];
    Object? d(String k) => daily is Map ? daily[k] : null;
    Object? s(String k) => sleep is Map ? sleep[k] : null;

    final gb = cd['readiness_glassbox'];
    final gbDrivers = gb is Map ? gb['drivers'] : null;

    final coach = cd['sleep_coach'];
    final needEnv = coach is Map ? coach['need'] : null;
    final bedEnv = coach is Map ? coach['bedtime'] : null;
    final needSec = (envValue(needEnv)?['need_sec'] as num?);

    final strain = today['coach'];

    final heldOver = heldOverNightOf(today);

    // Same envelope Health reads. The watch runs on NOCTURNAL RESTING HEART
    // RATE ALONE — it has never been given a temperature series — so nothing
    // here may imply a second signal.
    final illness = today['illness'];

    // The three that come off the OVERNIGHT block. Gated, so a night that is
    // not today's cannot arrive wearing today's clothes — see
    // [overnightMetric]. Steps, active energy and strain are today's own and
    // are read straight.
    // ONE headline source (todayHeadlineOf): the state Coach and the widgets
    // read too. A provisional night shows its own number, greyed.
    final head = todayHeadlineOf(today);
    final recoveryState = head['recovery_state'] as String?;
    // Provisional shows its own greyed number when it has one; a provisional
    // night with no number yet (still calibrating) reads the main envelope,
    // which carries why.
    final readiness =
        recoveryState == 'provisional' && d('readiness_provisional') != null
            ? metricOf(d('readiness_provisional'))
            : overnightMetric(today, d('readiness'), l);
    final absentDiag = readiness.value != null
        ? null
        : await LocalDb.readinessAbsentDiag(
            (today['status'] as Map?)?['today_day']?.toString());

    // HRV and breathing ride the night that sleep does: when the overnight
    // gate refuses the night, they go with it.
    final sleepMin = overnightMetric(today, s('duration_min'), l);
    final hrvBlock = today['hrv'];
    final respBlock = today['resp'];
    final hrv = sleepMin.isEmpty || hrvBlock is! Map
        ? Metric.empty
        : metricOf(hrvBlock['rmssd']);
    final resp = sleepMin.isEmpty || respBlock is! Map
        ? Metric.empty
        : metricOf(respBlock['value']);
    final dayId = (today['status'] as Map?)?['today_day']?.toString();

    return HomeData(
      name: profile['name']?.toString(),
      dayId: (today['status'] as Map?)?['today_day']?.toString(),
      heldOverNight: heldOver,
      illnessState: illness is Map ? illness['state']?.toString() : null,
      illnessDay: illness is Map ? illness['date']?.toString() : null,
      illnessZ: illness is Map ? (illness['z'] as num?)?.toDouble() : null,
      readiness: readiness,
      absentDiag: absentDiag,
      recoveryState: recoveryState,
      readinessUpdate: (head['recovery_update'] as Map?)?.cast<String, dynamic>(),
      drivers: [
        for (final e in (gbDrivers is List ? gbDrivers : const []))
          if (e is Map) e.cast<String, dynamic>(),
      ],
      strain: metricOf(d('strain')),
      sleepMin: sleepMin,
      rhr: overnightMetric(today, d('resting_hr'), l),
      hrv: hrv,
      resp: resp,
      hrvUsual: hrv.isEmpty ? null : await usualBefore('rmssd', dayId),
      rhrUsual: await usualBefore('rhr', dayId),
      sessions: await sessionsOfDay(repo, dayId),
      readinessCalibrating: switch (d('readiness_calibrating')) {
        {'value': final num v, 'nights': final num n, 'need': final num need} =>
          (value: v.toDouble(), nights: n.toInt(), need: need.toInt()),
        _ => null,
      },
      readinessYesterday: await readinessOnDayBefore(dayId),
      readinessWeekMax: await readinessWeekMaxBefore(dayId),
      strainCalibrating: switch (d('strain_calibrating')) {
        {'value': final num v} => v.toDouble(),
        _ => null,
      },
      respUsual: resp.isEmpty ? null : await usualBefore('resp_rate', dayId),
      steps: metricOf(d('steps')),
      calories: metricOf(d('calories')),
      caloriesTotal: metricOf(d('calories_total')),
      stepGoal: (today['step_goal'] as num?)?.toInt() ?? kDefaultStepGoal,
      // sleep_coach.need is the COMPUTED need. `sleep.need_min` is a hardcoded
      // 480 and must never be shown as "your sleep need".
      sleepNeedMin: envMetric(needEnv, needSec == null ? null : needSec / 60,
          unit: 'min'),
      bedtime: envMetric(
          bedEnv, envValue(bedEnv)?['bedtime_min_of_day'] as num?),
      strainTarget: strain is Map && strain['strain_target'] is Map
          ? (strain['strain_target'] as Map).cast<String, dynamic>()
          : null,
      insightsStale: staleReasonOf(cd),
    );
  }
}

class HomeScreen extends StatefulWidget {
  /// Injected only by goldens; production always loads.
  final HomeData? data;

  /// Hour of day, injected only by goldens. The greeting reads the clock, so a
  /// golden baked in the evening fails the next morning on nothing but the
  /// word "evening" — a test that breaks by being run at a different time is
  /// noise that trains you to regenerate without looking.
  final int? hour;

  /// Whether a workout is live, injected only by tests/goldens — production
  /// reads it off AppState via [workoutLiveOf].
  final bool? workoutLive;

  /// The wall clock, injected only by tests. The illness watch ages by the
  /// calendar, so a test of "a day later" needs to move it.
  final DateTime? now;

  const HomeScreen(
      {super.key, this.data, this.hour, this.workoutLive, this.now});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// What Home's switcher stores for [day]: null when it is today, so "today"
/// keeps following the clock. Home lives in the shell's IndexedStack and is
/// never disposed — a literal today's date stored by "Back to today" turned
/// into yesterday at midnight, and the tab silently became a past-day view
/// (no plan, no alarm, pull-to-refresh no longer synced).
String? homeSwitcherDay(String day, {DateTime? now}) =>
    day == todayLabel(now) ? null : day;

/// How long the app has to be away before Home gives up the day it was on.
/// A quick switch to another app and back keeps the place; a longer absence
/// means the past day is no longer what the user came back for.
const kHomeKeepDayAway = Duration(minutes: 30);

/// Whether Home drops a past day for today on the way back from the
/// background: after [kHomeKeepDayAway], or when the calendar day changed
/// while away (a day stepped back onto on Friday evening is not what Saturday
/// morning opens on). [dayAtHide] null means the leave was never seen, so
/// the absence is unknown and today wins.
bool homeReturnsToToday({
  required String? dayAtHide,
  required String dayNow,
  required Duration away,
}) =>
    dayAtHide == null || dayAtHide != dayNow || away >= kHomeKeepDayAway;

/// How long the app was away, from both clocks Home keeps: the longer one.
/// The [monotonic] stopwatch stops while the phone sleeps, so a locked
/// phone reads short on it; the [wall] clock can be set back while away.
Duration homeAwayFor({required Duration wall, required Duration monotonic}) =>
    wall > monotonic ? wall : monotonic;

/// The wall clock Home reads for an absence; tests move it.
@visibleForTesting
DateTime Function() debugHomeWallClock = DateTime.now;

class _HomeScreenState extends State<HomeScreen> with RevisionReload {
  HomeData? _d;
  bool _loading = true;

  /// Whether Home has already played its entrance (see [Rise]).
  bool _entered = false;

  /// "I'm awake" is saving the night (see [AppState.markAwakeNow]).
  bool _waking = false;

  Future<void> _imAwake(BuildContext c) async {
    final app = c.read<AppState>();
    setState(() => _waking = true);
    try {
      await app.markAwakeNow();
    } catch (_) {
      // The night stays as detected; it still settles on its own.
    } finally {
      if (mounted) setState(() => _waking = false);
    }
    if (mounted) await _load();
  }

  /// The day requested by the switcher, or null for "today" — the same
  /// null-means-today convention [_load] and [HomeData.load] already used
  /// before there was a switcher.
  ///
  /// NEVER today's own label: [_goDay] stores today as null. A dated "today"
  /// does not move at midnight, so a tap on "Back to today" on Friday evening
  /// opened Saturday morning on Friday's rings with "Back to today" under
  /// them.
  String? _day;

  /// Brings Home back to today when the app returns from the background.
  /// See [_onReturnFromBackground].
  AppLifecycleListener? _lifecycle;

  /// Today's label, the wall time and a running stopwatch, all taken as the
  /// app went to the background (see [homeAwayFor]). The label catches
  /// midnight.
  String? _dayAtHide;
  DateTime? _hiddenAt;
  final Stopwatch _away = Stopwatch();

  /// `availableDays()` — newest first — for [DayNav]. Refetched with every
  /// load: cheap, and a switcher stepping onto a day that just finished
  /// deriving must see it show up without a relaunch.
  List<String> _days = const [];

  /// The load THREW. Distinct from "there is nothing yet": a decode or a locked
  /// database is a read problem, and telling a user with three months of
  /// history that their band has never produced data is the wrong answer to it.
  bool _failed = false;

  /// Set the moment "Sync the band" is tapped, cleared once real progress has
  /// a signal of its own (`syncingNow`) or after [_tapGrace] with nothing —
  /// the bridge over the gap between the tap and the first record landing,
  /// where neither `busy` (skipped entirely on the common fast-reclaim path)
  /// nor `syncingNow` has moved yet and the button would otherwise look inert.
  bool _syncTapped = false;
  Timer? _syncTapTimer;
  static const _tapGrace = Duration(seconds: 20);

  void _tapSync(VoidCallback sync) {
    sync();
    setState(() => _syncTapped = true);
    _syncTapTimer?.cancel();
    _syncTapTimer = Timer(_tapGrace, () {
      if (mounted) setState(() => _syncTapped = false);
    });
  }

  @override
  void dispose() {
    _syncTapTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  void _onHide() {
    _dayAtHide = todayLabel(widget.now ?? debugHomeWallClock());
    _hiddenAt = debugHomeWallClock();
    _away
      ..reset()
      ..start();
  }

  /// COMING BACK LATER MEANS TODAY. Home is kept alive in the tab stack, so a
  /// day stepped back onto used to survive the app going to the background —
  /// overnight, too — and the next morning opened on that old day while every
  /// detail screen behind it opened on today. A quick trip to another app and
  /// back keeps the day (see [homeReturnsToToday]). `onRestart` fires only on
  /// the way back from hidden (backgrounded), not for Control Center or a
  /// permission sheet, which leave the app merely inactive.
  ///
  /// It also reloads when the switcher was already on today: a day that rolled
  /// over while the app was backgrounded moves no database revision, so
  /// nothing else would re-read it.
  ///
  /// A past day on screen is dropped before the read, not after it: kept, its
  /// rings would sit under today's header while the read runs, and stay there
  /// for good if the read failed, since the error card only shows with no day.
  void _onReturnFromBackground() {
    if (!mounted) return;
    final hiddenAt = _hiddenAt;
    final wall = hiddenAt == null
        ? Duration.zero
        : debugHomeWallClock().difference(hiddenAt);
    final away = homeAwayFor(wall: wall, monotonic: _away.elapsed);
    _away.stop();
    _hiddenAt = null;
    final back = homeReturnsToToday(
        dayAtHide: _dayAtHide,
        dayNow: todayLabel(widget.now ?? debugHomeWallClock()),
        away: away);
    _dayAtHide = null;
    // A past day kept after a short absence needs no read here: if its data
    // changes, the database revision reloads it like any other day.
    if (_day != null && !back) return;
    setState(() {
      _day = null;
      if (_d?.dayId != todayLabel(widget.now)) {
        _d = null;
        _loading = true;
      }
    });
    _load();
  }

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _d = widget.data;
      _loading = false;
      return;
    }
    _lifecycle = AppLifecycleListener(
        onHide: _onHide, onRestart: _onReturnFromBackground);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Handed its data (golden, gallery) — the screen just renders what it has.
  @override
  bool get revisionReloads => widget.data == null;

  /// Home used to load once post-frame and never listen, so the "Sync the
  /// band" button it renders could not change what the screen showed: the
  /// offload landed, the derive ran, and Home kept saying "Nothing derived
  /// yet" until the app was relaunched.
  @override
  void reload() => _load();

  Future<void> _load() async {
    final repo = repoOf(context);
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final t = beginRead(#home);
    try {
      final day = _day;
      final l = AppLocalizations.of(context);
      final d = day == null || day == todayLabel()
          ? await HomeData.load(repo, l)
          : await HomeData.loadForDay(repo, day, l);
      final days = await repo.availableDays();
      if (stillNewest(#home, t)) {
        setState(() => (_d = d, _days = days, _loading = false, _failed = false));
      }
    } catch (_) {
      if (stillNewest(#home, t)) {
        setState(() => (_loading = false, _failed = true));
      }
    }
  }

  /// Another day. The switcher never strands you off the record — [DayNav]
  /// already restricts the arrows to [_days] — so this just re-loads for it.
  void _goDay(String day) {
    setState(() {
      _day = homeSwitcherDay(day, now: widget.now);
      // The day on screen goes with the switch. Kept, it stayed under the new
      // day's stepper for the whole load with no spinner, and for good if the
      // load threw: the rings, tiles and greeting date were still the old
      // day's, and the failure card only renders when there is no day.
      _d = null;
      _loading = true;
      _failed = false;
    });
    _load();
  }

  /// The "nothing derived yet" card, upgraded with the one thing it used to
  /// withhold: whether anything is actually happening right now. Tapping Sync
  /// used to leave this card looking identical whether the band was mid-drain
  /// or the tap had silently gone nowhere — "I am not sure if it is actually
  /// syncing or not, no progress, no cue" was exactly that gap. `syncingNow` is
  /// the one signal that is honest across BOTH session paths (a fresh connect
  /// sets `busy`; the common fast-reclaim-from-background path never does), so
  /// it is what ends "connecting", not `busy`. `deriving`/`derivePending` catch
  /// the LAST mile — the backlog landed, `syncingNow` has gone quiet again, but
  /// this screen is still bare because the heavy derive it depends on hasn't
  /// finished. Without that phase the card would flash back to a bare "Nothing
  /// derived yet" for the minute or so a full sleep-stage + spectra pass takes.
  /// The syncing / analyzing / connecting phase card — valid whether or not
  /// [HomeData] itself has loaded yet, which is why it does not take one.
  /// Shared by the fully-bare first-run path (`d == null`) and the
  /// derived-but-empty bare-day path, so a first-run tap of "Sync the band"
  /// gets the same connecting/syncing feedback as every other one. Returns
  /// null when none of the three phases apply, so the caller falls through
  /// to its own "nothing yet" copy.
  ///
  /// [firstRun]: no night has been scored on this install yet. The derive
  /// card then says what the first data can and cannot give, instead of
  /// promising last night's numbers when there is no last night.
  Widget? _phaseStatusCard(BuildContext c, AppLocalizations? l,
      {bool firstRun = false}) {
    final syncing = syncingNowOf(c);
    final deriving = derivingOf(c);
    // The tap latch is otherwise cleared only by its 20s grace timer — if
    // real progress lands before that timer fires, clear it here too so the
    // UI does not bounce back to "Connecting" once syncing/deriving goes
    // quiet again.
    if ((syncing || deriving) && _syncTapped) {
      _syncTapped = false;
      _syncTapTimer?.cancel();
    }
    final spinner = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: P.of(c).ink3),
    );

    if (syncing) {
      return StatusCard(
        l?.homeSyncingTitle ?? 'Syncing with your band',
        l?.homeSyncingBody ?? 'Pulling data now — this can take a few minutes '
            'on a full backlog.',
        leading: spinner,
      );
    }
    if (deriving) {
      final progress = deriveProgressLine(c, l);
      String withProgress(String body) =>
          progress == null ? body : '$body $progress';
      return firstRun
          ? StatusCard(
              l?.homeAnalyzingFirstTitle ?? 'Reading your first data',
              withProgress(l?.homeAnalyzingFirstBody ??
                  'Steps and strain fill in as the day goes. Sleep and '
                      'recovery need a night with the band on.'),
              leading: spinner,
            )
          : StatusCard(
              l?.homeAnalyzingTitle ?? 'Updating your numbers',
              withProgress(l?.homeAnalyzingBody ??
                  'The data is in — sleep, recovery and strain are next.'),
              leading: spinner,
            );
    }
    if (_syncTapped) {
      return StatusCard(
        l?.homeConnectingTitle ?? 'Connecting to your band',
        l?.homeConnectingBody ?? 'Hang on — this usually takes a few seconds.',
        leading: spinner,
      );
    }
    return null;
  }

  /// The header's status line: "Synced through 8:12" at rest, and while
  /// something is in flight a small spinner with one word — syncing, updating,
  /// connecting — cross-faded in its place. The quiet signal a screen full of
  /// numbers needs; the full card is only for a screen with none.
  Widget _syncLine(BuildContext c, String? dayId, AppLocalizations? l) {
    final syncing = syncingNowOf(c);
    final deriving = derivingOf(c);
    if ((syncing || deriving) && _syncTapped) {
      _syncTapped = false;
      _syncTapTimer?.cancel();
    }
    final busy = syncing
        ? (l?.homeSyncingShort ?? 'Syncing…')
        : deriving
            ? (l?.homeUpdatingShort ?? 'Updating…')
            : _syncTapped
                ? (l?.homeConnectingShort ?? 'Connecting…')
                : null;
    final p = P.of(c);
    return AnimatedSwitcher(
      duration: motion(c, Motion.slow),
      child: busy == null
          ? KeyedSubtree(
              key: const ValueKey('synced'),
              child: syncedThroughLine(c, dayId, l))
          : Row(
              key: ValueKey(busy),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: p.ink3),
                ),
                const SizedBox(width: S.x2),
                Text(busy, style: F.cap.copyWith(color: p.ink3)),
              ],
            ),
    );
  }

  Widget _bareStatusCard(BuildContext c, HomeData d, AppLocalizations? l,
      {required bool pastDay}) {
    // A PAST day with nothing on it is a settled fact, not a sync problem —
    // "Sync the band" and the derive-phase cards below are both about THIS
    // install's live pipeline catching up, which has nothing to do with a day
    // the switcher stepped back onto.
    if (pastDay) {
      return StatusCard(
        l?.homeNoDataThisDayTitle ?? 'No data for this day',
        l?.homeNoDataThisDayBody ?? 'Nothing was recorded on this day.',
        fix: '',
        icon: LucideIcons.calendarOff,
      );
    }
    final phase = _phaseStatusCard(c, l, firstRun: d.heldOverNight == null);
    if (phase != null) return phase;
    if (noBandCard(c, l) case final noBand?) return noBand;

    final sync = syncOf(c);
    return StatusCard(
      d.heldOverNight == null
          ? (l?.homeNothingDerivedTitle ?? 'No nights scored yet')
          : (l?.homeNothingTodayTitle ?? 'Nothing recorded for today'),
      d.heldOverNight == null
          ? (l?.homeNothingDerivedBody ?? 'Wear the band tonight and open the app in the morning.')
          : (l?.homeNothingTodayBody(prettyDay(d.heldOverNight, l)) ??
              'The last night this app scored was '
                  '${prettyDay(d.heldOverNight, l)}. Nothing has reached it since.'),
      fix: sync == null ? '' : (l?.homeSyncBand ?? 'Sync the band'),
      icon: LucideIcons.watch,
      onFix: sync == null ? null : () => _tapSync(sync),
    );
  }

  /// Morning / afternoon / evening / night. One split at 18:00 greeted 00:30
  /// and 15:40 alike with "Good morning" beside a sun.
  ({String word, IconData icon, Color color}) _greeting(int h, AppLocalizations? l) {
    if (h < 5) {
      return (word: l?.homeGreetingStillUp ?? 'Still up', icon: LucideIcons.moon, color: C.indigo);
    }
    if (h < 12) {
      return (word: l?.homeGreetingMorning ?? 'Good morning', icon: LucideIcons.sun, color: C.yellow);
    }
    if (h < 18) {
      return (word: l?.homeGreetingAfternoon ?? 'Good afternoon', icon: LucideIcons.sun, color: C.orange);
    }
    return (word: l?.homeGreetingEvening ?? 'Good evening', icon: LucideIcons.moon, color: C.indigo);
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final d = _d;
    final g = _greeting(widget.hour ?? DateTime.now().hour, l);

    if (d == null) {
      return _refreshable(ListView(padding: pad, children: [
        const SizedBox(height: S.x8),
        // No day on screen ⇒ no `todayId`, so this renders the dated form.
        // Shown here TOO: a first run, a failed read and a sync in flight are
        // exactly when "how far are we?" is worth answering, and the header
        // this line normally sits under does not exist on this path.
        Align(alignment: Alignment.centerLeft, child: syncedThroughLine(c, null, l)),
        // The battery reading lives on AppState.device, independent of
        // HomeData — a load failure or first run must not hide it too.
        if (batteryLine(c) case final battery?) ...[
          const SizedBox(height: 2),
          Align(alignment: Alignment.centerLeft, child: battery),
        ],
        const SizedBox(height: S.x3),
        const DetectedActivitiesCard(),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_failed)
          StatusCard(
            _day == null
                ? (l?.homeLoadFailedTitle ?? 'Today could not be read')
                : (l?.homeDayLoadFailedTitle(prettyDay(_day, l)) ??
                    '${prettyDay(_day, l)} could not be read'),
            l?.homeLoadFailedBody ??
                'The stored day failed to load. Nothing was deleted — this is a '
                'read that went wrong, not missing data.',
            fix: l?.homeTryAgain ?? 'Try again',
            icon: LucideIcons.databaseZap,
            onFix: () {
              setState(() => (_loading = true, _failed = false));
              _load();
            },
          )
        else
          Builder(builder: (c) {
            final phase = _phaseStatusCard(c, l, firstRun: _days.isEmpty);
            if (phase != null) return phase;
            if (noBandCard(c, l) case final noBand?) return noBand;
            final sync = syncOf(c);
            return StatusCard(
              l?.homeNothingDerivedTitle ?? 'No nights scored yet',
              l?.homeNothingDerivedBody ?? 'Wear the band tonight and open the app in the morning.',
              fix: sync == null ? '' : (l?.homeSyncBand ?? 'Sync the band'),
              icon: LucideIcons.watch,
              onFix: sync == null ? null : () => _tapSync(sync),
            );
          }),
        // A failed read of a day stepped back onto has no stepper on this
        // path, so this is the way home.
        if (_day != null && _day != todayLabel())
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _goDay(todayLabel()),
              child: Text(l?.homeBackToToday ?? 'Back to today'),
            ),
          ),
        if (!_loading && !_failed && widget.data == null) ...[
          const SizedBox(height: S.x3),
          firstWeekCard(c, days: _days.length, strainScored: false),
        ],
        // The alarm lives on AppState too, so a load failure must not hide it.
        if (_day == null || _day == todayLabel())
          if (alarmArmOfContext(c) case final (DateTime?, AlarmArmState) a) ...[
            const SizedBox(height: S.x3),
            alarmDoor(c, a.$1, a.$2),
          ],
      ]));
    }

    // Nothing measured at all. It used to be reachable ONLY by a load throwing
    // — a real first-run user got four stacked absence cards instead of the one
    // card written for this state.
    //
    // It is now also where a day of NO WEAR lands, because the overnight block
    // no longer borrows an older night to fill the rings with. Those are two
    // different days and the copy below splits them on the one fact that tells
    // them apart: whether this install has ever scored a night. "No band
    // recordings processed yet" said to someone with three months of history is
    // the first-run answer to a gap, and it is wrong.
    final bare = d.readiness.isEmpty &&
        d.sleepMin.isEmpty &&
        d.strain.isEmpty &&
        d.rhr.isEmpty &&
        d.steps.value == null &&
        d.calories.isEmpty;

    // Whether the switcher is showing today or a day stepped back onto —
    // gates the plan/live-workout copy below, which is about what to DO
    // today and reads as a stale instruction on a day already in the past.
    final isToday = _day == null || _day == todayLabel();

    // Until recovery can score for the first time: what arrives when.
    // Also while the readiness note still counts nights: missed nights push
    // the first score past the day-15 the count alone would show.
    final recoveryNightsLeft = needMoreNightsFromNote(d.readiness.note);
    final firstWeeks = isToday &&
        widget.data == null &&
        d.readiness.isEmpty &&
        (_days.length <= readinessCompositeMinBaseline ||
            recoveryNightsLeft != null);

    final stale = staleInsightsCard(d.insightsStale, syncOf(c), l);
    // Above the greeting, not below it: if the app had to rebuild the database
    // to start, that outranks anything else this screen has to say today.
    final rebuilt = dbRebuiltCard(dbRebuildOf(c), l);

    // The entrance plays on the first full paint of real data only; every
    // later build (a sync landing, a day switch) shows the screen as it is.
    final play = !_entered;
    if (play) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _entered = true);
    }

    return _refreshable(ListView(padding: pad, children: [
      if (rebuilt != null) ...[const SizedBox(height: S.x3), rebuilt],

      // ── the one observation Home is allowed to make ──
      //
      // OUTSIDE the derived / not-derived split, and above the rings, for two
      // separate reasons. It outranks them: when this fires it is what matters
      // today, which is the question this screen answers, and under them it
      // would read as a footnote to three numbers. And it does not depend on
      // them — the watch comes off the CROSSDAY rollup, so it can carry a real
      // state on a morning whose own bundle has not derived yet, which is
      // exactly the morning you would most want to be told.
      ...?_bodyWatch(c, d, todayLabel(widget.now)),
      // ── greeting ──
      Padding(
        padding: const EdgeInsets.only(top: S.x3, bottom: S.x4),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    d.name == null || d.name!.isEmpty
                        ? g.word
                        : '${g.word}, ${d.name}',
                    style: F.t2.copyWith(color: p.ink),
                  ),
                ),
                const SizedBox(width: S.x2),
                Icon(g.icon, size: 17, color: p.on(g.color)),
              ]),
              const SizedBox(height: 2),
              Text(prettyDay(d.dayId, l), style: F.cap.copyWith(color: p.ink3)),
              // How far the band's data reaches, always — the question "am I
              // looking at today, or at last night?" used to be answerable
              // only by opening Profile > Devices.
              // Sync and battery share one line and wrap onto a second only
              // when the text size needs it — a Wrap, not a Row with an
              // `Expanded`, so neither is ever squeezed into extra lines.
              Wrap(
                spacing: S.x3,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _syncLine(c, d.dayId, l),
                  ?batteryLine(c),
                ],
              ),
            ]),
          ),
          const SizedBox(width: S.x3),
          // The coach moved to its own chip under the plan, and Profile is the
          // same avatar every tab carries.
          const ProfileAvatar(accent: C.domHome),
        ]),
      ),

      if (bare) ...[
        const DetectedActivitiesCard(),
      ],
      ...dayNavRow(_day ?? d.dayId, _days, _goDay),
      // Stepped back through the record: one tap home.
      if (!isToday)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _goDay(todayLabel()),
            child: Text(l?.homeBackToToday ?? 'Back to today'),
          ),
        ),
      // A sync or a derive over a screen that already has numbers is said in
      // the header line (see [_syncLine]), not by a card pushed over them:
      // the numbers on screen are the last good ones, and they update in
      // place when the new ones land. The card is for a screen with nothing
      // to show yet (the bare path).
      // A sideloaded build's signature is about to lapse (iOS, free Apple ID).
      // Nothing on an App Store / TestFlight build, nor when handed data.
      if (isToday && widget.data == null) const _SideloadExpiryCard(),
      // The active wearable's day, cell by cell. Nothing on a WHOOP-only
      // install, nor when the screen is handed its data.
      if (widget.data == null)
        WearableCells(kHomeWearableRows, date: isToday ? null : _day),

      if (bare) ...[
        // A live workout holds derivation, so a bare day with a session open
        // is the hold at work, not a sync problem — see [workoutHoldCard].
        // Only for TODAY: a live workout right now says nothing about why a
        // PAST day the switcher stepped onto has nothing on it.
        isToday && (widget.workoutLive ?? workoutLiveOf(c))
            ? workoutHoldCard(l)
            : _bareStatusCard(c, d, l, pastDay: !isToday),
        // The first morning is exactly when "when do I get numbers?" is
        // loudest.
        if (firstWeeks) ...[
          const SizedBox(height: S.x3),
          firstWeekCard(c,
              days: _days.length,
              strainScored: false,
              recoveryNightsLeft: recoveryNightsLeft),
        ],
      ] else ...[
        // ── the three rings ──
        //
        // Recovery, strain and sleep, each a door into its own screen. They
        // render as long as ONE of them has something to draw — a trio of
        // empty circles says less than the one written absence below, and the
        // empty state is a DOOR, not a dead end. The pipeline records why
        // readiness came back absent on every day it does — which input was
        // missing, how many of your own nights are behind each one — and that
        // diagnostic used to go nowhere but a Firebase breadcrumb. It belongs
        // one tap away, on the Readiness screen: a wall of per-input
        // diagnostics on Home makes the app read as broken.
        if (RingTrio.has(d))
          Rise(0, play: play, child: RingTrio(
            d: d,
            onOpen: (k) => go(
                c,
                switch (k) {
                  // A past day's rings open that day's screens: the number
                  // tapped and the number shown must be the same day's.
                  HomeRingKind.recovery =>
                    ReadinessDetail(day: isToday ? null : _day),
                  HomeRingKind.strain =>
                    DayStrainDetail(day: isToday ? null : _day),
                  // The night the ring was drawn from, not last night. Today
                  // stays null even after the switcher steps back onto it:
                  // today's ring is the held-over night, and only the default
                  // pick resolves to that one.
                  HomeRingKind.sleep => SleepDetail(day: isToday ? null : _day),
                }),
          ))
        else
          Builder(builder: (c) {
            final need = needMessageFromNote(d.readiness.note);
            // readinessInputShortfallNote/readinessUnstableBaselineNote off
            // d.absentDiag are the SAME functions and the SAME stored
            // diagnostic readiness_detail.dart's banner uses — not a second,
            // independently-worded explanation — so this card and the detail
            // screen can never say two different things about the same
            // absence.
            final shortfall = need == null
                ? readinessInputShortfallNote(d.absentDiag) ??
                    readinessUnstableBaselineNote(
                        d.absentDiag?['note']?.toString())
                : null;
            return StatusCard(
              l?.homeReadinessNotScoredTitle ?? 'Recovery is not scored today',
              need != null
                  ? (l?.homeReadinessNeedBody(need) ??
                      '$need to know what normal looks like for you.')
                  // Was "Needs a night of beat-to-beat data, plus your own
                  // history to compare it to" — a cause, stated for every
                  // absence the note convention did not cover. The door below
                  // is what actually answers it.
                  : shortfall ??
                      whyFromNote(d.readiness.note) ??
                      (l?.homeReadinessNoReason ?? 'Nothing recorded says why.'),
              fix: l?.homeSeeWhatWasMissing ?? 'See what was missing',
              icon: LucideIcons.batteryCharging,
              onFix: () =>
                  go(c, ReadinessDetail(day: isToday ? null : _day)),
            );
          }),

        // Still asleep as far as the band knows: one tap ends the night now
        // and scores it, rather than waiting for the band to see the wake.
        if (isToday &&
            widget.data == null &&
            d.recoveryState == 'night_in_progress') ...[
          const SizedBox(height: S.x3),
          BigButton(
            l?.homeImAwake ?? "I'm awake",
            icon: LucideIcons.sunrise,
            color: C.blue,
            soft: true,
            busy: _waking,
            onTap: _waking ? null : () => _imAwake(c),
          ),
        ],
        // The coach's read of the morning, the day as it happened, and what
        // was lifted — each only where there is something real to show.
        if (isToday) ...[
          const SizedBox(height: S.x3),
          Rise(1, play: play, child: _CoachCard(
              briefing: _resolveBriefingNow(d).briefing,
              onOpen: () async {
                final screen =
                    AiBriefingScreen(period: _resolveBriefingNow(d).period);
                await Navigator.of(c).push(themedRoute<void>((_) => screen,
                    name: screen.runtimeType.toString()));
                if (mounted) reload();
              })),
        ],
        if (widget.data == null && d.dayId != null) ...[
          const SizedBox(height: S.x3),
          Rise(2,
              play: play,
              child: _DayStrip(
                  key: ValueKey('strip:${d.dayId}'),
                  day: d.dayId!,
                  data: d,
                  onOpen: () => go(c, DayTimelineScreen(day: _day ?? d.dayId)))),
        ],
        if (isToday && widget.data == null) ...[
          Rise(3,
              play: play,
              child: _TrainingCard(data: d, readiness: d.readiness.value,
                  final_: d.recoveryState == 'final')),
        ],
        if (_VitalsStrip.has(d)) ...[
          const SizedBox(height: S.x3),
          Rise(1,
              play: play,
              child: _VitalsStrip(d,
                  onOpen: (k) => go(
                      c,
                      isToday || _day == null
                          ? MetricDetail(k)
                          : metricDayScreen(k, _day!)))),
        ],
        const SizedBox(height: S.x3),
        Rise(2, play: play, child: const DetectedActivitiesCard()),
        if (d.sessions.isNotEmpty)
          Rise(3,
              play: play,
              child: Section(
                  l?.homeActivitiesTitle ?? 'Activities',
                  _Activities(d.sessions,
                      onOpen: () =>
                          go(c, DayTimelineScreen(day: _day ?? d.dayId))))),
        const CommunityNudge(),

        // ── the rollup was withheld, not absent ──
        if (stale != null) ...[const SizedBox(height: S.x3), stale],

        // ── at a glance ──
        // First, in the first weeks too: resting HR, steps and the night's
        // sleep are real from night one, so they lead and the "what arrives
        // when" card follows them.
        Rise(4,
            play: play,
            child: Section(l?.homeAtAGlance ?? 'At a glance',
                _glance(c, d, isToday: isToday))),
        if (firstWeeks) ...[
          const SizedBox(height: S.x3),
          firstWeekCard(c,
              days: _days.length,
              strainScored: !d.strain.isEmpty,
              recoveryNightsLeft: recoveryNightsLeft),
        ],

        // ── today's plan: only what the app can actually stand behind ──
        // Skipped on a past day — "3,000 steps left" or "aim for 11.4
        // strain" about a day already over is an instruction, not a fact.
        if (isToday)
          Rise(5,
              play: play,
              child: Section(
                  l?.homeTodaysPlan ?? "Today's plan", _plan(c, p, d))),

        // ── the way into the whole day ──
        //
        // A DOOR, NOT A CARD, and that is what keeps it on the right side of
        // the law at the top of this file. It shows no number, previews no
        // shape and makes no observation — it names a place and goes there.
        // Home decides; the day view is where you go to look, and until this
        // row existed the only ways in were two screens deep.
        const SizedBox(height: S.x5),
        detailLinkRow(c, LucideIcons.chartGantt,
            l?.homeBreakdownTitle ?? 'Breakdown of your day',
            l?.homeBreakdownSubtitle ?? 'Hour by hour',
            () => go(c, DayTimelineScreen(day: _day))),
      ],

      // ── the next alarm: a door, same as the one above ──
      // Only on a bare day: otherwise it is a tile in "At a glance", and the
      // same alarm twice on one screen is one too many.
      if (isToday && bare)
        if (alarmArmOfContext(c) case final (DateTime?, AlarmArmState) a) ...[
          const SizedBox(height: S.x3),
          alarmDoor(c, a.$1, a.$2),
        ],
      // The coach, set up or not, on every ordinary or bare today.
      if (isToday) ...[
        const SizedBox(height: S.x4),
        coachChip(c),
      ],
    ]));
  }

  /// The illness watch, on Home, at amber as well as red.
  ///
  /// Returns null on every ordinary day — green, or no state at all because the
  /// CUSUM has not got its 7 nights yet. Absence here is silence, not a card
  /// explaining that nothing is wrong: "you are not getting sick" is not an
  /// observation worth a slot, and a watch that renders daily stops being read.
  ///
  /// The tap goes to the resting-heart-rate chart rather than Health's copy of
  /// this card, because the chart is the EVIDENCE — the watch reads that one
  /// series, so the honest answer to "why are you telling me this" is to show
  /// it. Health keeps its own fuller card; this is not a duplicate route to the
  /// same words, it is a shorter road to the number underneath them.
  ///
  /// [today] is the WALL-CLOCK day at build time, not the loaded payload's: a
  /// payload loaded yesterday and rebuilt today with no new sync has aged a
  /// day all the same.
  static List<Widget>? _bodyWatch(BuildContext c, HomeData d, String today) {
    final state = d.illnessState;
    if (state == null || state == 'green') return null;
    // The watch publishes the newest SETTLED night, which after days off the
    // wrist is days old, and the red title carries no date. Same freshness
    // rule as the push: older verdicts live in Observations, not on Home.
    final day = d.illnessDay;
    if (day == null || !isRecentFindingDate(day, today: today)) return null;
    final l = AppLocalizations.of(c);

    final sameNight = day == today;
    final z = d.illnessZ;
    final zAbs = z == null ? '' : z.abs().toStringAsFixed(1);

    return [
      Observation(
        state == 'red'
            ? (l?.homeIllnessRedTitle ?? 'Recent nights add up to a raised resting heart rate')
            : sameNight
                ? (l?.homeIllnessAmberSameNight ?? 'Last night sat outside your normal range')
                : (l?.homeIllnessAmberOtherNight(prettyDay(d.illnessDay, l)) ??
                    '${prettyDay(d.illnessDay, l)} sat outside your normal range'),
        z == null
            ? (l?.homeIllnessBodyNoZ ??
                'Your resting heart rate has run above your usual over recent nights. This tracks one signal, so it shows a pattern, not a cause.')
            : (z >= 0
                ? (l?.homeIllnessBodyAbove(zAbs) ??
                    'Recent nights put your resting heart rate above your usual. That night was $zAbs× your normal night-to-night swing above it. A pattern, not a cause.')
                : (l?.homeIllnessBodyBelow(zAbs) ??
                    'Recent nights together put your resting heart rate above your usual, even though that night on its own was $zAbs× your normal night-to-night swing below it. A pattern, not a cause.')),
        advice: l?.homeIllnessAdvice ?? 'Worth noting if it continues past a couple of days.',
        onTap: () => go(c, const MetricDetail('resting_hr')),
      ),
      const SizedBox(height: S.x3),
    ];
  }

  /// Pull to sync. Pull used to re-read the phone's database and nothing
  /// else, while every other wearable app treats it as "sync now". It now
  /// asks the band for its backlog (today only, and only with a band), shows
  /// the same connecting / syncing / analysing card the Sync button does, and
  /// re-reads when the sync returns. A past day just re-reads.
  Widget _refreshable(Widget list) =>
      RefreshIndicator(onRefresh: _pullToSync, child: list);

  Future<void> _pullToSync() async {
    AppState? app;
    try {
      app = context.read<AppState>();
    } catch (_) {
      // No AppState above us (goldens): nothing to sync.
    }
    final isToday = _day == null || _day == todayLabel();
    if (app != null && app.isPaired && isToday && widget.data == null) {
      _tapSync(() {});
      // ponytail: the spinner lets go after 90 s; a long backlog keeps going
      // in the background and the syncing card stays up until it ends.
      try {
        await app.syncNow().timeout(const Duration(seconds: 90));
      } catch (_) {
        // A timeout or a failed sync still re-reads what did land.
      }
    }
    await _load();
  }

  Widget _glance(BuildContext c, HomeData d, {required bool isToday}) {
    final l = AppLocalizations.of(c);
    final cards = <Widget>[];
    final absent = <StatusCard>[];

    void add(Metric m, Widget Function() card, StatusCard? Function() gap) {
      if (m.isEmpty) {
        final s = gap();
        if (s != null) absent.add(s);
      } else {
        cards.add(card());
      }
    }

    // Resting heart rate comes off the SAME overnight block readiness does,
    // and it used to carry a date on its own line for the mornings that block
    // was held over from an older night. It cannot be an older night any more
    // — the loader refuses those — so every tile in this row is today's and
    // none of them needs a date.
    //
    // On a past day every tile is THAT day's, and the trend screen opens on
    // today's window — tapping "11,204" landed on today's count. A past day's
    // tile opens the screen for the day it is showing instead.
    Widget detail(String key) =>
        isToday || _day == null ? MetricDetail(key) : metricDayScreen(key, _day!);

    // Sleep is a RING now, duration and all — the card here was the same
    // number twice on one screen, and the ring is the one that says what the
    // duration was measured against.
    // A measured resting rate is drawn in the vitals row under the rings now;
    // drawing it again here would be the same number twice on one screen.
    // Its ABSENCE still belongs to this section's one missing-data card.
    if (d.rhr.isEmpty) {
      // "no sleep was recorded" was stated as fact, unconditionally — and it
      // was rendered directly beside a Sleep card showing that night's
      // duration. Sleep duration and nocturnal RHR are gated separately: a
      // night staged from the accelerometer with no clean resting window
      // produces exactly that pair.
      // The else-branch used to name the gate — "no stretch of beats clean
      // enough" — which is one of several reasons a scored night yields no
      // resting rate, picked by a human writing copy. Only the branch the
      // screen can actually see is stated; the other defers to the note, or to
      // saying it does not know.
      final gap = StatusCard.forMetric(
          l?.homeNoRestingHr ?? 'No resting heart rate', d.rhr,
          why: d.sleepMin.isEmpty
              ? (l?.homeNoRestingHrWhy ??
                  'Resting heart rate is read from sleep, and no sleep was recorded.')
              : '');
      if (gap != null) absent.add(gap);
    }
    // Steps keeps its tile whether or not a counter reported. Zero steps is a
    // real reading — an unmoved counter — and it renders as 0, not as absence.
    // When nothing counted at all the tile stays and says so in two words,
    // rather than the whole card being replaced by a paragraph about wrist
    // motion: the answer to "how many steps" is short either way.
    cards.add(SignalCard(
      LucideIcons.footprints,
      C.green,
      l?.homeSteps ?? 'Steps',
      d.steps.value == null ? (l?.homeStepsNone ?? 'None') : thousands(d.steps.value),
      // The sensor rides the line that is already there rather than adding a
      // row: the day is resolved per window now, so "8,412" can be the strap's
      // count, the phone's, or both, and the card has to say which. The split
      // behind a mixed day is on Nerd stats, one tap down.
      sub: d.steps.value == null
          ? (l?.homeStepsNotRecorded ?? 'NOT RECORDED')
          : [
              if (d.stepGoal > 0)
                l?.homeStepsPercentGoal(
                        ((d.steps.value! / d.stepGoal) * 100).clamp(0, 999).round()) ??
                    '${((d.steps.value! / d.stepGoal) * 100).clamp(0, 999).round()}% of goal',
              ?stepSensorLabel(d.steps, l),
            ].join(' · '),
      onTap: () => go(c, detail('steps')),
      trailing: d.steps.value == null || d.stepGoal <= 0
          ? null
          : SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(
                painter: Ring(d.steps.value! / d.stepGoal, C.green,
                    P.of(c).track,
                    stroke: 3, solid: true),
              ),
            ),
    ));
    add(
      d.calories,
      () => SignalCard(LucideIcons.flame, C.orange, l?.homeActiveEnergy ?? 'Active energy',
          thousands(d.calories.value),
          unit: 'kcal',
          sub: d.caloriesTotal.value == null
              ? (l?.homeCaloriesEstimated ?? 'Estimated')
              : (l?.homeCaloriesTotal(thousands(d.caloriesTotal.value)) ??
                  '${thousands(d.caloriesTotal.value)} total'),
          onTap: () => go(c, detail('calories'))),
      // No `why:`. It said "Needs your weight and age" — and the measured run
      // printed that to a profile carrying both, because energy had gone absent
      // for an entirely different reason that the card never asked for.
      () => StatusCard.forMetric(l?.homeNoEnergyEstimate ?? 'No energy estimate', d.calories),
    );
    // The next alarm is not a reading of the day, so only today carries it —
    // "Tomorrow 07:30" under a day already over would be about a different day.
    if (isToday) {
      if (alarmArmOfContext(c) case final (DateTime?, AlarmArmState) a) {
        cards.add(alarmGlanceCard(c, a.$1, a.$2));
      }
    }

    return Column(children: [
      for (var i = 0; i < cards.length; i += 2) ...[
        if (i > 0) const SizedBox(height: S.x3),
        // IntrinsicHeight, because `stretch` inside a ListView asks for an
        // infinite height. The two cards in a row must match: a short card
        // beside a tall one reads as a layout bug, not as less data.
        // An odd last card takes the whole width rather than half of it with a
        // hole beside it. Three cards is the ordinary count now that sleep is
        // a ring, so the gap would be there every day.
        if (i + 1 >= cards.length)
          cards[i]
        else
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: cards[i]),
              const SizedBox(width: S.x3),
              Expanded(child: cards[i + 1]),
            ]),
          ),
        ],
        // One card for everything missing, not one card each: a partial
        // night used to stack two or three absence cards and read as broken.
        if (absent.length == 1) ...[const SizedBox(height: S.x3), absent.single]
        else if (absent.length > 1) ...[
          const SizedBox(height: S.x3),
          StatusCard(
            // The glance also renders for a day the switcher stepped back
            // onto, where "today's" names the wrong day.
            isToday
                ? (l?.homeSomeDataMissingTitle ??
                    'Some of today\'s data is missing')
                : (l?.homeSomeDayDataMissingTitle ??
                    'Some of this day\'s data is missing'),
            [
              for (final s in absent)
                [s.what, s.why, s.fix].where((t) => t.isNotEmpty).join('. '),
            ].join('\n'),
            icon: LucideIcons.circleDashed,
          ),
        ],
      ],
    );
  }


  Widget _plan(BuildContext c, P p, HomeData d) {
    final l = AppLocalizations.of(c);
    final rows = <Widget>[];

    final stepsLeft = d.steps.value == null
        ? null
        : (d.stepGoal - d.steps.value!).round();
    if (stepsLeft != null && stepsLeft > 0) {
      rows.add(_row(
          p,
          LucideIcons.footprints,
          C.green,
          l?.homeStepsLeft(thousands(stepsLeft)) ?? '${thousands(stepsLeft)} steps left',
          l?.homeMovement ?? 'Movement',
          l?.homeGoalSteps(thousands(d.stepGoal)) ?? 'Goal ${thousands(d.stepGoal)}',
          false));
    } else if (stepsLeft != null) {
      rows.add(_row(p, LucideIcons.footprints, C.green,
          l?.homeStepGoalMet ?? 'Step goal met',
          l?.homeMovement ?? 'Movement', l?.actionDone ?? 'Done', true));
    }

    final target = d.strainTarget;
    if (target != null && target['value'] is num) {
      final aim = target['value'] as num;
      // The strain ring is on this screen now, so a row still saying "aim for
      // 11.4" beside a ring reading 14.2 is a plan the day already overtook.
      // Same shape the step goal above it has always had.
      final met = (d.strain.value ?? -1) >= aim;
      rows.add(_row(
          p,
          LucideIcons.zap,
          C.purple,
          met
              ? (l?.homeStrainTargetMet ?? 'Strain target met')
              : (l?.homeAimForStrain(displayFixed(aim, 1)) ??
                  'Aim for ${displayFixed(aim, 1)} strain'),
          // Built on a wearable's estimated TRIMP: say so.
          [
            l?.homeTraining ?? 'Training',
            if (target['estimated'] == true) l?.wearableEstimated ?? 'Estimated',
          ].join(' · '),
          met
              ? (l?.actionDone ?? 'Done')
              : '${_fixed1OrEmpty(target['low'])}–'
                  '${_fixed1OrEmpty(target['high'])}',
          met));
    }

    final need = d.sleepNeedMin.value;
    if (need != null) {
      rows.add(_row(
          p,
          LucideIcons.bedDouble,
          C.blue,
          l?.homeSleepNeedRow(hm(need)) ?? '${hm(need)} of sleep',
          l?.homeTonight ?? 'Tonight',
          d.bedtime.value == null
              ? (l?.homeNeed ?? 'Need')
              : (l?.homeBedTime(clock(d.bedtime.value)) ?? 'Bed ${clock(d.bedtime.value)}'),
          false));
    }

    final planBody = rows.isEmpty
        ? StatusCard.forMetric(l?.homeNoPlanTitle ?? 'No plan for today yet', d.sleepNeedMin,
                // "none are established yet" is the COLD-START reason, and it
                // is a wrong answer when the baselines exist and are being
                // withheld.
                why: d.insightsStale != null
                    ? (l?.homeNoPlanWhyStale ?? 'Your trends are being updated. This takes a minute after a sync.')
                    : (l?.homeNoPlanWhyNone ?? 'None are established yet.')) ??
            const SizedBox.shrink()
        : Surface(
            pad: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x2),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(color: p.line, height: 1),
                rows[i],
              ],
            ]),
          );

    // The briefing used to have a row here; it is the coach card near the
    // top of Home now, and one place is enough.
    return planBody;
  }

  /// The briefing to show now, resolved fresh on every call: Home is kept
  /// alive by the shell's IndexedStack, so a decision captured at build time
  /// could outlive the morning/evening boundary.
  ({BriefingPeriod period, Briefing? briefing}) _resolveBriefingNow(HomeData d) {
    final period = currentBriefingPeriod(DateTime.now());
    return resolveBriefingToShow(
      period,
      BriefingStore.read(period, day: d.dayId),
      BriefingStore.read(BriefingPeriod.morning, day: d.dayId),
    );
  }

  Widget _row(P p, IconData i, Color col, String title, String kind,
          String meta, bool done) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: S.x3),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration:
                BoxDecoration(color: p.wash(col), borderRadius: R.rSm),
            child: Icon(i, size: 16, color: p.on(col)),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind, style: F.over.copyWith(color: p.ink3)),
                  const SizedBox(height: 2),
                  Text(title, style: F.body.copyWith(color: p.ink)),
                ]),
          ),
          const SizedBox(width: S.x2),
          Text(meta,
              textAlign: TextAlign.right,
              style: F.cap.copyWith(
                  color: done ? p.on(C.green) : p.ink3,
                  fontWeight: done ? FontWeight.w600 : FontWeight.w400)),
        ]),
      );
}

/// What happens in the first weeks, with the counts the pipeline actually
/// gates on: sleep after the first night, strain once [quietHrrMinDays] earlier
/// days give it a resting level, recovery once [readinessCompositeMinBaseline]
/// earlier nights give it a normal range. Read from the analytics constants so
/// the card cannot drift from the gate.
Widget firstWeekCard(BuildContext c,
    {required int days, required bool strainScored, int? recoveryNightsLeft}) {
  final p = P.of(c);
  final l = AppLocalizations.of(c);
  final strainDay = quietHrrMinDays + 1;
  final recoveryNight = readinessCompositeMinBaseline + 1;
  Widget step(bool done, String text) => Semantics(
        // The tick is drawn, so it is also said.
        label: done ? (l?.homeFirstWeekDone(text) ?? 'Done: $text') : text,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: S.x2),
          child: Row(children: [
            Icon(done ? LucideIcons.circleCheck : LucideIcons.circle,
                size: 18, color: done ? p.on(C.green) : p.ink3),
            const SizedBox(width: S.x3),
            Expanded(
                child: Text(text, style: F.body.copyWith(color: p.ink))),
          ]),
        ),
      );
  return Surface(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l?.homeFirstWeekTitle ?? 'Your first weeks',
          style: F.head.copyWith(color: p.ink)),
      const SizedBox(height: S.x2),
      step(days > 0, l?.homeFirstWeekWear ?? 'Wear the band tonight'),
      step(days > 0,
          l?.homeFirstWeekSleep ?? 'Sleep: the morning after your first night'),
      step(strainScored,
          l?.homeFirstWeekStrain(strainDay) ?? 'Strain: from day $strainDay'),
      // The live countdown when the pipeline says how many nights are left;
      // the static "from night N" only before it has said anything.
      step(
          false,
          recoveryNightsLeft != null
              ? (l?.homeRecoveryStartsIn(recoveryNightsLeft) ??
                  'Recovery starts in $recoveryNightsLeft nights')
              : (l?.homeFirstWeekRecovery(recoveryNight) ??
                  'Recovery: from night $recoveryNight, once it knows your normal')),
      const SizedBox(height: S.x1),
      Text(l?.homeFirstWeekSoFar(days) ?? '$days days recorded so far',
          style: F.cap.copyWith(color: p.ink3)),
    ]),
  );
}

/// The coach's one door on Today. It used to be an icon that appeared only
/// once a model was configured, so a new user never learned there was a
/// coach. Not set up, the chip says what it is for and opens the setup.
Widget coachChip(BuildContext c) {
  final p = P.of(c);
  final l = AppLocalizations.of(c);
  final ready = coachReady(c);
  final text = ready
      ? (l?.homeAskCoach ?? 'Ask the coach')
      : (l?.homeCoachSetUpChip ?? 'Ask questions about your data: set up the coach');
  return Align(
    alignment: Alignment.centerLeft,
    child: Pressable(
      semanticLabel: text,
      onTap: () => go(c, ready ? const CoachScreen() : const CoachSetup()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x3),
        decoration:
            BoxDecoration(color: p.wash(kCoachAccent), borderRadius: R.rPill),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.sparkles, size: 16, color: p.on(kCoachAccent)),
          const SizedBox(width: S.x2),
          Flexible(
            child: Text(text,
                style: F.cap.copyWith(
                    color: p.on(kCoachAccent), fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    ),
  );
}

/// "Re-sign within N hours" on Home while a sideloaded build's 7-day
/// signature runs out. Asked once per screen build of Home; renders nothing
/// when there is no profile or the expiry is more than two days away.
class _SideloadExpiryCard extends StatefulWidget {
  const _SideloadExpiryCard();

  @override
  State<_SideloadExpiryCard> createState() => _SideloadExpiryCardState();
}

class _SideloadExpiryCardState extends State<_SideloadExpiryCard> {
  late final Future<DateTime?> _expiry = Provisioning.expiry();

  @override
  Widget build(BuildContext c) => FutureBuilder<DateTime?>(
        future: _expiry,
        builder: (c, snap) {
          final notice = sideloadExpiryNotice(snap.data, DateTime.now());
          if (notice == null) return const SizedBox.shrink();
          final l = AppLocalizations.of(c);
          final title = notice.hoursLeft == 0
              ? (l?.sideloadExpiryLapsedTitle ?? 'This install has expired')
              : (l?.sideloadExpiryTitle(notice.hoursLeft) ??
                  'This install stops opening in ${notice.hoursLeft} h');
          return Padding(
            padding: const EdgeInsets.only(bottom: S.x3),
            child: StatusCard(
              title,
              l?.sideloadExpiryBody ??
                  'Re-sign it with Sideloadly, using the same Apple ID, to '
                      'keep syncing. Installing over it keeps your data.',
              icon: LucideIcons.clock,
            ),
          );
        },
      );
}
