// The WHOOP-style physiological age (lib/compute/healthspan.dart): each curve
// must reproduce its cited paper, meeting a guideline must add no years, and
// it must refuse rather than guess.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/compute/healthspan.dart';
import 'package:openstrap_edge/data/healthspan_inputs.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/ui2/screens/healthspan_screen.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

double yrs(double rr) => 8 * math.log(rr) / math.ln2;

HealthspanData data({
  int? age = 34,
  String? sex = 'm',
  double? weightKg = 75,
  double? heightCm = 178,
  double? gpsVo2max,
  double? sri,
  List<double> sleepMin = const [],
  List<double> stepsDaily = const [],
  List<double> rhrNightly = const [],
  double? moderate,
  double? vigorous,
  double? strength,
}) =>
    (
      age: age,
      sex: sex,
      weightKg: weightKg,
      heightCm: heightCm,
      gpsVo2max: gpsVo2max,
      sri: sri,
      sleepMin: sleepMin,
      stepsDaily: stepsDaily,
      rhrNightly: rhrNightly,
      moderateMinPerWeek: moderate,
      vigorousMinPerWeek: vigorous,
      strengthMinPerWeek: strength,
    );

void main() {
  group('the curves reproduce their papers', () {
    test('a doubling of risk is eight years', () {
      expect(yearsFromRiskRatio(2), closeTo(8, 1e-9));
    });

    test('meeting each guideline adds no years', () {
      expect(yearsVsBreakEven(kModerateCurve, 150, 150), closeTo(0, 1e-12));
      expect(yearsVsBreakEven(kVigorousCurve, 75, 75), closeTo(0, 1e-12));
      expect(yearsVsBreakEven(kStepsCurve, 8000, 8000), closeTo(0, 1e-12));
    });

    test('Lee 2022: no vigorous activity vs the guideline is HR 0.81', () {
      expect(yearsVsBreakEven(kVigorousCurve, 0, 75), closeTo(yrs(1 / 0.81), 1e-9));
      // Flat past 300 min: no extra credit for more.
      expect(yearsVsBreakEven(kVigorousCurve, 600, 75),
          closeTo(yearsVsBreakEven(kVigorousCurve, 300, 75), 1e-12));
    });

    test('Banach 2023: quartile medians carry their risks', () {
      expect(rrOnCurve(kStepsCurve, 5537), closeTo(0.52, 1e-12));
      expect(rrOnCurve(kStepsCurve, 2000), 1.0, reason: 'flat below the data');
      expect(yearsVsBreakEven(kStepsCurve, 11529, 8000), lessThan(0));
      expect(yearsVsBreakEven(kStepsCurve, 4000, 8000), greaterThan(0));
    });

    test('Momma 2022: strength bottoms out at 40 min, RR 0.83', () {
      expect(rrOnCurve(kStrengthCurve, 40), closeTo(0.83, 1e-12));
      expect(rrOnCurve(kStrengthCurve, 200), closeTo(0.83, 1e-12));
    });

    test('Jackson 1990 non-exercise VO2max, and PA-R from measured minutes', () {
      expect(jacksonVo2max(age: 30, sex: 'm', bmi: 24, par: 5),
          closeTo(56.363 + 1.921 * 5 - 0.381 * 30 - 0.754 * 24 + 10.987, 1e-9));
      expect(physicalActivityRating(0, 0), 0);
      expect(physicalActivityRating(30, 0), 2);
      expect(physicalActivityRating(90, 0), 3);
      expect(physicalActivityRating(0, 20), 4);
      expect(physicalActivityRating(0, 45), 5);
      expect(physicalActivityRating(0, 120), 6);
      expect(physicalActivityRating(0, 200), 7);
    });

    test('FRIEND medians and Kodama per MET', () {
      expect(friendVo2maxMedian(25, 'm'), 48.0);
      expect(friendVo2maxMedian(35, 'f'), 30.2);
      expect(friendVo2maxMedian(19, 'm'), isNull);
    });
  });

  group('it works without runs, like WHOOP', () {
    test('no GPS run: VO2max comes from the non-exercise model', () {
      final est = estimateHealthspan(data(
        moderate: 200,
        vigorous: 60,
        stepsDaily: List.filled(30, 9000),
      ))!;
      final vo2 = est.pillars.firstWhere((p) => p.kind == HealthspanKind.vo2max);
      expect(vo2.estimated, isTrue);
    });

    test('a GPS run takes precedence', () {
      final est = estimateHealthspan(data(
        gpsVo2max: 50,
        moderate: 200,
        vigorous: 60,
      ))!;
      final vo2 = est.pillars.firstWhere((p) => p.kind == HealthspanKind.vo2max);
      expect(vo2.estimated, isFalse);
      expect(vo2.value, 50);
    });
  });

  group('it refuses rather than guesses', () {
    test('no age or sex: no estimate', () {
      final g = <HealthspanGap>[];
      expect(estimateHealthspan(data(age: null), gaps: g), isNull);
      expect(g, contains(HealthspanGap.age));
    });

    test('fewer than three contributors: no estimate', () {
      expect(estimateHealthspan(data(weightKg: null, sri: 85,
          sleepMin: List.filled(10, 450))), isNull);
    });

    test('missing contributors are named, lean mass always until a scale', () {
      final missing = <HealthspanKind>[];
      estimateHealthspan(
          data(sri: 85, sleepMin: List.filled(10, 450), moderate: 150,
              vigorous: 75, strength: 30),
          missing: missing);
      expect(missing, containsAll([HealthspanKind.leanMass, HealthspanKind.steps,
          HealthspanKind.restingHr]));
    });

    test('pace: steady habits read 1x, improving reads below 1x', () {
      final a = estimateHealthspan(data(sri: 85, sleepMin: List.filled(10, 450),
          moderate: 150, vigorous: 75))!;
      expect(paceOfAging(a, a), closeTo(1, 1e-12));
      final better = estimateHealthspan(data(sri: 85,
          sleepMin: List.filled(10, 450), moderate: 300, vigorous: 150))!;
      expect(paceOfAging(better, a)!, lessThan(1));
      expect(paceOfAging(a, null), isNull);
    });
  });

  test('session minutes: zones split 1–3 / 4–5, strength by type', () {
    final m = sessionMinutes([
      {'zone_min_json': '[10,20,30,5,1]', 'type': 'run', 'duration_min': 66},
      {'zone_min_json': '[]', 'type': 'weight_training', 'duration_min': 45},
    ]);
    expect(m.moderate, 60);
    expect(m.vigorous, 6);
    expect(m.strength, 45);
  });

  testWidgets('the screen shows the estimate, the pace and what is missing',
      (t) async {
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final d = data(sri: 85, sleepMin: List.filled(10, 450), moderate: 150,
        vigorous: 75, stepsDaily: List.filled(30, 8000));
    await t.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(Brightness.light),
      home: HealthspanScreen(windows: (now: d, before: d)),
    ));
    await t.pumpAndSettle();
    expect(find.text('Edad fisiológica'), findsOneWidget);
    expect(find.text('Tu edad: 34'), findsOneWidget);
    // Separator follows LocaleController, not MaterialApp.locale.
    expect(find.textContaining(RegExp(r'^Ritmo de envejecimiento: 1[.,]0x$')),
        findsOneWidget);
    expect(find.text('Necesita una báscula de composición corporal.'),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
