// The Home sleep ring as rendered: a scored night as stage arcs (Deep, REM,
// Light, Awake) against a target that says when it is the 8 h default, a slept
// night never an empty bar, and the data HomeData hands it.
//
// ROOT-CAUSE REGRESSIONS (owner saw "of 8h 10m" only BEFORE sleeping and an
// EMPTY bar AFTER sleeping):
//   * the arc and the "of ..." text were both gated on `sleepNeedMin` alone, so
//     a scored night with no learned need drew duration + "No target yet" + an
//     empty bar, and
//   * `HomeData.loadForDay` never loaded `sleepNeedMin` at all, so any dated
//     view of a slept night did the same even when a need existed.
// Both are pinned below: a slept night is never an empty bar, and the need
// reaches the ring from both loaders.
//
// FORK (2026-11-14 upstream merge): the owner kept the fork's Home header (one
// headline number and three bars), so upstream's widget tests of the ring
// drawing (stage arcs, spiral laps, ring captions) were removed with that
// design. The loader tests below are design-free and stay; the "never an empty
// bar" rule is kept by the fork's sleep bar (`_sleepState`, 8 h default
// labelled as the default).

import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/data/local_repository.dart';
import 'package:openstrap_edge/ui2/screens/screens.dart';

// ── fixtures ───────────────────────────────────────────────────────────────

class _Repo extends LocalRepository {
  _Repo({
    this.today = const {},
    this.insights = const {},
    this.night = const {},
  });

  final Map<String, dynamic> today, insights, night;

  @override
  Future<Map<String, dynamic>> getToday() async => today;
  @override
  Future<Map<String, dynamic>> getInsights() async => insights;
  @override
  Future<Map<String, dynamic>> getProfile() async => const {};
  @override
  Future<Map<String, dynamic>> getDaySleepV2(String date) async => night;
  @override
  Future<Map<String, dynamic>> getDayOverview(String date) async => const {};
  @override
  Future<Map<String, dynamic>> getDayStrain(String date) async => const {};
}

Map<String, dynamic> _env(num v) => {
      'value': v,
      'confidence': .8,
      'tier': 'ESTIMATE',
      'unit': 'min',
    };

const _needInsights = {
  'sleep_coach': {
    'need': {
      'value': {'need_sec': 27720}, // 462 min
      'confidence': .7,
      'tier': 'ESTIMATE',
    },
  },
};

Map<String, dynamic> get _sleptToday => {
      'daily': const {},
      'sleep': {'duration_min': _env(442)},
      'status': {
        'today_day': '2026-10-09',
        'overnight_state': 'ready',
        'overnight_day': '2026-10-09',
        'showing_prior_overnight': false,
      },
    };

const _nightMap = {
  'has_sleep': true,
  'duration_min': 442,
  'deep_min': 70,
  'rem_min': 95,
  'light_min': 277,
  'awake_min': 30,
};

void main() {

  group('regression: a slept night is never an empty bar', () {

    test('HomeData.load carries the learned need and the stage totals of a '
        'night that scored', () async {
      final repo = _Repo(
        today: _sleptToday,
        insights: _needInsights,
        night: _nightMap,
      );
      final d = await HomeData.load(repo);
      expect(d.sleepMin.value, 442);
      expect(d.sleepNeedMin.value, 462);
      expect(d.sleepStages?.deep, 70);
      expect(d.sleepStages?.rem, 95);
      expect(d.sleepStages?.light, 277);
      expect(d.sleepStages?.awake, 30);
    });

    test('HomeData.loadForDay (a dated view of a slept night) carries the '
        'need the night itself reports', () async {
      final repo = _Repo(
        night: {..._nightMap, 'need_min': _env(462)},
      );
      final d = await HomeData.loadForDay(repo, '2026-10-08');
      expect(d.sleepMin.value, 442);
      expect(d.sleepNeedMin.value, 462);
      expect(d.sleepStages?.deep, 70);
    });

    test('HomeData.loadForDay with no learned need leaves it absent (the ring '
        'then shows the labelled default, never a made-up need)', () async {
      final repo = _Repo(night: _nightMap);
      final d = await HomeData.loadForDay(repo, '2026-10-08');
      expect(d.sleepNeedMin.value, isNull);
      expect(d.sleepMin.value, 442);
    });

  });

  group('loaders: no stale stages', () {
    test('a night that is NOT today\'s never lends its stages to today',
        () async {
      final repo = _Repo(
        today: {
          'daily': const {},
          'sleep': const {},
          'status': {
            'today_day': '2026-10-09',
            'overnight_state': 'building',
            'overnight_day': '2026-10-08',
            'showing_prior_overnight': true,
          },
        },
        insights: _needInsights,
        night: _nightMap, // last night's, which the ring must not borrow
      );
      final d = await HomeData.load(repo);
      expect(d.sleepMin.value, isNull);
      expect(d.sleepStages, isNull);
      expect(d.sleepNeedMin.value, 462);
    });
  });

}
