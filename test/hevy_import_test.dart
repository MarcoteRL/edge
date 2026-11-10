// Hevy workouts → strength sets and the session they belong to.
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/import/hevy_import.dart';

Map<String, dynamic> _workout() => {
      'id': 'w1',
      'title': 'Push',
      'start_time': '2026-11-10T17:00:00Z',
      'end_time': '2026-11-10T18:05:00Z',
      'exercises': [
        {
          'title': 'Bench Press (Barbell)',
          'sets': [
            {'type': 'warmup', 'weight_kg': 40, 'reps': 10},
            {'type': 'normal', 'weight_kg': 80, 'reps': 8, 'rpe': 8.5},
            {'type': 'failure', 'weight_kg': 80, 'reps': 6},
          ],
        },
        {
          'title': 'Plank',
          'sets': [
            {'type': 'normal', 'duration_seconds': 60},
            {'type': 'normal'},
          ],
        },
      ],
    };

void main() {
  test('window from Hevy\'s ISO times, in epoch seconds', () {
    final w = hevyWindow(_workout())!;
    expect(w.end - w.start, 65 * 60);
    expect(w.start,
        DateTime.utc(2026, 11, 10, 17).millisecondsSinceEpoch ~/ 1000);
    expect(hevyWindow({'start_time': 'x', 'end_time': 'y'}), isNull);
    expect(
        hevyWindow({
          'start_time': '2026-11-10T18:00:00Z',
          'end_time': '2026-11-10T17:00:00Z'
        }),
        isNull);
  });

  test('sets keep their order, kind and numbers; empty ones are dropped', () {
    final rows = hevySetsOf(_workout(), 100);
    expect(rows, hasLength(4));
    expect(rows.first['exercise_key'], 'hevy:Bench Press (Barbell)');
    expect(rows.first['note'], 'warmup');
    expect(rows[1]['load_kg'], 80.0);
    expect(rows[1]['reps'], 8);
    expect(rows[1]['rpe'], 9); // stored whole, as the column is
    expect(rows[1]['note'], '');
    expect(rows[2]['note'], 'failure');
    expect(rows[3]['exercise_key'], 'hevy:Plank');
    expect(rows[3]['hold_sec'], 60);
    expect(rows[3]['set_index'], 0);
    expect(rows.every((r) => r['at_ts'] == 100), isTrue);
  });

  group('hevyAttachTarget', () {
    Map<String, dynamic> s(String id, int a, int b, {String status = 'done'}) =>
        {'id': id, 'start_ts': a, 'end_ts': b, 'status': status};

    test('the band session that covers most of it', () {
      final t = hevyAttachTarget(
          [s('walk', 0, 300), s('gym', 950, 4100)], 1000, 4900);
      expect(t?['id'], 'gym');
    });

    test('a band fragment inside the workout still counts', () {
      final t = hevyAttachTarget([s('frag', 2000, 2600)], 1000, 4900);
      expect(t?['id'], 'frag');
    });

    test('a brush at the edge does not, nor a live session', () {
      expect(hevyAttachTarget([s('x', 0, 1100)], 1000, 4900), isNull);
      expect(
          hevyAttachTarget([s('live', 1000, 4900, status: 'live')], 1000, 4900),
          isNull);
    });
  });

  test('templates and muscles from Hevy\'s shapes', () {
    final w = {
      'exercises': [
        {'title': 'Squat (Barbell)', 'exercise_template_id': 'D04AC939'},
        {'title': 'No template'},
      ]
    };
    expect(hevyTemplatesOf(w), {'Squat (Barbell)': 'D04AC939'});
    expect(
        hevyMusclesOf({
          'primary_muscle_group': 'quadriceps',
          'secondary_muscle_groups': ['glutes', 'hamstrings'],
        }),
        {
          'primary': ['quadriceps'],
          'secondary': ['glutes', 'hamstrings'],
        });
  });
}

