// What the strength log says about the last weeks — the training block on
// Home and the coach's morning inputs read the same thing, so they cannot
// disagree. Pure arithmetic over `strength_set` + `sessions` + the exercise
// muscles (`exercise_def` for imported lifts, the built-in catalogue for the
// rest). Nothing is estimated: a lift with no known muscles counts toward no
// group, and a group nobody trained is simply not listed.
import '../compute/fork/load.dart';
import '../ui2/activity/catalogue.dart' show exerciseByKey;
import 'day_label.dart' show calendarDaysBetween;
import 'db.dart';

/// The six groups Home speaks in. Every muscle name either source uses maps
/// onto one of them or onto none.
enum MuscleGroup { chest, back, legs, shoulders, arms, core }

MuscleGroup? muscleGroupOf(String muscle) {
  switch (muscle.toLowerCase().replaceAll(' ', '_')) {
    case 'chest':
    case 'pectorals':
    case 'pecs':
      return MuscleGroup.chest;
    case 'back':
    case 'lats':
    case 'upper_back':
    case 'lower_back':
    case 'traps':
    case 'trapezius':
      return MuscleGroup.back;
    case 'legs':
    case 'quadriceps':
    case 'quads':
    case 'hamstrings':
    case 'glutes':
    case 'calves':
    case 'adductors':
    case 'abductors':
      return MuscleGroup.legs;
    case 'shoulders':
    case 'delts':
    case 'deltoids':
      return MuscleGroup.shoulders;
    case 'arms':
    case 'biceps':
    case 'triceps':
    case 'forearms':
      return MuscleGroup.arms;
    case 'core':
    case 'abs':
    case 'abdominals':
    case 'obliques':
      return MuscleGroup.core;
    default:
      return null;
  }
}

typedef TopLift = ({
  String key,
  String label,
  int sets,
  int? reps,
  double? loadKg,
  bool pr,
});

typedef StrengthSession = ({
  String id,
  int startTs,
  int? durationMin,
  double? strain,
  double? kcal,
  String source,
  List<TopLift> lifts,
});

typedef StrengthSummary = ({
  StrengthSession? last,
  Map<MuscleGroup, int> weekSets,
  Map<MuscleGroup, int> daysSince,

  /// Volume load of the last 7 days: Σ reps × kg over working sets, each set
  /// once (not once per muscle group), with the sets that carry no load
  /// counted beside it. Null when no working set was logged in the week.
  Tonnage? weekLoad,

  /// Session-RPE load of the last 7 days over the sessions with sets; a floor
  /// while any of them is unrated ([RpeLoad.complete]).
  RpeLoad weekRpe,
});

/// Working sets: a warm-up is logged but is not training volume.
bool isWorkingSet(Map<String, Object?> s) => '${s['note'] ?? ''}' != 'warmup';

/// The summary as of [now]: the newest session with sets in the last 7 days,
/// working sets per group over the last 7 days, and days since each group was
/// last trained over the last 28. Null when nothing was lifted in 28 days.
Future<StrengthSummary?> loadStrengthSummary({DateTime? now}) async {
  final t = now ?? DateTime.now();
  final nowSec = t.millisecondsSinceEpoch ~/ 1000;
  final from28 = nowSec - 28 * 86400;
  final from7 = nowSec - 7 * 86400;
  final sessions = (await LocalDb.sessionsInRange(from28, nowSec))
      .where((r) => r['private'] != 1 && r['id'] is String)
      .toList();
  final setsBySession = <String, List<Map<String, Object?>>>{};
  for (final r in sessions) {
    final sets = await LocalDb.strengthSets(r['id'] as String);
    if (sets.isNotEmpty) setsBySession[r['id'] as String] = sets;
  }
  if (setsBySession.isEmpty) return null;
  final keys = {
    for (final l in setsBySession.values)
      for (final s in l) '${s['exercise_key']}'
  };
  final defs = await LocalDb.exerciseDefs(keys);
  List<MuscleGroup> groupsOf(String key) {
    final d = defs[key];
    final primary = d?.primary ?? exerciseByKey(key)?.primaryMuscles ?? const [];
    return {for (final m in primary) ?muscleGroupOf(m)}.toList();
  }

  String labelOf(String key) =>
      defs[key]?.label ??
      exerciseByKey(key)?.label ??
      (key.startsWith('hevy:') ? key.substring(5) : key);

  final weekSets = <MuscleGroup, int>{};
  final lastTrained = <MuscleGroup, int>{};
  // The week's muscular load, kept apart from strain (DECISIONS D-09): the
  // arithmetic lives in compute/fork/load.dart.
  final weekLifts = <(int, int?, double?)>[];
  final weekRatings = <(double?, double)>[];
  Map<String, dynamic>? newest;
  for (final r in sessions) {
    final id = r['id'] as String;
    final sets = setsBySession[id];
    if (sets == null) continue;
    final start = (r['start_ts'] as num).toInt();
    if (start >= from7) {
      final end = (r['end_ts'] as num?)?.toInt();
      weekRatings.add((
        (r['rpe'] as num?)?.toDouble(),
        // No end, no duration: the session has no sRPE and counts as unrated.
        end == null ? 0.0 : (end - start) / 60,
      ));
      for (final s in sets.where(isWorkingSet)) {
        weekLifts.add((
          0,
          (s['reps'] as num?)?.toInt(),
          (s['load_kg'] as num?)?.toDouble(),
        ));
      }
    }
    for (final s in sets.where(isWorkingSet)) {
      for (final g in groupsOf('${s['exercise_key']}')) {
        if (start >= from7) weekSets[g] = (weekSets[g] ?? 0) + 1;
        if (start > (lastTrained[g] ?? 0)) lastTrained[g] = start;
      }
    }
    if (start >= from7 &&
        (newest == null || start > (newest['start_ts'] as num).toInt())) {
      newest = r;
    }
  }

  StrengthSession? last;
  if (newest != null) {
    final id = newest['id'] as String;
    final start = (newest['start_ts'] as num).toInt();
    final byKey = <String, List<Map<String, Object?>>>{};
    for (final s in setsBySession[id]!.where(isWorkingSet)) {
      (byKey['${s['exercise_key']}'] ??= []).add(s);
    }
    final lifts = <TopLift>[];
    for (final e in byKey.entries) {
      Map<String, Object?>? top;
      for (final s in e.value) {
        final load = (s['load_kg'] as num?)?.toDouble() ?? -1;
        final reps = (s['reps'] as num?)?.toInt() ?? 0;
        final tl = (top?['load_kg'] as num?)?.toDouble() ?? -1;
        final tr = (top?['reps'] as num?)?.toInt() ?? 0;
        if (top == null || load > tl || (load == tl && reps > tr)) top = s;
      }
      final topLoad = (top?['load_kg'] as num?)?.toDouble();
      // A record only against earlier sessions that lifted it at all — the
      // first time a lift is logged is not a record, it is a start.
      var pr = false;
      if (topLoad != null && topLoad > 0) {
        final before = (await LocalDb.recentSetsFor(e.key, limit: 400)).where(
            (s) =>
                s['session_id'] != id &&
                ((s['at_ts'] as num?)?.toInt() ?? 0) < start);
        final prevBest = before
            .map((s) => (s['load_kg'] as num?)?.toDouble() ?? 0)
            .fold<double>(0, (a, b) => a > b ? a : b);
        pr = before.isNotEmpty && topLoad > prevBest;
      }
      lifts.add((
        key: e.key,
        label: labelOf(e.key),
        sets: e.value.length,
        reps: (top?['reps'] as num?)?.toInt(),
        loadKg: topLoad,
        pr: pr,
      ));
    }
    last = (
      id: id,
      startTs: start,
      durationMin: (newest['duration_min'] as num?)?.toInt(),
      strain: (newest['strain'] as num?)?.toDouble(),
      kcal: (newest['calories'] as num?)?.toDouble(),
      source: '${newest['source'] ?? ''}',
      lifts: lifts,
    );
  }
  return (
    last: last,
    weekSets: weekSets,
    weekLoad: tonnageBy<int>(weekLifts)[0],
    weekRpe: rpeLoadOf(weekRatings),
    // Calendar days, local: trained yesterday evening is 1 day this morning,
    // however few hours ago that was.
    daysSince: {
      for (final e in lastTrained.entries)
        e.key: calendarDaysBetween(
            DateTime.fromMillisecondsSinceEpoch(e.value * 1000), t),
    },
  );
}

/// The group trained longest ago among the ones trained in the window, or
/// null when fewer than two groups have been trained (nothing to compare).
({MuscleGroup group, int days})? mostRestedGroup(Map<MuscleGroup, int> since) {
  if (since.length < 2) return null;
  final e = since.entries.reduce((a, b) => b.value > a.value ? b : a);
  return (group: e.key, days: e.value);
}
