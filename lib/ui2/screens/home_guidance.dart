// FORK — what Home says beyond the numbers (iteration 4: P-01, P-03, P-08 and
// the "how it is computed" sheet). Everything here is deterministic: no model
// is asked, nothing is stored, and every sentence is built from a value the
// day's bundle or the stored series already holds.
//
//   * DecisionLine  — the day's training call, from the recovery band the
//                     ring already shows, with the inputs that moved it.
//   * EvolutionCard — the last week against the four before it, per metric,
//                     and only called a change when it clears the noise
//                     (compute/fork/trends.dart).
//   * dataFreshnessLine — "synced through …" for the tabs that are not Home.
//   * HowComputedScreen — what each headline number is made of.
//
// Absence is never dressed up: a recovery that is not scored gives no call, a
// series too short for a verdict says so, and a tab with no band data draws
// no freshness line at all (its own empty state already says why).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../compute/derivation_engine.dart' show kAlgoVersion;
import '../../compute/fork/trend_service.dart';
import '../../compute/fork/trends.dart' as fork;
import '../../l10n/app_localizations.dart';
import '../../l10n/decimal_text.dart';
import '../ui2.dart';
import 'home_screen.dart'
    show
        derivingOf,
        driverLabel,
        hm,
        lastDataAtOf,
        readinessBand,
        syncedThroughLine,
        syncingNowOf;
import 'metric_detail.dart' show detailScaffold;

// ── P-01 · the day's call ──────────────────────────────────────────────────

/// The training call for a recovery band tier ([readinessBand]'s `tier`,
/// 0–3). One place, so the line on Home and the log of past days use the
/// same words.
String decisionCall(int tier, AppLocalizations? l) => switch (tier) {
      3 => l?.homeDecisionGood ?? 'A good day for intensity',
      2 => l?.homeDecisionSteady ?? 'A normal day: train as planned',
      1 => l?.homeDecisionEasy ?? 'Keep it light today',
      _ => l?.homeDecisionRest ?? 'A day to recover',
    };

/// One deterministic sentence about today's training, read off the SAME band
/// the recovery ring is in ([readinessBand]) so the two cannot disagree, and
/// the inputs that pushed the score up or held it back.
///
/// It is a call about training load, not about health, and it is only made on
/// a real score: while recovery is calibrating it says exactly that, and with
/// no score and no calibration it draws nothing.
class DecisionLine extends StatelessWidget {
  const DecisionLine({
    super.key,
    required this.readiness,
    this.calibrating = false,
    this.drivers = const [],
  });

  /// Today's final recovery, 0–100; null when it is not scored.
  final num? readiness;

  /// True while only the greyed estimate exists.
  final bool calibrating;

  /// The composite's own drivers: `{label, contribution}`, contribution
  /// positive when the input pushed the score up.
  final List<Map<String, dynamic>> drivers;

  /// Whether there is anything to say at all.
  static bool has({required num? readiness, required bool calibrating}) =>
      readiness != null || calibrating;

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final v = readiness;
    if (v == null) {
      if (!calibrating) return const SizedBox.shrink();
      return Surface(
        child: Text(
          l?.homeDecisionCalibrating ??
              'No training call yet: recovery is still calibrating',
          style: F.body.copyWith(color: p.ink2),
        ),
      );
    }
    final band = readinessBand(v, l);
    final call = decisionCall(band.tier, l);
    String names(bool up) => drivers
        .where((e) {
          final k = e['contribution'];
          return k is num && (up ? k > 0 : k < 0);
        })
        .take(2)
        .map((e) => driverLabel(e['label'], l))
        .where((s) => s.isNotEmpty)
        .join(', ');
    final helping = names(true), holding = names(false);
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.zap, size: 18, color: p.on(band.color)),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            child: Text(call, style: F.head.copyWith(color: p.ink)),
          ),
        ]),
        if (helping.isNotEmpty) ...[
          const SizedBox(height: S.x2),
          Text(l?.homeDecisionHelping(helping) ?? 'Helping: $helping',
              style: F.cap.copyWith(color: p.ink2)),
        ],
        if (holding.isNotEmpty) ...[
          const SizedBox(height: S.x1),
          Text(l?.homeDecisionHolding(holding) ?? 'Holding it back: $holding',
              style: F.cap.copyWith(color: p.ink2)),
        ],
      ]),
    );
  }
}

// ── the three series every week-level verdict is made on ───────────────────

/// The stored series the fork's trend rules read, and how each one prints.
/// One list, so Home's evolution card, the weekly line under a Health trend,
/// the period lab and the weekly report cannot disagree about a unit.
enum GuideMetric {
  hrv('ln_rmssd'),
  rhr('rhr'),
  sleep('tst_min');

  const GuideMetric(this.seriesKey);

  /// The `metric_series` key.
  final String seriesKey;

  String label(AppLocalizations? l) => switch (this) {
        hrv => l?.homeDriverHrv ?? 'HRV',
        rhr => l?.homeDriverRhr ?? 'Resting heart rate',
        sleep => l?.homeRingSleep ?? 'Sleep',
      };

  /// A signed difference in this metric, with its unit. The HRV series is
  /// lnRMSSD, so its differences read as a percentage of RMSSD: e^Δ − 1.
  String delta(double d, AppLocalizations? l) => switch (this) {
        hrv => signed(
            d,
            '${displayFixed(((math.exp(d.abs()) - 1) * 100).clamp(0, 999), 0)} %',
          ),
        rhr => signed(
            d,
            '${displayFixed(d.abs(), 1)} ${l?.activityZonesBpmUnit ?? 'bpm'}',
          ),
        sleep => signed(d, hm(d.abs())),
      };

  /// A level (a mean of the series) in the unit the app shows. The mean of
  /// lnRMSSD goes back to milliseconds as e^mean — a geometric mean.
  String level(double v, AppLocalizations? l) => switch (this) {
        hrv => '${displayFixed(math.exp(v), 0)} ms',
        rhr => '${displayFixed(v, 1)} ${l?.activityZonesBpmUnit ?? 'bpm'}',
        sleep => hm(v),
      };
}

/// What a week-against-usual verdict says: the signed change when it clears
/// the noise, "Stable" when it does not, and "not enough days" when it cannot
/// be judged (never "stable" for that).
String weekVerdict(GuideMetric m, fork.Trend t, AppLocalizations? l) =>
    switch (t.relevant) {
      true => l?.homeEvolutionChanged(m.delta(t.change!.delta, l)) ??
          '${m.delta(t.change!.delta, l)} vs your usual',
      false => l?.homeEvolutionStable ?? 'Stable',
      null => l?.homeEvolutionNeedsDays ?? 'Not enough days yet',
    };

/// P-02 — the week's verdict under a single-day trend card: "Last 7 days:
/// stable". The card above it judges ONE reading against your usual range;
/// this line judges the week, and only calls it a change when it clears the
/// minimal detectable change. Loads on its own ([TrendService]); until it
/// has an answer, and when reading fails, it draws nothing.
class WeekTrendLine extends StatefulWidget {
  const WeekTrendLine(this.metric, {super.key});
  final GuideMetric metric;

  @override
  State<WeekTrendLine> createState() => _WeekTrendLineState();
}

class _WeekTrendLineState extends State<WeekTrendLine> with RevisionReload {
  fork.Trend? _trend;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // The tabs live in an IndexedStack, so without this a new night never
  // reached a line that was already on screen.
  @override
  void reload() => _load();

  Future<void> _load() async {
    final read = beginRead(#trend);
    try {
      final t = await TrendService.of(widget.metric.seriesKey);
      if (stillNewest(#trend, read)) setState(() => _trend = t);
    } catch (_) {
      // No database (a test host, a locked store): nothing to show.
    }
  }

  @override
  Widget build(BuildContext c) {
    final t = _trend;
    if (t == null) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final verdict = weekVerdict(widget.metric, t, l);
    return Padding(
      padding: const EdgeInsets.only(left: S.x1, top: S.x2),
      child: Text(
        l?.trendWeekLine(verdict) ?? 'Last 7 days: $verdict',
        style: F.cap.copyWith(
          color: t.relevant == true ? p.ink : p.ink3,
          fontWeight: t.relevant == true ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

// ── P-03 · how you are evolving ────────────────────────────────────────────

/// One metric's verdict: [relevant] true = changed beyond the noise, false =
/// stable, null = not enough days to say. [delta] is the signed difference,
/// already formatted with its unit; only read when [relevant] is true.
typedef EvolutionRow = ({String label, bool? relevant, String delta});

/// The last 7 days against the 4 weeks before them, one row per metric.
/// Draws nothing with no rows.
class EvolutionCard extends StatelessWidget {
  const EvolutionCard(this.rows, {super.key});
  final List<EvolutionRow> rows;

  @override
  Widget build(BuildContext c) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    String verdict(EvolutionRow r) => switch (r.relevant) {
          true => l?.homeEvolutionChanged(r.delta) ?? '${r.delta} vs your usual',
          false => l?.homeEvolutionStable ?? 'Stable',
          null => l?.homeEvolutionNeedsDays ?? 'Not enough days yet',
        };
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          l?.homeEvolutionSub ?? 'Last 7 days against the 4 weeks before',
          style: F.cap.copyWith(color: p.ink3),
        ),
        for (final r in rows) ...[
          const SizedBox(height: S.x3),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(r.label, style: F.body.copyWith(color: p.ink)),
            ),
            const SizedBox(width: S.x3),
            Flexible(
              child: Text(
                verdict(r),
                textAlign: TextAlign.right,
                style: F.body.copyWith(
                  color: r.relevant == true ? p.ink : p.ink3,
                  fontWeight:
                      r.relevant == true ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// [EvolutionCard] for the three series Home cares about, loaded when it
/// first appears: [TrendService] reads the stored series, runs the bootstrap
/// in an isolate and caches it. Never part of `getToday`.
///
/// Until the trends arrive, and whenever reading them fails, it draws
/// nothing — a section that cannot be filled is not announced.
class HomeEvolution extends StatefulWidget {
  const HomeEvolution({super.key});

  @override
  State<HomeEvolution> createState() => _HomeEvolutionState();
}

class _HomeEvolutionState extends State<HomeEvolution> with RevisionReload {
  List<fork.Trend>? _trends;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Home stays mounted for the life of the app: re-read when a derive or an
  // import lands, or the card would show the week it was first opened in.
  @override
  void reload() => _load();

  Future<void> _load() async {
    final read = beginRead(#trends);
    try {
      final out = <fork.Trend>[];
      for (final m in GuideMetric.values) {
        out.add(await TrendService.of(m.seriesKey));
      }
      if (stillNewest(#trends, read)) setState(() => _trends = out);
    } catch (_) {
      // No database (a test host, a locked store): nothing to show.
    }
  }

  @override
  Widget build(BuildContext c) {
    final t = _trends;
    if (t == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(c);
    return Section(
      l?.homeEvolutionTitle ?? "How you're evolving",
      EvolutionCard([
        for (final (i, m) in GuideMetric.values.indexed)
          (
            label: m.label(l),
            relevant: t[i].relevant,
            delta: t[i].change == null ? '' : m.delta(t[i].change!.delta, l),
          ),
      ]),
    );
  }
}

// ── P-08 · how fresh is this ───────────────────────────────────────────────

/// The status line Home's header carries, for the other tabs: "Syncing…",
/// "Updating…" or "Synced through …". With no band data and nothing in
/// progress it is an empty box — the tab's own empty state already says so.
Widget dataFreshnessLine(BuildContext c) {
  final l = AppLocalizations.of(c);
  final busy = syncingNowOf(c)
      ? (l?.homeSyncingShort ?? 'Syncing…')
      : derivingOf(c)
          ? (l?.homeUpdatingShort ?? 'Updating…')
          : null;
  if (busy == null && lastDataAtOf(c) == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(left: S.x1, bottom: S.x2),
    child: Align(
      alignment: Alignment.centerLeft,
      child: busy == null
          ? syncedThroughLine(c, null, l)
          : Text(busy, style: F.cap.copyWith(color: P.of(c).ink3)),
    ),
  );
}

// ── how each headline number is computed ───────────────────────────────────

/// What today's number stands on: [scored] from the user's own data,
/// [estimate] while a baseline is still building ([have] of [need] nights
/// when the count is known), [absent] when there is nothing for it today.
enum HowKind { scored, estimate, absent }

typedef HowStatus = ({HowKind kind, int? have, int? need});
typedef HowToday = ({
  HowStatus recovery,
  HowStatus strain,
  HowStatus sleep,
  HowStatus vitals,
});

String howTodayText(HowStatus s, AppLocalizations? l) => switch (s.kind) {
      HowKind.scored => l?.howTodayScored ?? 'Today: from your own data',
      HowKind.absent => l?.howTodayAbsent ?? 'Today: nothing to compute it from',
      HowKind.estimate => s.have != null && s.need != null
          ? (l?.howTodayEstimateOf(s.have!, s.need!) ??
              'Today: an estimate, ${s.have} of ${s.need} nights of your own')
          : (l?.howTodayEstimate ??
              'Today: an estimate, your own baseline is still building'),
    };

/// A plain page: for each headline number, whether it is measured, derived
/// or estimated, what goes into it, the window it looks at and what it does
/// with missing data, and where it stops being trustworthy. Static text, the
/// running algorithm version and, when Home hands it over, what today's
/// number of each kind stands on; it reads nothing itself.
class HowComputedScreen extends StatelessWidget {
  const HowComputedScreen({super.key, this.today});

  /// What today's number of each kind stands on, from the day Home already
  /// loaded; null (a deep link, a test) draws the page without those lines.
  final HowToday? today;

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final measured = l?.howComputedMeasured ?? 'Measured';
    final derived = l?.howComputedDerived ?? 'Derived';
    Widget part(String label, String text) => Padding(
          padding: const EdgeInsets.only(top: S.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: F.over.copyWith(color: p.ink3)),
              const SizedBox(height: S.x1),
              Text(text, style: F.body.copyWith(color: p.ink2, height: 1.45)),
            ],
          ),
        );
    Widget metric(String name, String kind, String unit, String what,
            String data, String limits, [HowStatus? now]) =>
        Padding(
          padding: const EdgeInsets.only(bottom: S.x4),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: F.head.copyWith(color: p.ink)),
                const SizedBox(height: S.x1),
                Text('$kind · $unit', style: F.cap.copyWith(color: p.ink3)),
                if (now != null) ...[
                  const SizedBox(height: S.x2),
                  Text(howTodayText(now, l),
                      style: F.cap.copyWith(
                          color: p.ink, fontWeight: FontWeight.w600)),
                ],
                part(l?.howComputedInputs ?? 'What goes in', what),
                part(l?.howComputedMissing ?? 'Window and missing data', data),
                part(l?.howComputedLimits ?? 'Limits', limits),
              ],
            ),
          ),
        );
    return detailScaffold(
      c,
      l?.howComputedTitle ?? 'How these numbers are computed',
      [
        metric(
          l?.homeRingRecovery ?? 'Recovery',
          derived,
          '0–100',
          l?.howRecoveryWhat ??
              "Last night's HRV, resting heart rate and breathing rate, each "
                  'compared with your own usual. HRV and resting heart rate '
                  'count together for most of the score. Sleep length is '
                  'shown beside it, not mixed in.',
          l?.howRecoveryData ??
              'Your usual is the median of up to 28 earlier nights; a night '
                  'never counts toward its own baseline. It needs 14 nights. '
                  'A missing input is left out, never filled in. Until then '
                  'a grey estimate that starts from a general adult '
                  'reference is shown instead.',
          l?.howRecoveryLimits ??
              'Wrist heart-rate variability is not an ECG. The score says '
                  'how last night compares with your normal; it is not a '
                  'medical reading.',
          today?.recovery,
        ),
        metric(
          l?.homeRingStrain ?? 'Strain',
          derived,
          '0–21',
          l?.howStrainWhat ??
              'Heart rate through your waking day, as a share of your range '
                  'between resting and maximum heart rate, counted above '
                  'your own quiet level.',
          l?.howStrainData ??
              'One day at a time. It needs 3 earlier days to learn your '
                  'quiet level; before that the grey number uses a general '
                  'one. Time without the band adds nothing.',
          l?.howStrainLimits ??
              'It only sees cardiovascular effort, so lifting weights '
                  'scores low. Maximum heart rate comes from your age '
                  'unless a higher one has been observed.',
          today?.strain,
        ),
        metric(
          l?.homeRingSleep ?? 'Sleep',
          measured,
          'h min',
          l?.howSleepWhat ??
              'When you fell asleep and woke comes from wrist movement, '
                  'checked against heart rate. Stages are estimated from '
                  'heart rate and movement.',
          l?.howSleepData ??
              'One night. You can correct the times, and your correction '
                  'always wins.',
          l?.howSleepLimits ??
              'Stages from the wrist are rough, so they are shown as a '
                  'range. Lying still while awake can count as sleep.',
          today?.sleep,
        ),
        metric(
          '${l?.homeDriverHrv ?? 'HRV'} · ${l?.homeDriverRhr ?? 'Resting heart rate'}',
          measured,
          'ms · bpm',
          l?.howHrvWhat ??
              'HRV is RMSSD over 5-minute windows of your sleep, averaged. '
                  'Resting heart rate is your lowest 30-minute average '
                  'while asleep.',
          l?.howHrvData ??
              'Both need a detected night with enough clean beats; without '
                  'one they stay empty.',
          l?.howHrvLimits ??
              'Measured optically at the wrist, so movement and a loose '
                  'band add noise.',
          today?.vitals,
        ),
        Text(
          l?.howComputedVersion(kAlgoVersion) ??
              'Algorithm version $kAlgoVersion',
          style: F.cap.copyWith(color: p.ink3),
        ),
      ],
    );
  }
}
