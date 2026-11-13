// FORK MODULE — a conscious exception to AGENTS §1 (DECISIONS.md D-15).
//
// "How am I evolving?" over the scalars the pipeline already stores. These
// are new decision rules, and upstream's rule is that a new metric belongs in
// `openstrap_analytics`. They live here instead while there is no history to
// validate them against, on these terms:
//
//   * PURE functions over values the caller hands in. Nothing here reads the
//     database, and nothing here is written to `day_result` or
//     `metric_series`: no kAlgoVersion bump, no golden moves.
//   * Built only from analytics primitives (`theilSen`, `robustBaseline`,
//     `mdc`, `median`, `stddev`) — no second copy of any of them.
//   * NEVER on the read seam's hot path (`getToday`). The bootstrap is
//     O(B·n²): callers go through `trend_service.dart`, which runs it in
//     `Isolate.run` and caches the answer, when a screen that shows it opens.
//   * EXIT: a rule that holds up over ≥ 60 real nights and is worth
//     persisting moves to a `MarcoteRL/analytics` fork, with a pin and a bump.
//
// Formulas, minimums and the evidence for each: docs/development/
// ALGORITHM_EVALUATION.md (ALG-T1, ALG-H1, ALG-S3) and research/REFERENCES.md.

import 'dart:math' as math;

import 'package:openstrap_analytics/onehz.dart' as ana;

/// One stored night/day of a metric: [day] is the local calendar day as a
/// day number (any epoch, consecutive days differ by 1), so gaps are visible
/// and a 23 h or 25 h day is still one step.
typedef TrendPoint = ({int day, double value});

/// The mean of the last [days] calendar days, or absent under [need] values.
class WindowMean {
  const WindowMean(this.days, this.need, this.have, this.mean);
  final int days;
  final int need;
  final int have;

  /// Null when [have] < [need]: never a mean of too few nights.
  final double? mean;
}

/// Theil–Sen slope over the slope window with its bootstrap interval.
class TrendSlope {
  const TrendSlope(this.perDay, this.lo, this.hi, this.n);

  /// Units of the metric per day.
  final double perDay;

  /// 95 % percentile-bootstrap bounds of [perDay].
  final double lo, hi;
  final int n;

  bool get excludesZero => lo > 0 || hi < 0;
}

/// The recent week against the four weeks before it.
class TrendChange {
  const TrendChange({
    required this.recent,
    required this.usual,
    required this.delta,
    required this.lo,
    required this.hi,
    required this.mdc,
    required this.swc,
  });

  /// Mean of the recent window; median of the reference window.
  final double recent, usual;

  /// `recent − usual`.
  final double delta;

  /// 95 % percentile-bootstrap bounds of [delta] (both windows resampled).
  final double lo, hi;

  bool get excludesZero => lo > 0 || hi < 0;

  /// Minimal detectable change of an n-night mean; null when the reference
  /// window has no dispersion to estimate noise from.
  final double? mdc;

  /// Smallest worthwhile change: 0.5 × SD of the reference window.
  final double swc;

  /// The bar [delta] has to clear; null when [mdc] is.
  double? get threshold => mdc == null ? null : math.max(mdc!, swc);
}

class Trend {
  const Trend({
    required this.means,
    required this.slope,
    required this.change,
    required this.relevant,
    required this.note,
  });

  /// 7 / 14 / 30 / 90 days, in that order.
  final List<WindowMean> means;

  /// Null under [kTrendSlopeMinPoints] values in the slope window.
  final TrendSlope? slope;

  /// Null when either window is too thin (see [note]).
  final TrendChange? change;

  /// TRUE only when the recent week sits beyond max(MDC, SWC) from the usual
  /// AND the bootstrap interval of that difference excludes zero. Null when
  /// it cannot be judged — which is not "no change".
  ///
  /// The interval is the DIFFERENCE's, not the slope's: Theil–Sen ignores up
  /// to ~29 % outlying points by design, so a real step in the last week
  /// leaves a 30-day slope's interval straddling zero for a fortnight. The
  /// slope answers "is there a sustained drift" ([TrendSlope.excludesZero])
  /// and is reported beside this, not folded into it (DECISIONS.md D-17).
  final bool? relevant;

  /// Why [relevant] is null: `need_baseline:have=H,need=N`, or
  /// [kTrendNoDispersion]. Null when it was judged.
  final String? note;
}

/// The usual window is flat (its MAD is zero), so there is no noise to
/// measure a change against.
const String kTrendNoDispersion = 'no_dispersion';

/// The day number of a `YYYY-MM-DD` local day label: calendar arithmetic in
/// UTC on the date alone, so consecutive labels always differ by exactly 1 —
/// across a 23 h or a 25 h day too. Null for anything else.
int? dayNumberOf(String label) {
  final d = DateTime.tryParse(label);
  if (d == null) return null;
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

/// Calendar windows reported, and the values each needs (≥ 60 % of its days,
/// and never fewer than 4: a week with three nights is not a week).
const List<(int, int)> kTrendWindows = [(7, 4), (14, 9), (30, 18), (90, 54)];

/// The slope looks at the last 30 days and needs half of them.
const int kTrendSlopeDays = 30;
const int kTrendSlopeMinPoints = 15;

/// "Recent" is the last 7 days (≥ 4 values); "usual" is the 28 days BEFORE
/// those (≥ 14 values). The usual never contains the recent week, so a bad
/// week cannot vouch for itself, and it is a median, so a few bad nights
/// inside it barely move it.
const int kTrendRecentDays = 7;
const int kTrendRecentMin = 4;
const int kTrendUsualDays = 28;
const int kTrendUsualMin = 14;

/// Bootstrap resamples. 500 keeps the 2.5 % / 97.5 % percentiles stable to
/// about a tenth of the interval's width and costs ~0.2 M pair slopes.
const int kTrendBootstrap = 500;

/// [series] can come in any order and may hold one value per day at most (a
/// repeated day keeps its last value — `metric_series` cannot repeat a day,
/// but a caller's join can). [today] is the day number the windows end on.
Trend trendOf(List<TrendPoint> series, {required int today, int seed = 1}) {
  final byDay = <int, double>{
    for (final p in series)
      if (p.value.isFinite && p.day <= today) p.day: p.value,
  };
  List<double> window(int from, int to) => [
    for (var d = from; d <= to; d++) ?byDay[d],
  ];

  WindowMean meanOver(int days, int need) {
    final v = window(today - days + 1, today);
    return WindowMean(days, need, v.length, v.length < need ? null : ana.mean(v));
  }

  final means = [for (final (days, need) in kTrendWindows) meanOver(days, need)];

  // ── slope ──────────────────────────────────────────────────────────────
  final sx = <double>[], sy = <double>[];
  for (var d = today - kTrendSlopeDays + 1; d <= today; d++) {
    final v = byDay[d];
    if (v != null) {
      sx.add(d.toDouble());
      sy.add(v);
    }
  }
  TrendSlope? slope;
  if (sy.length >= kTrendSlopeMinPoints) {
    final s = ana.theilSen(sy, sx);
    if (s != null) {
      final rng = math.Random(seed);
      final boots = <double>[];
      for (var b = 0; b < kTrendBootstrap; b++) {
        final bx = <double>[], by = <double>[];
        for (var i = 0; i < sy.length; i++) {
          final k = rng.nextInt(sy.length);
          bx.add(sx[k]);
          by.add(sy[k]);
        }
        final bs = ana.theilSen(by, bx);
        if (bs != null) boots.add(bs);
      }
      if (boots.length >= kTrendBootstrap ~/ 2) {
        boots.sort();
        slope = TrendSlope(
          s,
          ana.percentileSorted(boots, 2.5)!,
          ana.percentileSorted(boots, 97.5)!,
          sy.length,
        );
      }
    }
  }

  // ── recent week against the usual ──────────────────────────────────────
  final recent = window(today - kTrendRecentDays + 1, today);
  final usual = window(
      today - kTrendRecentDays - kTrendUsualDays + 1, today - kTrendRecentDays);
  if (recent.length < kTrendRecentMin) {
    return Trend(
      means: means,
      slope: slope,
      change: null,
      relevant: null,
      note: ana.needBaselineNote(have: recent.length, need: kTrendRecentMin),
    );
  }
  if (usual.length < kTrendUsualMin) {
    return Trend(
      means: means,
      slope: slope,
      change: null,
      relevant: null,
      note: ana.needBaselineNote(have: usual.length, need: kTrendUsualMin),
    );
  }
  final base = ana.robustBaseline(usual, minValid: kTrendUsualMin);
  final recentMean = ana.mean(recent)!;
  final rng = math.Random(seed + 1);
  List<double> resample(List<double> v) =>
      [for (var i = 0; i < v.length; i++) v[rng.nextInt(v.length)]];
  final deltas = [
    for (var b = 0; b < kTrendBootstrap; b++)
      ana.mean(resample(recent))! - ana.median(resample(usual))!,
  ]..sort();
  final change = TrendChange(
    recent: recentMean,
    usual: base.center!,
    delta: recentMean - base.center!,
    lo: ana.percentileSorted(deltas, 2.5)!,
    hi: ana.percentileSorted(deltas, 97.5)!,
    // The noise of a mean of n nights, not of one night: typical error / √n.
    mdc: base.scale == null
        ? null
        : ana.mdc(base, typicalError: base.scale! / math.sqrt(recent.length)),
    swc: 0.5 * (ana.stddev(usual) ?? 0),
  );
  // A flat (fully quantized) usual has no noise estimate: nothing can be
  // called a change against it, in either direction.
  final bar = change.threshold;
  final relevant =
      bar == null ? null : change.delta.abs() > bar && change.excludesZero;
  final note = bar == null ? kTrendNoDispersion : null;
  return Trend(
    means: means,
    slope: slope,
    change: change,
    relevant: relevant,
    note: note,
  );
}

// ── ALG-P1 · two stretches of your own choosing ───────────────────────────

/// [days] calendar days before a date against the [days] from it on.
class PeriodChange {
  const PeriodChange({
    required this.before,
    required this.after,
    this.delta,
    this.lo,
    this.hi,
    this.threshold,
    this.relevant,
    this.note,
  });

  /// Each period's mean; absent under its minimum of values.
  final WindowMean before, after;

  /// `after − before`; null when either mean is.
  final double? delta;

  /// 95 % percentile-bootstrap bounds of [delta] (both periods resampled).
  final double? lo, hi;

  /// The bar [delta] has to clear: the larger of 1.96 standard errors of a
  /// difference of two means (pooled SD) and half the SD of the period
  /// before. Null when it cannot be estimated.
  final double? threshold;

  /// TRUE only when [delta] clears [threshold] AND its interval excludes
  /// zero. Null when it cannot be judged — which is not "no change".
  final bool? relevant;

  /// Why [relevant] is null: `need_baseline:have=H,need=N` for the thinner
  /// period, or [kTrendNoDispersion]. Null when it was judged.
  final String? note;
}

/// Values a period of [days] calendar days needs: 60 % of them, never under 4
/// (the convention of [kTrendWindows]).
int periodMinValues(int days) => math.max(4, (days * 0.6).round());

/// The [days] calendar days ending the day before [split] against the [days]
/// starting on [split]. A description of two stretches of one person's data:
/// it says whether they differ beyond night-to-night noise, never why. Nights
/// are treated as independent, which they are not quite; the bar is the
/// larger of two rules for that reason.
PeriodChange periodChange(
  List<TrendPoint> series, {
  required int split,
  required int days,
  int seed = 1,
}) {
  final byDay = <int, double>{
    for (final p in series)
      if (p.value.isFinite) p.day: p.value,
  };
  List<double> window(int from, int to) => [
    for (var d = from; d <= to; d++) ?byDay[d],
  ];
  final need = periodMinValues(days);
  final a = window(split - days, split - 1);
  final b = window(split, split + days - 1);
  WindowMean of(List<double> v) =>
      WindowMean(days, need, v.length, v.length < need ? null : ana.mean(v));
  final before = of(a), after = of(b);
  final ma = before.mean, mb = after.mean;
  if (ma == null || mb == null) {
    final thin = ma == null ? a : b;
    return PeriodChange(
      before: before,
      after: after,
      note: ana.needBaselineNote(have: thin.length, need: need),
    );
  }
  final delta = mb - ma;
  final sa = ana.stddev(a) ?? 0, sb = ana.stddev(b) ?? 0;
  final pooled = math.sqrt(
    ((a.length - 1) * sa * sa + (b.length - 1) * sb * sb) /
        (a.length + b.length - 2),
  );
  // Two flat stretches have no noise to measure a difference against.
  if (!(pooled > 0)) {
    return PeriodChange(
      before: before,
      after: after,
      delta: delta,
      note: kTrendNoDispersion,
    );
  }
  final rng = math.Random(seed);
  List<double> resample(List<double> v) =>
      [for (var i = 0; i < v.length; i++) v[rng.nextInt(v.length)]];
  final deltas = [
    for (var i = 0; i < kTrendBootstrap; i++)
      ana.mean(resample(b))! - ana.mean(resample(a))!,
  ]..sort();
  final lo = ana.percentileSorted(deltas, 2.5)!;
  final hi = ana.percentileSorted(deltas, 97.5)!;
  final bar = math.max(
    1.96 * pooled * math.sqrt(1 / a.length + 1 / b.length),
    0.5 * sa,
  );
  return PeriodChange(
    before: before,
    after: after,
    delta: delta,
    lo: lo,
    hi: hi,
    threshold: bar,
    relevant: delta.abs() > bar && (lo > 0 || hi < 0),
  );
}

// ── ALG-H1 · night-to-night HRV stability ─────────────────────────────────

/// Coefficient of variation (%) of lnRMSSD across the last 7 nights:
/// `100 · SD / mean`. Null under 5 nights, or when the mean is not positive
/// (ln of an RMSSD under 1 ms — not a night worth a ratio).
///
/// Only nights measured the same way belong in [lnRmssd]: wrist PRV and a
/// chest strap's RR are different quantities (the caller filters by
/// `metric_method`).
double? lnRmssdCv7(List<double> lnRmssd) {
  if (lnRmssd.length < kCv7MinNights || lnRmssd.length > 7) return null;
  final m = ana.mean(lnRmssd), sd = ana.stddev(lnRmssd);
  if (m == null || sd == null || m <= 0) return null;
  return 100 * sd / m;
}

const int kCv7MinNights = 5;

// ── ALG-S3 · schedule consistency ─────────────────────────────────────────

/// Circular standard deviation, in minutes, of clock times given as minutes
/// after local midnight (bedtimes or wake times of the last 7 nights). Null
/// under 5 nights.
///
/// Circular because 23:50 and 00:10 are twenty minutes apart, not 1420:
/// `R = |mean of e^{iθ}|`, `SD = √(−2 ln R)` radians, scaled to a 1440-minute
/// day. Clock time is the wall clock the night was lived on, so a 23 h or
/// 25 h day needs no correction here.
double? scheduleSdMin(List<double> clockMin) {
  if (clockMin.length < kScheduleMinNights) return null;
  var c = 0.0, s = 0.0;
  for (final m in clockMin) {
    final a = 2 * math.pi * (m % 1440) / 1440;
    c += math.cos(a);
    s += math.sin(a);
  }
  final r = math.sqrt(c * c + s * s) / clockMin.length;
  // Times spread evenly round the clock have no mean direction (R → 0) and
  // no meaningful spread either.
  if (r < 1e-9) return null;
  return math.sqrt(-2 * math.log(math.min(1, r))) * 1440 / (2 * math.pi);
}

const int kScheduleMinNights = 5;
