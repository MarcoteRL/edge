// Iteration 5 (fork): the period lab's verdicts and the weekly report's
// lines, from synthetic values only. What is pinned is the honesty of each
// outcome: a comparison that could not be made never reads as "no change",
// and a line with nothing behind it is not written.

import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/fork/load.dart';
import 'package:openstrap_edge/compute/fork/trends.dart';
import 'package:openstrap_edge/data/strength_summary.dart';
import 'package:openstrap_edge/ui2/screens/screens.dart';

const _full = WindowMean(14, 8, 14, 60);

PeriodChange _change({double? delta, bool? relevant, String? note}) =>
    PeriodChange(
      before: _full,
      after: _full,
      delta: delta,
      relevant: relevant,
      note: note,
    );

/// A trend whose 7-day mean is [week] (null = [have] of 4 nights).
Trend _trend({double? week, int have = 7, bool? relevant, double delta = 0}) =>
    Trend(
      means: [WindowMean(7, 4, have, week)],
      slope: null,
      change: relevant == null
          ? null
          : TrendChange(
              recent: 0,
              usual: 0,
              delta: delta,
              lo: 0,
              hi: 0,
              mdc: 1,
              swc: 1,
            ),
      relevant: relevant,
      note: null,
    );

StrengthSummary _strength({Tonnage? load, RpeLoad rpe = const RpeLoad(null, 0, 0)}) =>
    (last: null, weekSets: const {}, daysSince: const {}, weekLoad: load, weekRpe: rpe);

void main() {
  test('shiftDay steps by calendar days, across both clock changes', () {
    expect(shiftDay('2026-10-26', -1), '2026-10-25');
    expect(shiftDay('2026-10-25', -1), '2026-10-24');
    expect(shiftDay('2026-03-28', 2), '2026-03-30');
    expect(shiftDay('2026-03-01', -1), '2026-02-28');
    expect(shiftDay('2026-11-13', -13), '2026-10-31');
  });

  group('periodVerdict', () {
    test('a relevant difference states it', () {
      final s = periodVerdict(
          GuideMetric.rhr, _change(delta: -3, relevant: true), null);
      expect(s, contains('beyond the night-to-night noise'));
      expect(s, startsWith('−'));
    });

    test('a difference inside the noise is not a change', () {
      final s = periodVerdict(
          GuideMetric.rhr, _change(delta: 0.4, relevant: false), null);
      expect(s, startsWith('No difference beyond the noise'));
    });

    test('too few days is not "no difference"', () {
      final s = periodVerdict(GuideMetric.rhr,
          _change(note: 'need_baseline:have=3,need=8'), null);
      expect(s, 'Not enough days in one of the periods');
    });

    test('flat periods say there is no noise to judge against', () {
      final s = periodVerdict(GuideMetric.sleep,
          _change(delta: 5, note: kTrendNoDispersion), null);
      expect(s, contains('flat'));
      expect(s, isNot(contains('No difference')));
    });
  });

  group('weeklyReportRows', () {
    final trends = [
      _trend(week: 4.0, relevant: true, delta: 0.1),
      _trend(week: 52, relevant: false),
      _trend(have: 2),
    ];

    test('one line per metric; a thin week says how thin', () {
      final rows = weeklyReportRows(trends: trends);
      expect(rows, hasLength(3));
      expect(rows[0].value, contains('vs your usual'));
      expect(rows[1].value, endsWith('Stable'));
      expect(rows[2].value, '2 days with data, 4 needed');
    });

    test('no lifting, no bedtime line when there is nothing behind them', () {
      final rows = weeklyReportRows(
        trends: trends,
        strength: _strength(load: const Tonnage(0, 0, 6)),
      );
      expect(rows, hasLength(3));
    });

    test('lifting, a session-load floor and the bedtime spread', () {
      final rows = weeklyReportRows(
        trends: trends,
        strength: _strength(
          load: const Tonnage(12500, 40, 2),
          rpe: const RpeLoad(900, 2, 1),
        ),
        bedtimeSpreadMin: 35,
      );
      expect(rows.map((r) => r.label), [
        'HRV',
        'Resting heart rate',
        'Sleep',
        'Bedtime, night to night',
        'Lifted',
        'Session load (effort × minutes)',
      ]);
      expect(rows[3].value, startsWith('± '));
      expect(rows[4].value, endsWith(' kg'));
      // One of three sessions is unrated: the load is a floor, and says so.
      expect(rows[5].value, startsWith('at least '));
    });

    test('a fully rated week states its session load plainly', () {
      final rows = weeklyReportRows(
        trends: trends,
        strength: _strength(rpe: const RpeLoad(900, 3, 0)),
      );
      expect(rows.last.value, isNot(contains('at least')));
    });
  });

  test('weeklyReportText is a small Markdown file', () {
    final text = weeklyReportText(
      title: 'Weekly report',
      period: 'A – B',
      rows: const [(label: 'HRV', value: '55 ms · Stable')],
      footer: 'Footer.',
    );
    expect(text, '# Weekly report\n\nA – B\n\n- HRV: 55 ms · Stable\n\nFooter.\n');
  });

  test('how-it-is-computed: what today stands on', () {
    expect(howTodayText((kind: HowKind.scored, have: null, need: null), null),
        'Today: from your own data');
    expect(howTodayText((kind: HowKind.estimate, have: 5, need: 14), null),
        'Today: an estimate, 5 of 14 nights of your own');
    expect(howTodayText((kind: HowKind.estimate, have: null, need: null), null),
        contains('still building'));
    expect(howTodayText((kind: HowKind.absent, have: null, need: null), null),
        'Today: nothing to compute it from');
  });
}
