// An evening of sitting still, still going at the data edge, is not the night
// that ended today. Reported: "2h 38m of sleep from 20:57 until now" while the
// user was awake at a desk — the day's search slice stops at the edge, so the
// open rest block was cut there and published as today's night.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/substrate.dart';

int _local(int y, int mo, int d, [int h = 0, int mi = 0]) =>
    DateTime(y, mo, d, h, mi).millisecondsSinceEpoch ~/ 1000;

typedef _Sec = ({int hr, bool still});

Substrate _build(int start, int end, _Sec Function(int t) at) {
  final ts = <int>[], hr = <int>[];
  final ax = <double>[], ay = <double>[], az = <double>[];
  for (var t = start; t < end; t++) {
    final s = at(t);
    ts.add(t);
    hr.add(s.hr);
    if (s.still) {
      ax.add(0.0);
      ay.add(0.0);
      az.add(1.0);
    } else {
      final rad = ((t - start) % 9) * 10.0 * math.pi / 180.0;
      ax.add(math.cos(rad));
      ay.add(0.0);
      az.add(math.sin(rad));
    }
  }
  final n = ts.length;
  return Substrate(
    tsSec: ts,
    hr: hr,
    rrTsMs: const [],
    rrMs: const [],
    ax: ax,
    ay: ay,
    az: az,
    spo2Red: List<int>.filled(n, 0),
    spo2Ir: List<int>.filled(n, 0),
    skinTemp: List<int>.filled(n, 0),
    skinContact: List<int>.filled(n, 0),
  );
}

void main() {
  group('tonightStillGoing', () {
    final dayStart = _local(2026, 11, 9);
    final dayEnd = _local(2026, 11, 10);
    final edge = _local(2026, 11, 9, 23, 35);

    bool go({required int on, int? off, int? dataEnd, required int hour}) =>
        tonightStillGoing(
          onsetSec: on,
          offsetSec: off ?? edge,
          dayStartSec: dayStart,
          dayEndSec: dayEnd,
          dataEndSec: dataEnd ?? edge,
          onsetLocalHour: hour,
        );

    test('an evening block open at the edge is tonight', () {
      expect(go(on: _local(2026, 11, 9, 20, 57), hour: 20), isTrue);
    });

    test('a block that already ended before the edge is not', () {
      expect(
          go(
              on: _local(2026, 11, 9, 14),
              off: _local(2026, 11, 9, 16),
              hour: 14),
          isFalse);
    });

    test('a night begun before midnight is today\'s, even if still going', () {
      final morning = _local(2026, 11, 9, 6);
      expect(
          go(on: _local(2026, 11, 8, 23), off: morning, dataEnd: morning,
              hour: 23),
          isFalse);
    });

    test('a small-hours onset still going at a morning sync is today\'s', () {
      final morning = _local(2026, 11, 9, 6);
      expect(
          go(on: _local(2026, 11, 9, 0, 30), off: morning, dataEnd: morning,
              hour: 0),
          isFalse);
    });

    test('a slice cut at midnight is not the live edge', () {
      expect(
          go(on: _local(2026, 11, 9, 21), off: dayEnd, dataEnd: dayEnd,
              hour: 21),
          isFalse);
    });
  });

  test('calendarDays: still at a desk from 20:57 until the edge is no night',
      () {
    final start = _local(2026, 11, 9, 8);
    final stillFrom = _local(2026, 11, 9, 20, 57);
    final edge = _local(2026, 11, 9, 23, 35);
    final days = calendarDays(_build(start, edge,
        (t) => t < stillFrom ? (hr: 78, still: false) : (hr: 58, still: true)));
    final today = days.singleWhere((d) => d.date == '2026-11-09');
    expect(today.sleep.present, isFalse,
        reason: 'tonight\'s block, still open at the edge, is not today\'s');
    expect(today.sleepSource, 'none');
  });

  test('calendarDays: a real night still going at a 06:00 sync is kept', () {
    final start = _local(2026, 11, 8, 12);
    final bed = _local(2026, 11, 8, 23);
    final edge = _local(2026, 11, 9, 6);
    final days = calendarDays(_build(start, edge,
        (t) => t < bed ? (hr: 78, still: false) : (hr: 50, still: true)));
    final today = days.singleWhere((d) => d.date == '2026-11-09');
    expect(today.sleep.present, isTrue);
  });

  test('calendarDays: the same block, once it ends, is tomorrow\'s night', () {
    // Proves the detector does read this shape as sleep — so the first
    // calendarDays case above is the fix at work, not a block nobody saw.
    final start = _local(2026, 11, 9, 8);
    final stillFrom = _local(2026, 11, 9, 20, 57);
    final wake = _local(2026, 11, 10, 6, 30);
    final edge = _local(2026, 11, 10, 8);
    final days = calendarDays(_build(
        start,
        edge,
        (t) => t >= stillFrom && t < wake
            ? (hr: 58, still: true)
            : (hr: 78, still: false)));
    expect(days.singleWhere((d) => d.date == '2026-11-09').sleep.present,
        isFalse);
    expect(days.singleWhere((d) => d.date == '2026-11-10').sleep.present,
        isTrue);
  });
}
