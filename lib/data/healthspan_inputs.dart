// Reads what lib/compute/healthspan.dart needs for one six-month window —
// FORK MODULE. Everything here is already stored; nothing new is written.

import '../compute/healthspan.dart';
import '../compute/profile.dart';
import 'day_label.dart';
import 'db.dart';
import 'local_repository.dart';

/// WHOOP reads six months.
const Duration kHealthspanWindow = Duration(days: 180);

/// A GPS VO2max still counts as current fitness for this long (WHOOP's GPS
/// lookback is 90 days); after that the non-exercise model takes over.
const Duration kHealthspanGpsWindow = Duration(days: 90);

/// Pace of ageing compares today's window with the one this much earlier.
const Duration kHealthspanPaceLookback = Duration(days: 30);

/// Weekly minutes need this many worn days behind them, or they are absent.
const int kHealthspanMinWornDays = 14;

/// Session types that count as strength time (WHOOP counts yoga too).
const Set<String> kStrengthSessionTypes = {
  'strength', 'weights', 'lifting', 'weight_training', 'powerlifting',
  'kettlebell', 'weightlifting', 'strength_trainer', 'functional',
  'functional_fitness', 'crossfit', 'calisthenics', 'yoga', 'pilates',
};

/// Median of the newest (up to) three VO2max estimates; [sessions] come
/// newest first. One run on a hot day should not set the number.
double? latestVo2max(List<Map<String, dynamic>> sessions) {
  final xs = <double>[
    for (final s in sessions)
      if ((s['vo2max_estimate'] as num?)?.toDouble() case final v?)
        if (v.isFinite && v > 0) v,
  ].take(3).toList()
    ..sort();
  return xs.isEmpty ? null : xs[xs.length ~/ 2];
}

/// Z1–Z3 and Z4–Z5 minutes and strength minutes summed over [sessions].
({double moderate, double vigorous, double strength}) sessionMinutes(
    List<Map<String, dynamic>> sessions) {
  var moderate = 0.0, vigorous = 0.0, strength = 0.0;
  for (final s in sessions) {
    final zones = parseZoneMinutes(s['zone_min_json']);
    for (var i = 0; i < zones.length && i < 5; i++) {
      if (i < 3) {
        moderate += zones[i];
      } else {
        vigorous += zones[i];
      }
    }
    final type = (s['type'] ?? '').toString().toLowerCase();
    if (kStrengthSessionTypes.contains(type)) {
      strength += (s['duration_min'] as num?)?.toDouble() ?? 0;
    }
  }
  return (moderate: moderate, vigorous: vigorous, strength: strength);
}

/// `zone_min_json` is a JSON list of Z1..Z5 minutes, or empty / null.
List<double> parseZoneMinutes(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  final m = RegExp(r'-?\d+(?:\.\d+)?').allMatches(raw);
  return [for (final x in m) double.parse(x[0]!)];
}

Future<List<double>> _series(String key, String from, String to) async {
  final rows = await LocalDb.metricSeries(key, measuredOnly: true);
  return [
    for (final r in rows)
      if ((r['date'] ?? '').toString().compareTo(from) >= 0 &&
          (r['date'] ?? '').toString().compareTo(to) <= 0)
        ?(r['value'] as num?)?.toDouble(),
  ];
}

/// The window ending at [end] (default now). [sri] is the current regularity
/// insight; it is not stored per day, so a past window reuses it and its
/// contribution cancels out of the pace.
Future<HealthspanData> loadHealthspanData({
  required Map<String, dynamic>? user,
  LocalRepository? repo,
  DateTime? end,
  double? sri,
}) async {
  final profile = Profile.fromMap(user ?? const <String, dynamic>{});
  final e = end ?? DateTime.now();
  final s = e.subtract(kHealthspanWindow);
  final from = dayLabelOf(s), to = dayLabelOf(e);
  final eSec = e.millisecondsSinceEpoch ~/ 1000;
  final sSec = s.millisecondsSinceEpoch ~/ 1000;
  final gpsSec = e.subtract(kHealthspanGpsWindow).millisecondsSinceEpoch ~/ 1000;

  double? sriValue = sri;
  if (sriValue == null && repo != null) {
    try {
      final reg = (await repo.getInsights())['regularity'];
      final v = reg is Map ? reg['value'] : null;
      sriValue = v is Map ? (v['sri'] as num?)?.toDouble() : null;
    } catch (_) {}
  }

  var sessions = const <Map<String, dynamic>>[];
  try {
    sessions = await LocalDb.sessionsInRange(sSec, eSec);
  } catch (_) {}
  final gps = latestVo2max([
    for (final x in sessions)
      if (((x['start_ts'] as num?)?.toInt() ?? 0) >= gpsSec) x,
  ]);

  List<double> sleep = const [], steps = const [], rhr = const [], worn = const [];
  try {
    sleep = await _series('tst_min', from, to);
    steps = await _series('steps', from, to);
    rhr = await _series('rhr', from, to);
    worn = await _series('worn_min', from, to);
  } catch (_) {}
  final wornDays = worn.where((v) => v > 0).length;
  final weeks = wornDays / 7;
  final mins = sessionMinutes(sessions);
  final enough = wornDays >= kHealthspanMinWornDays;

  return (
    age: profile.ageYears,
    sex: profile.sex,
    weightKg: profile.weightKg,
    heightCm: profile.heightCm,
    gpsVo2max: gps,
    sri: sriValue,
    sleepMin: sleep,
    stepsDaily: steps,
    rhrNightly: rhr,
    moderateMinPerWeek: enough ? mins.moderate / weeks : null,
    vigorousMinPerWeek: enough ? mins.vigorous / weeks : null,
    strengthMinPerWeek: enough ? mins.strength / weeks : null,
  );
}
