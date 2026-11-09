// healthspan.dart — FORK MODULE (MarcoteRL/edge, not upstream).
//
// An estimated physiological age built the way WHOOP describes Healthspan:
// the same nine contributors, six months of data, a break-even point at the
// public-health guideline for each one (meet it and that contributor adds no
// years), and Gompertz's law to turn a risk ratio into years. WHOOP's own
// coefficients are not published, so every curve here comes from a cited paper
// and is written next to it. Pure and isolate-safe; computed on read, never
// persisted, no kAlgoVersion bump. Per AGENTS.md a metric belongs in
// OpenStrap/analytics; the fork owner chose to keep it in edge.
//
//   years(RR) = 8 · log2(RR)   adult all-cause mortality doubles every ~8 y
//
// CONTRIBUTORS (break-even → source)
//   1 Sleep consistency  SRI 81, UK Biobank median; RR 0.813 per +10.7
//                        (1 SD), Windred et al., Sleep 2024
//   2 Hours of sleep     6–9 h neutral; <6 h RR 1.12, >=9 h RR 1.30,
//                        Cappuccio et al., Sleep 2010
//   3 Zones 1–3 / week   150 min (guideline). vs none: 150–299 RR 0.795,
//                        300–599 RR 0.715, flat from 600. Lee et al., Circ 2022
//   4 Zones 4–5 / week   75 min (guideline). vs none: 75–149 HR 0.81, 150–299
//                        RR 0.78, flat from 300. Lee et al., Circ 2022
//   5 Strength / week    30 min. vs none: lowest RR 0.83 at 40 min, held flat
//                        beyond (J-shape ignored). Momma et al., BJSM 2022
//   6 Steps / day        8,000 (WHOOP's stated target). Quartile medians
//                        3,967 / 5,537 / 7,370 / 11,529 steps carry RR 1 /
//                        0.52 / 0.45 / 0.33. Banach et al., EJPC 2023
//   7 VO2max             FRIEND p50 for age and sex (Kaminsky 2015);
//                        RR 0.87 per MET (Kodama, JAMA 2009). From GPS runs
//                        when there are any in 90 days, else the
//                        non-exercise model of Jackson et al. 1990 (age,
//                        sex, BMI, PA-R scored from your measured minutes).
//   8 Resting HR         60 bpm; RR 1.09 per +10 bpm (Zhang et al., CMAJ
//                        2016). The band's is a nocturnal minimum, which runs
//                        lower than a seated clinical reading, so this
//                        contributor leans young. Shown as such.
//   9 Lean body mass     needs a body-composition scale; absent otherwise.
//
// HONESTY (AGENTS.md §3.3): no age/sex or age outside 20–79 → no estimate;
// a contributor without data is ABSENT, never zero; fewer than three present
// → no estimate; every input is clamped to the range its evidence covers.
// ponytail: contributors are summed as if independent (WHOOP does the same).
// The ceiling is some double counting between correlated habits; the upgrade
// is one joint model from a cohort that measured them together.

import 'dart:math' as math;

const double kMortalityDoublingYears = 8.0;

double yearsFromRiskRatio(double riskRatio) =>
    kMortalityDoublingYears * math.log(riskRatio) / math.ln2;

/// RR at [x] on a curve given as (x, RR) points, log-linear between points
/// and held flat outside them.
double rrOnCurve(List<(double, double)> pts, double x) {
  if (x <= pts.first.$1) return pts.first.$2;
  if (x >= pts.last.$1) return pts.last.$2;
  for (var i = 0; i < pts.length - 1; i++) {
    final (x0, r0) = pts[i];
    final (x1, r1) = pts[i + 1];
    if (x <= x1) {
      final t = (x - x0) / (x1 - x0);
      return math.exp(math.log(r0) + (math.log(r1) - math.log(r0)) * t);
    }
  }
  return pts.last.$2;
}

/// Years for [x] on [pts], relative to the break-even [ref].
double yearsVsBreakEven(List<(double, double)> pts, double x, double ref) =>
    yearsFromRiskRatio(rrOnCurve(pts, x) / rrOnCurve(pts, ref));

// ── 7 VO2max ────────────────────────────────────────────────────────────────

const List<double> kFriendMenP50 = [48.0, 42.4, 37.8, 32.6, 28.2, 24.4];
const List<double> kFriendWomenP50 = [37.6, 30.2, 26.7, 23.4, 20.0, 18.3];
const int kHealthspanMinAge = 20;
const int kHealthspanMaxAge = 79;

double? friendVo2maxMedian(int age, String sex) {
  final table = switch (sex) {
    'm' => kFriendMenP50,
    'f' => kFriendWomenP50,
    _ => null,
  };
  if (table == null || age < kHealthspanMinAge || age > kHealthspanMaxAge) {
    return null;
  }
  final pos = ((age - 25) / 10).clamp(0.0, (table.length - 1).toDouble());
  final i = pos.floor();
  if (i >= table.length - 1) return table.last;
  return table[i] + (table[i + 1] - table[i]) * (pos - i);
}

const double kMlPerMet = 3.5;
const double kFitnessRrPerMet = 0.87;
const double kFitnessMaxMets = 4.0;

/// NASA/JSC PA-R (0–7) scored from MEASURED weekly minutes rather than asked:
/// zones 4–5 stand in for "running or comparable", zones 1–3 for "modest
/// activity". Jackson's scale: 2 = 10–60 min/wk modest, 3 = >1 h/wk modest,
/// 4 = <30 min/wk vigorous, 5 = 30–60, 6 = 1–3 h, 7 = >3 h.
int physicalActivityRating(double moderateMinPerWeek, double vigorousMinPerWeek) {
  final v = vigorousMinPerWeek, m = moderateMinPerWeek;
  if (v > 180) return 7;
  if (v >= 60) return 6;
  if (v >= 30) return 5;
  if (v > 0) return 4;
  if (m > 60) return 3;
  if (m >= 10) return 2;
  return m > 0 ? 1 : 0;
}

/// Jackson et al. 1990 non-exercise model (BMI form), mL/kg/min.
double jacksonVo2max(
        {required int age,
        required String sex,
        required double bmi,
        required int par}) =>
    56.363 + 1.921 * par - 0.381 * age - 0.754 * bmi + (sex == 'm' ? 10.987 : 0);

// ── the contributors ────────────────────────────────────────────────────────

enum HealthspanKind {
  sleepConsistency,
  sleepHours,
  zones13,
  zones45,
  strength,
  steps,
  vo2max,
  restingHr,
  leanMass,
}

class HealthspanPillar {
  final HealthspanKind kind;
  final double years; // negative = younger
  final double value;
  final double breakEven;

  /// VO2max only: true when it came from the non-exercise model.
  final bool estimated;

  const HealthspanPillar(this.kind, this.years, this.value, this.breakEven,
      {this.estimated = false});
}

const double kSriBreakEven = 81.0, kSriSd = 10.7, kSriRrPerSd = 0.813;
const double kStepsBreakEven = 8000;
const List<(double, double)> kStepsCurve = [
  (3967, 1.0), (5537, 0.52), (7370, 0.45), (11529, 0.33),
];
const double kModerateBreakEven = 150;
const List<(double, double)> kModerateCurve = [
  (0, 1.0), (150, 0.795), (300, 0.715), (600, 0.715),
];
const double kVigorousBreakEven = 75;
const List<(double, double)> kVigorousCurve = [
  (0, 1.0), (75, 0.81), (150, 0.78), (300, 0.78),
];
const double kStrengthBreakEven = 30;
const List<(double, double)> kStrengthCurve = [(0, 1.0), (40, 0.83)];
const double kRhrBreakEven = 60, kRhrRrPer10 = 1.09;
const int kMinNights = 7, kMinDays = 14;

/// Everything the estimate reads, for one six-month window.
typedef HealthspanData = ({
  int? age,
  String? sex,
  double? weightKg,
  double? heightCm,
  double? gpsVo2max,
  double? sri,
  List<double> sleepMin,
  List<double> stepsDaily,
  List<double> rhrNightly,
  double? moderateMinPerWeek,
  double? vigorousMinPerWeek,
  double? strengthMinPerWeek,
});

double? _mean(List<double> xs, int min) {
  final v = [for (final x in xs) if (x.isFinite && x > 0) x];
  return v.length < min ? null : v.reduce((a, b) => a + b) / v.length;
}

HealthspanPillar? _sleepConsistency(double? sri) {
  if (sri == null || !sri.isFinite) return null;
  final sd = ((sri - kSriBreakEven) / kSriSd).clamp(-2.0, 2.0);
  return HealthspanPillar(HealthspanKind.sleepConsistency,
      yearsFromRiskRatio(math.pow(kSriRrPerSd, sd).toDouble()), sri,
      kSriBreakEven);
}

HealthspanPillar? _sleepHours(List<double> sleepMin) {
  final m = _mean(sleepMin, kMinNights);
  if (m == null) return null;
  final h = m / 60;
  final rr = h < 6 ? 1.12 : (h >= 9 ? 1.30 : 1.0);
  return HealthspanPillar(
      HealthspanKind.sleepHours, yearsFromRiskRatio(rr), h, 7.5);
}

HealthspanPillar? _curve(HealthspanKind k, double? x,
        List<(double, double)> pts, double breakEven) =>
    x == null || !x.isFinite
        ? null
        : HealthspanPillar(k, yearsVsBreakEven(pts, x, breakEven), x, breakEven);

HealthspanPillar? _vo2(HealthspanData d) {
  final ref = friendVo2maxMedian(d.age!, d.sex!);
  if (ref == null) return null;
  var vo2 = d.gpsVo2max;
  var estimated = false;
  if (vo2 == null &&
      d.weightKg != null &&
      d.heightCm != null &&
      d.heightCm! > 0 &&
      d.moderateMinPerWeek != null &&
      d.vigorousMinPerWeek != null) {
    final bmi = d.weightKg! / math.pow(d.heightCm! / 100, 2);
    vo2 = jacksonVo2max(
        age: d.age!,
        sex: d.sex!,
        bmi: bmi,
        par: physicalActivityRating(
            d.moderateMinPerWeek!, d.vigorousMinPerWeek!));
    estimated = true;
  }
  if (vo2 == null || !vo2.isFinite || vo2 <= 0) return null;
  final mets = ((vo2 - ref) / kMlPerMet).clamp(-kFitnessMaxMets, kFitnessMaxMets);
  return HealthspanPillar(HealthspanKind.vo2max,
      yearsFromRiskRatio(math.pow(kFitnessRrPerMet, mets).toDouble()), vo2, ref,
      estimated: estimated);
}

HealthspanPillar? _rhr(List<double> nightly) {
  final m = _mean(nightly, kMinNights);
  if (m == null) return null;
  final x = m.clamp(45.0, 90.0);
  return HealthspanPillar(
      HealthspanKind.restingHr,
      yearsFromRiskRatio(
          math.pow(kRhrRrPer10, (x - kRhrBreakEven) / 10).toDouble()),
      m,
      kRhrBreakEven);
}

class HealthspanEstimate {
  final int age;
  final List<HealthspanPillar> pillars;
  const HealthspanEstimate(this.age, this.pillars);
  double get years => pillars.fold(0.0, (s, p) => s + p.years);
  double get physiologicalAge => age + years;
}

enum HealthspanGap { age, sex, ageRange }

const int kHealthspanMinPillars = 3;

/// The estimate for one window, or null. [gaps] gets the blocking reasons;
/// [missing] gets the contributors with no data (lean mass always, until a
/// body-composition source exists).
HealthspanEstimate? estimateHealthspan(HealthspanData d,
    {List<HealthspanGap>? gaps, List<HealthspanKind>? missing}) {
  final g = gaps ?? <HealthspanGap>[];
  if (d.age == null) g.add(HealthspanGap.age);
  if (d.sex != 'm' && d.sex != 'f') g.add(HealthspanGap.sex);
  if (d.age != null &&
      (d.age! < kHealthspanMinAge || d.age! > kHealthspanMaxAge)) {
    g.add(HealthspanGap.ageRange);
  }
  if (g.isNotEmpty) return null;
  final all = <HealthspanKind, HealthspanPillar?>{
    HealthspanKind.sleepConsistency: _sleepConsistency(d.sri),
    HealthspanKind.sleepHours: _sleepHours(d.sleepMin),
    HealthspanKind.zones13: _curve(HealthspanKind.zones13,
        d.moderateMinPerWeek, kModerateCurve, kModerateBreakEven),
    HealthspanKind.zones45: _curve(HealthspanKind.zones45,
        d.vigorousMinPerWeek, kVigorousCurve, kVigorousBreakEven),
    HealthspanKind.strength: _curve(HealthspanKind.strength,
        d.strengthMinPerWeek, kStrengthCurve, kStrengthBreakEven),
    HealthspanKind.steps: _curve(HealthspanKind.steps,
        _mean(d.stepsDaily, kMinDays), kStepsCurve, kStepsBreakEven),
    HealthspanKind.vo2max: _vo2(d),
    HealthspanKind.restingHr: _rhr(d.rhrNightly),
    HealthspanKind.leanMass: null,
  };
  missing?.addAll([for (final e in all.entries) if (e.value == null) e.key]);
  final pillars = [for (final p in all.values) ?p];
  return pillars.length < kHealthspanMinPillars
      ? null
      : HealthspanEstimate(d.age!, pillars);
}

/// WHOOP's Pace of Aging: physiological years gained per calendar year,
/// from this window's estimate against the one [days] earlier. 1 = ageing at
/// the calendar's rate, 0 = holding still, below 0 = getting younger. Clamped
/// to WHOOP's −1…3 display range.
double? paceOfAging(HealthspanEstimate? now, HealthspanEstimate? before,
    {int days = 30}) {
  if (now == null || before == null) return null;
  final pace = 1 + (now.years - before.years) / (days / 365.25);
  return pace.clamp(-1.0, 3.0);
}
