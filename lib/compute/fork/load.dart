// FORK MODULE — see trends.dart for the terms (DECISIONS.md D-15): pure,
// read-time, never persisted, never on the read seam's hot path.
//
// Training load the heart-rate strain cannot see. Strain is cardiovascular
// (Banister TRIMP): a heavy lifting session barely moves it. These are the
// two published, arithmetic-only complements, kept SEPARATE from strain —
// never blended into the 0–21 number (DECISIONS.md D-09).

/// Session RPE load (Foster 2001): `RPE (CR-10) × minutes`, in arbitrary
/// units. Null without a rating — an unrated session has no sRPE, and a
/// default rating would be an invented one (AGENTS §3.3).
double? sessionRpeLoad({required double? rpe, required double durationMin}) {
  if (rpe == null || rpe < 0 || rpe > 10 || durationMin <= 0) return null;
  return rpe * durationMin;
}

/// The sRPE of a period: the sum over rated sessions, and how many sessions
/// had no rating. [total] is the whole period's load only when [unrated] is
/// 0; with any unrated session it is a floor and must be shown as one.
class RpeLoad {
  const RpeLoad(this.total, this.rated, this.unrated);
  final double? total;
  final int rated, unrated;
  bool get complete => rated > 0 && unrated == 0;
}

/// [sessions] as `(rpe, durationMin)`. No sessions ⇒ a null total: "nothing
/// logged" is not "zero load" unless the caller knows the period was rested.
RpeLoad rpeLoadOf(Iterable<(double?, double)> sessions) {
  var total = 0.0;
  var rated = 0, unrated = 0;
  for (final (rpe, min) in sessions) {
    final l = sessionRpeLoad(rpe: rpe, durationMin: min);
    if (l == null) {
      unrated++;
    } else {
      rated++;
      total += l;
    }
  }
  return RpeLoad(rated == 0 ? null : total, rated, unrated);
}

/// Volume load ("tonnage"): Σ reps × load (kg) over working sets, per key
/// (a muscle group). A set with no load — bodyweight, or simply not entered —
/// adds nothing and is COUNTED in [setsWithoutLoad], so a group trained with
/// push-ups reads "n sets, load not recorded", never "0 kg".
class Tonnage {
  const Tonnage(this.kg, this.setsWithLoad, this.setsWithoutLoad);
  final double kg;
  final int setsWithLoad, setsWithoutLoad;
}

/// [sets] as `(group, reps, loadKg)`. A set that works two groups is passed
/// once per group by the caller; nothing is split or weighted here.
Map<K, Tonnage> tonnageBy<K>(Iterable<(K, int?, double?)> sets) {
  final kg = <K, double>{}, withLoad = <K, int>{}, without = <K, int>{};
  for (final (group, reps, load) in sets) {
    if (reps == null || reps <= 0 || load == null || load <= 0) {
      without[group] = (without[group] ?? 0) + 1;
    } else {
      withLoad[group] = (withLoad[group] ?? 0) + 1;
      kg[group] = (kg[group] ?? 0) + reps * load;
    }
  }
  return {
    for (final g in {...withLoad.keys, ...without.keys})
      g: Tonnage(kg[g] ?? 0, withLoad[g] ?? 0, without[g] ?? 0),
  };
}

/// Edwards' training load: Σ minutes in zone i × i, zones 1–5. Null unless
/// exactly five zone totals are given.
///
/// Also the intensity distribution it comes from: the share of zone time in
/// zones 1–2, 3 and 4–5 ([edwardsShares]) — descriptive only.
double? edwardsLoad(List<double>? zoneMin) {
  if (zoneMin == null || zoneMin.length != 5) return null;
  var load = 0.0;
  for (var i = 0; i < 5; i++) {
    if (!zoneMin[i].isFinite || zoneMin[i] < 0) return null;
    load += zoneMin[i] * (i + 1);
  }
  return load;
}

/// `(low, moderate, high)` fractions of zone time (zones 1–2, 3, 4–5). Null
/// with no zone time at all.
(double, double, double)? edwardsShares(List<double>? zoneMin) {
  if (edwardsLoad(zoneMin) == null) return null;
  final z = zoneMin!;
  final all = z.reduce((a, b) => a + b);
  if (all <= 0) return null;
  return ((z[0] + z[1]) / all, z[2] / all, (z[3] + z[4]) / all);
}
