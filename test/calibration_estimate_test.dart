// Greyed Recovery/Strain while the real ones calibrate (owner request): the
// estimate starts at a generic adult reference and moves to the user's own
// nights; it is never built from breathing alone and never pinned to an end.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/calibration_estimate.dart';

void main() {
  group('blendedBaseline', () {
    test('no history: the reference itself', () {
      final b = blendedBaseline(const [], kRefRhr);
      expect(b.centre, kRefRhr.centre);
      expect(b.spread, kRefRhr.spread);
    });

    test('the user\'s nights pull the centre toward them', () {
      final few = blendedBaseline(const [50, 50], kRefRhr);
      final many = blendedBaseline(List.filled(12, 50.0), kRefRhr);
      expect(few.centre, lessThan(kRefRhr.centre));
      expect(many.centre, lessThan(few.centre));
      expect(many.centre, closeTo(50, 2));
    });
  });

  group('calibratingRecovery', () {
    test('needs HRV or resting HR: breathing alone is not enough', () {
      expect(calibratingRecovery(respRate: 14), isNull);
      expect(calibratingRecovery(), isNull);
    });

    test('a night at the reference reads the middle', () {
      final v = calibratingRecovery(
          rmssdMs: math.exp(kRefLnRmssd.centre), restingHr: kRefRhr.centre);
      expect(v, closeTo(50, 0.5));
    });

    test('higher HRV and lower resting HR read higher', () {
      final good = calibratingRecovery(rmssdMs: 90, restingHr: 48)!;
      final poor = calibratingRecovery(rmssdMs: 25, restingHr: 70)!;
      expect(good, greaterThan(60));
      expect(poor, lessThan(40));
    });

    test('never pinned to an end: the z cap holds it inside', () {
      final top = calibratingRecovery(rmssdMs: 400, restingHr: 30)!;
      final bottom = calibratingRecovery(rmssdMs: 5, restingHr: 110)!;
      final cap = 100 / (1 + math.exp(-kCalibrationZCap));
      expect(top, lessThanOrEqualTo(cap + 1e-9));
      expect(bottom, greaterThanOrEqualTo(100 - cap - 1e-9));
    });

    test('judged against the user once they have nights', () {
      // A low-HRV person: 30 ms is their normal, so tonight at 30 ms is not
      // the poor night it would be against the adult reference.
      final cold = calibratingRecovery(rmssdMs: 30, restingHr: 57)!;
      final known = calibratingRecovery(
          rmssdMs: 30,
          rmssdHistoryMs: List.filled(10, 30.0),
          restingHr: 57,
          restingHrHistory: List.filled(10, 57.0))!;
      expect(known, greaterThan(cold));
    });
  });

  test('calibratingStrain: nothing without the inputs the real one needs', () {
    expect(
        calibratingStrain(
            wakeHrPerMin: const [], restingHr: 55, maxHr: 185, female: false),
        isNull);
    expect(
        calibratingStrain(
            wakeHrPerMin: List.filled(600, 80.0),
            restingHr: null,
            maxHr: 185,
            female: false),
        isNull);
  });

  test('calibratingStrain: a hard hour scores above a quiet day', () {
    final quiet = calibratingStrain(
        wakeHrPerMin: List.filled(900, 70.0),
        restingHr: 55,
        maxHr: 185,
        female: false);
    final hard = calibratingStrain(
        wakeHrPerMin: [...List.filled(840, 70.0), ...List.filled(60, 165.0)],
        restingHr: 55,
        maxHr: 185,
        female: false);
    expect(hard, isNotNull);
    expect(hard!, greaterThan(quiet ?? 0));
    expect(hard, lessThanOrEqualTo(21));
  });
}
