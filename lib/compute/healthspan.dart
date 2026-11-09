// healthspan.dart — FORK MODULE (MarcoteRL/edge, not upstream).
//
// An estimated physiological age in the spirit of WHOOP's Healthspan: your age,
// moved by how far a few measured habits sit from a population reference, each
// translated into years through the mortality evidence behind it.
//
// Per AGENTS.md a new metric belongs in OpenStrap/analytics. The fork owner
// chose to keep it here instead (no sibling fork, no repin), so it is a pure,
// isolate-safe function over values edge already stores, computed on read and
// never persisted: no day_result field, no kAlgoVersion bump. Moving it to
// analytics later is a straight copy.
//
// THE MODEL, AND EVERY NUMBER IN IT
//
//   years(RR) = 8 · log2(RR)
//     Gompertz: adult all-cause mortality roughly doubles every ~8 years
//     (mortality-rate doubling time 7–9 y), so a risk ratio is worth the age
//     gap that would produce the same change in hazard.
//
//   Fitness — VO2max against the FRIEND treadmill 50th percentile for your age
//     and sex (Kaminsky, Arena & Myers 2015, Mayo Clin Proc 90:1515, Table 3),
//     1 MET = 3.5 mL/kg/min, RR 0.87 per 1-MET higher fitness (Kodama et al.
//     2009, JAMA 301:2024).
//
//   Sleep regularity — SRI against the UK Biobank median 81.0, per +1 SD
//     (10.7) an 18.7 % lower adjusted hazard, RR 0.813 (Windred et al., Sleep
//     2024;47:zsad253, and its 2022 Sleep Advances abstract O020).
//
//   Sleep duration — mean nightly sleep: under 6 h RR 1.12, 9 h or more RR
//     1.30, otherwise 1.0 (Cappuccio et al. 2010, Sleep 33:585).
//
// DELIBERATELY LEFT OUT
//   * Resting heart rate. The band's is a nocturnal minimum, not the seated
//     clinical value the cohorts measured, so placing it against their
//     reference would be a guess. Upstream also deleted an older age function
//     for counting RHR twice (see the v-notes in derivation_engine.dart).
//   * Steps. The dose-response is real (Banach 2023), but its reference is the
//     least-active quartile, with no population-neutral point, so almost
//     everyone would read "younger".
//
// HONESTY RULES (AGENTS.md §3.3)
//   * No age or no sex, or an age outside the FRIEND range: no estimate.
//   * A pillar with no data is ABSENT, never zero, and fewer than two present
//     pillars means no estimate at all.
//   * Each pillar is clamped to the range its evidence covers.
//   ponytail: pillars are summed as if independent, but regularity and
//   duration overlap (Windred compared them in nested models). The ceiling is
//   a few years of double counting; the upgrade is one joint model from a
//   cohort that measured all three.

import 'dart:math' as math;

const double kMortalityDoublingYears = 8.0;

/// Gompertz: the age gap whose change in hazard equals [riskRatio].
double yearsFromRiskRatio(double riskRatio) =>
    kMortalityDoublingYears * math.log(riskRatio) / math.ln2;

/// FRIEND 2015 treadmill 50th percentile VO2max (mL/kg/min) by decade
/// 20–29 … 70–79 (Kaminsky 2015, Table 3).
const List<double> kFriendMenP50 = [48.0, 42.4, 37.8, 32.6, 28.2, 24.4];
const List<double> kFriendWomenP50 = [37.6, 30.2, 26.7, 23.4, 20.0, 18.3];

const int kHealthspanMinAge = 20;
const int kHealthspanMaxAge = 79;

/// The reference VO2max for [age] and [sex] ('m' | 'f'), interpolated between
/// decade midpoints (25, 35 … 75) and held flat at the ends. Null outside
/// 20–79 or for any other sex value.
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
  final t = pos - i;
  return table[i] + (table[i + 1] - table[i]) * t;
}

const double kMlPerMet = 3.5;
const double kFitnessRrPerMet = 0.87; // Kodama 2009
const double kFitnessMaxMets = 4.0; // ~low-to-high CRF span in Kodama's bands

const double kSriReference = 81.0; // Windred 2024, UK Biobank median
const double kSriSd = 10.7;
const double kSriRrPerSd = 0.813; // Windred, adjusted 18.7 % per +1 SD
const double kSriMaxSd = 2.0;

const double kShortSleepHours = 6.0;
const double kLongSleepHours = 9.0;
const double kShortSleepRr = 1.12; // Cappuccio 2010
const double kLongSleepRr = 1.30;
const int kSleepMinNights = 7;

enum HealthspanPillarKind { fitness, sleepRegularity, sleepDuration }

class HealthspanPillar {
  final HealthspanPillarKind kind;

  /// Years this pillar moves the estimate: negative is younger.
  final double years;

  /// The measured value it came from (mL/kg/min, SRI, hours).
  final double value;

  /// The population reference it was placed against, in the same unit.
  final double reference;

  const HealthspanPillar(this.kind, this.years, this.value, this.reference);
}

class HealthspanEstimate {
  final int age;
  final List<HealthspanPillar> pillars;

  const HealthspanEstimate(this.age, this.pillars);

  double get years => pillars.fold(0.0, (s, p) => s + p.years);
  double get physiologicalAge => age + years;
}

/// Why no estimate, or which inputs are missing from an estimate that exists.
enum HealthspanGap { age, sex, ageRange, fitness, sleepRegularity, sleepDuration }

HealthspanPillar? fitnessPillar(double? vo2max, int age, String sex) {
  final ref = friendVo2maxMedian(age, sex);
  if (vo2max == null || ref == null || !vo2max.isFinite || vo2max <= 0) {
    return null;
  }
  final mets =
      ((vo2max - ref) / kMlPerMet).clamp(-kFitnessMaxMets, kFitnessMaxMets);
  return HealthspanPillar(HealthspanPillarKind.fitness,
      yearsFromRiskRatio(math.pow(kFitnessRrPerMet, mets).toDouble()), vo2max,
      ref);
}

HealthspanPillar? sleepRegularityPillar(double? sri) {
  if (sri == null || !sri.isFinite) return null;
  final sd = ((sri - kSriReference) / kSriSd).clamp(-kSriMaxSd, kSriMaxSd);
  return HealthspanPillar(HealthspanPillarKind.sleepRegularity,
      yearsFromRiskRatio(math.pow(kSriRrPerSd, sd).toDouble()), sri,
      kSriReference);
}

HealthspanPillar? sleepDurationPillar(List<double> nightlySleepMin) {
  final nights = [
    for (final m in nightlySleepMin)
      if (m.isFinite && m > 0) m
  ];
  if (nights.length < kSleepMinNights) return null;
  final hours = nights.reduce((a, b) => a + b) / nights.length / 60.0;
  final rr = hours < kShortSleepHours
      ? kShortSleepRr
      : hours >= kLongSleepHours
          ? kLongSleepRr
          : 1.0;
  return HealthspanPillar(HealthspanPillarKind.sleepDuration,
      yearsFromRiskRatio(rr), hours, (kShortSleepHours + kLongSleepHours) / 2);
}

/// The estimate, or null with the reasons in [gaps]. [gaps] is also filled
/// with the missing pillars when an estimate exists, so a screen can say what
/// would sharpen it.
HealthspanEstimate? estimateHealthspan({
  required int? age,
  required String? sex,
  double? vo2max,
  double? sri,
  List<double> nightlySleepMin = const [],
  List<HealthspanGap>? gaps,
}) {
  final g = gaps ?? <HealthspanGap>[];
  if (age == null) g.add(HealthspanGap.age);
  if (sex != 'm' && sex != 'f') g.add(HealthspanGap.sex);
  if (age != null && (age < kHealthspanMinAge || age > kHealthspanMaxAge)) {
    g.add(HealthspanGap.ageRange);
  }
  if (g.isNotEmpty) return null;
  final pillars = <HealthspanPillar>[];
  void add(HealthspanPillar? p, HealthspanGap gap) =>
      p == null ? g.add(gap) : pillars.add(p);
  add(fitnessPillar(vo2max, age!, sex!), HealthspanGap.fitness);
  add(sleepRegularityPillar(sri), HealthspanGap.sleepRegularity);
  add(sleepDurationPillar(nightlySleepMin), HealthspanGap.sleepDuration);
  return pillars.length < 2 ? null : HealthspanEstimate(age, pillars);
}
