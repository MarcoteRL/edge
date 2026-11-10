// The training block and the coach read one summary of the strength log:
// last session's top sets and records, working sets per muscle group this
// week, and how long since each group was trained.
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/data/db.dart';
import 'package:openstrap_edge/data/strength_summary.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late String dir;
  final now = DateTime(2026, 11, 10, 9);
  int daysAgo(int d, [int h = 18]) =>
      DateTime(now.year, now.month, now.day - d, h).millisecondsSinceEpoch ~/
      1000;

  Future<void> session(String id, int start,
      List<(String key, int reps, double? kg, String note)> sets) async {
    await LocalDb.putSession({
      'id': id,
      'start_ts': start,
      'end_ts': start + 3600,
      'type': 'weight_training',
      'status': 'done',
      'source': 'hevy',
      'duration_min': 60,
      'strain': 11.2,
      'created_at': 0,
    });
    await LocalDb.replaceStrengthSets(id, [
      for (final (i, s) in sets.indexed)
        {
          'exercise_key': s.$1,
          'set_index': i,
          'reps': s.$2,
          'load_kg': s.$3,
          'at_ts': start,
          'note': s.$4,
        }
    ]);
  }

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.dbName = 'openstrap_strength_summary_test.db';
    dir = await databaseFactory.getDatabasesPath();
    await LocalDb.close();
    await databaseFactory.deleteDatabase(p.join(dir, LocalDb.dbName));
    await LocalDb.instance;
    await LocalDb.putExerciseDef('hevy:Bench Press (Barbell)',
        'Bench Press (Barbell)', {'primary': ['chest'], 'secondary': ['triceps']});
    await LocalDb.putExerciseDef('hevy:Squat (Barbell)', 'Squat (Barbell)',
        {'primary': ['quadriceps'], 'secondary': []});
  });

  tearDown(() async {
    await LocalDb.close();
    await databaseFactory.deleteDatabase(p.join(dir, LocalDb.dbName));
  });

  test('muscle names from either source land in six groups', () {
    expect(muscleGroupOf('quadriceps'), MuscleGroup.legs);
    expect(muscleGroupOf('upper_back'), MuscleGroup.back);
    expect(muscleGroupOf('Abdominals'), MuscleGroup.core);
    expect(muscleGroupOf('cardio'), isNull);
  });

  test('nothing lifted: no summary', () async {
    expect(await loadStrengthSummary(now: now), isNull);
  });

  test('last session, records, weekly sets and the most rested group',
      () async {
    await session('legs', daysAgo(9), [
      ('hevy:Squat (Barbell)', 5, 100, ''),
    ]);
    await session('old', daysAgo(5), [
      ('hevy:Bench Press (Barbell)', 8, 75, ''),
    ]);
    await session('push', daysAgo(1), [
      ('hevy:Bench Press (Barbell)', 10, 40, 'warmup'),
      ('hevy:Bench Press (Barbell)', 8, 80, ''),
      ('hevy:Bench Press (Barbell)', 7, 80, ''),
    ]);
    final s = (await loadStrengthSummary(now: now))!;
    final last = s.last!;
    expect(last.id, 'push');
    final bench = last.lifts.single;
    expect(bench.label, 'Bench Press (Barbell)');
    expect(bench.sets, 2, reason: 'warm-ups are not working sets');
    expect(bench.loadKg, 80);
    expect(bench.reps, 8);
    expect(bench.pr, isTrue, reason: '80 kg beats the 75 kg of 5 days ago');
    expect(s.weekSets, {MuscleGroup.chest: 3});
    expect(s.daysSince[MuscleGroup.legs], 9);
    expect(mostRestedGroup(s.daysSince)?.group, MuscleGroup.legs);
  });

  test('the first time a lift is logged is not a record', () async {
    await session('first', daysAgo(1), [
      ('hevy:Squat (Barbell)', 5, 100, ''),
    ]);
    final s = (await loadStrengthSummary(now: now))!;
    expect(s.last!.lifts.single.pr, isFalse);
    expect(mostRestedGroup(s.daysSince), isNull,
        reason: 'one group trained: nothing to compare');
  });
}
