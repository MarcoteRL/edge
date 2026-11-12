// The fork's read-time trend rules (lib/compute/fork/, DECISIONS.md D-15),
// on synthetic series only: step, ramp, white noise, gaps, a clock change and
// duplicate days. Nothing here is a claim about real physiology — it pins
// what the rules do, and how often they cry wolf on noise.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/fork/load.dart';
import 'package:openstrap_edge/compute/fork/trends.dart';

/// Standard normal draws, Box–Muller, from a seeded generator.
double Function() _gauss(int seed) {
  final r = math.Random(seed);
  return () =>
      math.sqrt(-2 * math.log(1 - r.nextDouble())) *
      math.cos(2 * math.pi * r.nextDouble());
}

/// [n] consecutive days ending on day 1000: `level(i) + sd·noise`.
List<TrendPoint> _series(int n, double Function(int daysAgo) level,
    {double sd = 0.1, int seed = 7}) {
  final g = _gauss(seed);
  return [
    for (var ago = n - 1; ago >= 0; ago--)
      (day: 1000 - ago, value: level(ago) + sd * g()),
  ];
}

void main() {
  group('trendOf', () {
    test('a step in the last week is a relevant change', () {
      final t = trendOf(_series(60, (ago) => ago < 7 ? 4.4 : 4.0), today: 1000);
      expect(t.relevant, isTrue);
      expect(t.change!.delta, closeTo(0.4, 0.1));
      expect(t.change!.excludesZero, isTrue);
      expect(t.change!.delta.abs(), greaterThan(t.change!.threshold!));
      expect(t.note, isNull);
    });

    test('a slow ramp is a relevant change with a slope that excludes zero',
        () {
      final t = trendOf(
          _series(60, (ago) => 4.0 + 0.01 * (60 - ago), sd: 0.05),
          today: 1000);
      expect(t.relevant, isTrue);
      expect(t.slope!.perDay, closeTo(0.01, 0.004));
      expect(t.slope!.excludesZero, isTrue);
    });

    test('white noise is called a change less than 5 % of the time', () {
      var called = 0, slopes = 0;
      const runs = 200;
      for (var i = 0; i < runs; i++) {
        final t = trendOf(_series(60, (_) => 4.0, seed: 100 + i),
            today: 1000, seed: i);
        expect(t.relevant, isNotNull);
        if (t.relevant!) called++;
        if (t.slope!.excludesZero) slopes++;
      }
      expect(called / runs, lessThan(0.05), reason: '$called of $runs');
      // The slope's own interval is a 95 % one: it should miss zero about
      // one time in twenty, not one in five.
      expect(slopes / runs, lessThan(0.12), reason: '$slopes of $runs');
    });

    test('a change inside the noise is not relevant', () {
      // 0.3 SD up: under the smallest worthwhile change, let alone the MDC.
      final t = trendOf(_series(60, (ago) => ago < 7 ? 4.03 : 4.0), today: 1000);
      expect(t.relevant, isFalse);
    });

    test('gaps: judged on what is there, absent when too little is', () {
      final full = _series(60, (ago) => ago < 7 ? 4.4 : 4.0);
      // Every third day missing.
      final holed = [
        for (final p in full)
          if (p.day % 3 != 0) p,
      ];
      final t = trendOf(holed, today: 1000);
      expect(t.relevant, isTrue);
      expect(t.means.first.have, lessThan(7));

      // Only three nights in the last week.
      final thin = [
        for (final p in full)
          if (p.day <= 993 || p.day >= 998) p,
      ];
      final a = trendOf(thin, today: 1000);
      expect(a.relevant, isNull);
      expect(a.change, isNull);
      expect(a.note, 'need_baseline:have=3,need=4');
      expect(a.means.first.mean, isNull, reason: 'no mean of three nights');

      // A week of data and nothing before it.
      final fresh = trendOf(_series(7, (_) => 4.0), today: 1000);
      expect(fresh.relevant, isNull);
      expect(fresh.note, 'need_baseline:have=0,need=14');
      expect(fresh.slope, isNull);
      expect(fresh.means.map((m) => m.mean != null), [true, false, false, false]);
    });

    test('no data at all', () {
      final t = trendOf(const [], today: 1000);
      expect(t.relevant, isNull);
      expect(t.note, 'need_baseline:have=0,need=4');
      expect(t.means.every((m) => m.mean == null), isTrue);
    });

    test('a flat usual has no noise to measure against', () {
      final t = trendOf(
          [for (var ago = 59; ago >= 0; ago--) (day: 1000 - ago, value: 52.0)],
          today: 1000);
      expect(t.relevant, isNull);
      expect(t.note, kTrendNoDispersion);
      expect(t.change!.mdc, isNull);
    });

    test('duplicate days, any order, values after today: one value per day',
        () {
      final base = _series(60, (ago) => ago < 7 ? 4.4 : 4.0);
      final messy = [
        (day: 1001, value: 99.0), // tomorrow: not part of any window
        for (final p in base.reversed) ...[
          (day: p.day, value: -50.0), // an earlier duplicate, superseded
          p,
        ],
      ];
      final a = trendOf(base, today: 1000), b = trendOf(messy, today: 1000);
      expect(b.change!.delta, a.change!.delta);
      expect(b.slope!.perDay, a.slope!.perDay);
      expect(b.means.map((m) => m.have), a.means.map((m) => m.have));
    });

    test('the same series and seed give the same interval', () {
      final s = _series(60, (ago) => 4.0 + 0.005 * (60 - ago));
      final a = trendOf(s, today: 1000), b = trendOf(s, today: 1000);
      expect((a.slope!.lo, a.slope!.hi), (b.slope!.lo, b.slope!.hi));
      expect((a.change!.lo, a.change!.hi), (b.change!.lo, b.change!.hi));
    });
  });

  test('day numbers step by one across a clock change', () {
    // Europe's 23 h and 25 h days of 2026, and a year boundary.
    for (final (a, b) in [
      ('2026-03-28', '2026-03-29'),
      ('2026-03-29', '2026-03-30'),
      ('2026-10-24', '2026-10-25'),
      ('2026-10-25', '2026-10-26'),
      ('2026-12-31', '2027-01-01'),
    ]) {
      expect(dayNumberOf(b)! - dayNumberOf(a)!, 1, reason: '$a → $b');
    }
    expect(dayNumberOf('not a day'), isNull);
  });

  group('lnRmssdCv7', () {
    test('SD over mean, in percent', () {
      expect(lnRmssdCv7([4, 4, 4, 4, 4]), 0);
      // mean 4, sample SD of {3.8, 4.2, 3.8, 4.2, 4.0} = 0.2
      expect(lnRmssdCv7([3.8, 4.2, 3.8, 4.2, 4.0]), closeTo(5.0, 1e-9));
    });
    test('absent under five nights, over seven, or with no positive mean', () {
      expect(lnRmssdCv7([4, 4.1, 3.9, 4]), isNull);
      expect(lnRmssdCv7(List.filled(8, 4.0)), isNull);
      expect(lnRmssdCv7([0, 0, 0, 0, 0]), isNull);
      expect(lnRmssdCv7([]), isNull);
    });
  });

  group('scheduleSdMin', () {
    test('times around midnight are close together', () {
      // 23:50, 00:10, 23:55, 00:05, 00:00 — ten-odd minutes of spread.
      final sd = scheduleSdMin([1430, 10, 1435, 5, 0])!;
      expect(sd, inInclusiveRange(5, 12));
    });
    test('the same time every night is zero spread', () {
      expect(scheduleSdMin(List.filled(7, 420.0)), closeTo(0, 1e-6));
    });
    test('absent under five nights or with no mean direction', () {
      expect(scheduleSdMin([420, 425, 430, 415]), isNull);
      expect(scheduleSdMin([0, 360, 720, 1080, 0, 360, 720, 1080]), isNull);
    });
  });

  group('load', () {
    test('sRPE needs a rating', () {
      expect(sessionRpeLoad(rpe: 7, durationMin: 60), 420);
      expect(sessionRpeLoad(rpe: null, durationMin: 60), isNull);
      expect(sessionRpeLoad(rpe: 11, durationMin: 60), isNull);
      expect(sessionRpeLoad(rpe: 7, durationMin: 0), isNull);
    });
    test('a week with an unrated session is a floor, not a total', () {
      final w = rpeLoadOf([(7.0, 60.0), (null, 45.0), (5.0, 30.0)]);
      expect(w.total, 570);
      expect((w.rated, w.unrated), (2, 1));
      expect(w.complete, isFalse);
      expect(rpeLoadOf([(7.0, 60.0)]).complete, isTrue);
      final none = rpeLoadOf(const []);
      expect(none.total, isNull, reason: 'nothing logged is not zero load');
      expect(none.complete, isFalse);
      expect(rpeLoadOf([(null, 45.0)]).total, isNull);
    });
    test('tonnage per group; a set without load is counted, not zeroed', () {
      final t = tonnageBy<String>([
        ('legs', 5, 100.0),
        ('legs', 5, 100.0),
        ('chest', 12, null), // push-ups
        ('chest', 8, 60.0),
        ('back', null, 80.0),
      ]);
      expect(t['legs']!.kg, 1000);
      expect((t['chest']!.kg, t['chest']!.setsWithLoad, t['chest']!.setsWithoutLoad),
          (480, 1, 1));
      expect((t['back']!.kg, t['back']!.setsWithoutLoad), (0, 1));
      expect(tonnageBy<String>(const []), isEmpty);
    });
    test('Edwards: minutes in zone i times i, five zones or nothing', () {
      expect(edwardsLoad([10, 20, 30, 5, 1]), 10 + 40 + 90 + 20 + 5);
      expect(edwardsLoad([10, 20, 30]), isNull);
      expect(edwardsLoad(null), isNull);
      expect(edwardsLoad([10, -1, 0, 0, 0]), isNull);
      final s = edwardsShares([30, 30, 20, 10, 10])!;
      expect((s.$1, s.$2, s.$3), (0.6, 0.2, 0.2));
      expect(edwardsShares([0, 0, 0, 0, 0]), isNull);
    });
  });
}
