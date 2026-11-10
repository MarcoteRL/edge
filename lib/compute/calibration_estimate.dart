// CALIBRATION ESTIMATES — what Recovery and Strain show before they have a
// personal baseline (fork decision, owner request, 2026-11-10).
//
// The real Recovery needs 14 nights of the user's own history per input and
// the real Strain a personal quiet-waking level from 3 prior days; until then
// both are absent with the `need_baseline:` grammar, which is honest and means
// a new user sees nothing for two weeks. WHOOP greys out a provisional score
// from the first night instead, and the owner asked for the same.
//
// So these are ESTIMATES, and are only ever shown as such:
//   * never written to `metric_series`, `day_result` or any baseline — they
//     are computed at read time from values already stored, so they can't
//     pollute the history the real score will be built on;
//   * never pinned as the day's headline, never notified, never charted;
//   * shown greyed with "calibrating" and how many nights are in.
//
// Recovery: each input (nightly ln RMSSD, sleeping resting HR, breathing rate)
// is compared against a centre and spread that START at a generic adult
// reference and move to the user's own nights as they arrive — a weighted
// blend in which the reference counts as [kCalibrationPriorNights] nights, so
// by night 7 the user's own history already carries 70 % of it. The oriented
// z's combine with the composite's own weights and logistic map, z capped at
// ±2 because the spread is a guess. Strain: the same 0–21 net-TRIMP score the
// real one uses, priced against the population quiet-waking level instead of
// the user's.
import 'dart:math' as math;

import 'package:openstrap_analytics/onehz.dart' as ana;

/// How many nights the generic reference is worth in the blend.
const double kCalibrationPriorNights = 3;

/// Generic adult references for the overnight inputs: centre and spread.
/// Deliberately wide — between-person spread, not night-to-night — so a night
/// far from "average adult" moves the estimate gently rather than to an end.
/// ln RMSSD ≈ 47 ms nocturnal mean; sleeping resting HR; breaths/min.
const ({double centre, double spread}) kRefLnRmssd = (centre: 3.85, spread: 0.50);
const ({double centre, double spread}) kRefRhr = (centre: 57, spread: 8);
const ({double centre, double spread}) kRefResp = (centre: 14.5, spread: 2.0);

/// Cap on each oriented z: the spread is partly assumed, so no single input
/// may push the estimate to an end.
const double kCalibrationZCap = 2.0;

/// The blended centre/spread for one input: the reference worth
/// [kCalibrationPriorNights] nights, plus the user's own [history].
({double centre, double spread}) blendedBaseline(
  List<double> history,
  ({double centre, double spread}) ref,
) {
  final n = history.length.toDouble();
  const k = kCalibrationPriorNights;
  if (n == 0) return ref;
  final mean = history.reduce((a, b) => a + b) / n;
  final variance = n < 2
      ? 0.0
      : history.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
          (n - 1);
  final centre = (k * ref.centre + n * mean) / (k + n);
  final spread = math.sqrt(
      (k * ref.spread * ref.spread + n * variance) / (k + n));
  return (centre: centre, spread: math.max(spread, 1e-6));
}

/// A provisional Recovery 0–100 while the real one is calibrating, or null
/// when neither autonomic input (HRV, resting HR) was measured tonight — the
/// estimate is never built from breathing alone.
double? calibratingRecovery({
  double? rmssdMs,
  List<double> rmssdHistoryMs = const [],
  double? restingHr,
  List<double> restingHrHistory = const [],
  double? respRate,
  List<double> respHistory = const [],
}) {
  final ln = rmssdMs != null && rmssdMs > 0 ? math.log(rmssdMs) : null;
  if (ln == null && restingHr == null) return null;
  final parts = <({double z, double w})>[];
  void add(double? v, List<double> hist,
      ({double centre, double spread}) ref, int goodSign, double w) {
    if (v == null) return;
    final b = blendedBaseline(hist, ref);
    final z = (goodSign * (v - b.centre) / b.spread)
        .clamp(-kCalibrationZCap, kCalibrationZCap)
        .toDouble();
    parts.add((z: z, w: w));
  }

  // Same signs and weights as the real composite's inputs.
  final hrv = ana.hrvInput(ln, const []);
  final rhr = ana.rhrInput(restingHr, const []);
  final resp = ana.respInput(respRate, const []);
  add(ln, [
    for (final r in rmssdHistoryMs)
      if (r > 0) math.log(r)
  ], kRefLnRmssd, hrv.goodSign, hrv.weight);
  add(restingHr, restingHrHistory, kRefRhr, rhr.goodSign, rhr.weight);
  add(respRate, respHistory, kRefResp, resp.goodSign, resp.weight);
  final wSum = parts.fold(0.0, (a, p) => a + p.w);
  if (wSum <= 0) return null;
  final z = parts.fold(0.0, (a, p) => a + p.z * p.w) / wSum;
  return 100 / (1 + math.exp(-z));
}

/// A provisional 0–21 Strain while the personal quiet-waking level is still
/// calibrating: the real scorer over the same wake minutes, priced at the
/// population quiet level. Null when an input the real one needs is missing.
double? calibratingStrain({
  required List<double> wakeHrPerMin,
  required double? restingHr,
  required double? maxHr,
  required bool female,
}) {
  if (wakeHrPerMin.isEmpty || restingHr == null || maxHr == null) return null;
  final m = ana.strainScoreFromSeries(
    wakeHrPerMin,
    restingHr: restingHr,
    maxHr: maxHr,
    quietHrr: ana.quietWakingHrr,
    sex: female ? ana.Sex.female : ana.Sex.male,
    quietSettled: false,
  );
  return m.present ? m.value : null;
}
