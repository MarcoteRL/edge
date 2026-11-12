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
    final call = switch (band.tier) {
      3 => l?.homeDecisionGood ?? 'A good day for intensity',
      2 => l?.homeDecisionSteady ?? 'A normal day: train as planned',
      1 => l?.homeDecisionEasy ?? 'Keep it light today',
      _ => l?.homeDecisionRest ?? 'A day to recover',
    };
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

class _HomeEvolutionState extends State<HomeEvolution> {
  List<fork.Trend>? _trends;

  static const _keys = ['ln_rmssd', 'rhr', 'tst_min'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final out = <fork.Trend>[];
      for (final k in _keys) {
        out.add(await TrendService.of(k));
      }
      if (mounted) setState(() => _trends = out);
    } catch (_) {
      // No database (a test host, a locked store): nothing to show.
    }
  }

  @override
  Widget build(BuildContext c) {
    final t = _trends;
    if (t == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(c);
    // lnRMSSD differences read as a percentage of RMSSD: e^Δ − 1.
    String hrv(double d) => signed(
        d, '${displayFixed(((math.exp(d.abs()) - 1) * 100).clamp(0, 999), 0)} %');
    final bpmUnit = l?.activityZonesBpmUnit ?? 'bpm';
    String bpm(double d) => signed(d, '${displayFixed(d.abs(), 1)} $bpmUnit');
    String sleep(double d) => signed(d, hm(d.abs()));
    EvolutionRow row(String label, fork.Trend tr, String Function(double) f) =>
        (
          label: label,
          relevant: tr.relevant,
          delta: tr.change == null ? '' : f(tr.change!.delta),
        );
    return Section(
      l?.homeEvolutionTitle ?? "How you're evolving",
      EvolutionCard([
        row(l?.homeDriverHrv ?? 'HRV', t[0], hrv),
        row(l?.homeDriverRhr ?? 'Resting heart rate', t[1], bpm),
        row(l?.homeRingSleep ?? 'Sleep', t[2], sleep),
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

/// A plain page: for each headline number, whether it is measured, derived
/// or estimated, what goes into it, the window it looks at and what it does
/// with missing data, and where it stops being trustworthy. Static text and
/// the running algorithm version; it reads nothing.
class HowComputedScreen extends StatelessWidget {
  const HowComputedScreen({super.key});

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
            String data, String limits) =>
        Padding(
          padding: const EdgeInsets.only(bottom: S.x4),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: F.head.copyWith(color: p.ink)),
                const SizedBox(height: S.x1),
                Text('$kind · $unit', style: F.cap.copyWith(color: p.ink3)),
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
