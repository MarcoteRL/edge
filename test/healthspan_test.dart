// The physiological-age estimate (lib/compute/healthspan.dart): the numbers
// must come out of the cited papers, and it must refuse rather than guess.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/compute/healthspan.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/ui2/screens/healthspan_screen.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

void main() {
  group('the evidence, as numbers', () {
    test('a doubling of risk is eight years', () {
      expect(yearsFromRiskRatio(2.0), closeTo(8.0, 1e-9));
      expect(yearsFromRiskRatio(1.0), 0.0);
    });

    test('FRIEND medians at decade midpoints, interpolated between', () {
      expect(friendVo2maxMedian(25, 'm'), 48.0);
      expect(friendVo2maxMedian(35, 'f'), 30.2);
      expect(friendVo2maxMedian(30, 'm'), closeTo((48.0 + 42.4) / 2, 1e-9));
      expect(friendVo2maxMedian(20, 'm'), 48.0, reason: 'held flat below 25');
      expect(friendVo2maxMedian(79, 'f'), 18.3, reason: 'held flat above 75');
      expect(friendVo2maxMedian(19, 'm'), isNull);
      expect(friendVo2maxMedian(80, 'm'), isNull);
      expect(friendVo2maxMedian(40, 'x'), isNull);
    });

    test('one MET above the median is Kodama RR 0.87 of younger', () {
      final ref = friendVo2maxMedian(35, 'm')!;
      final p = fitnessPillar(ref + 3.5, 35, 'm')!;
      expect(p.years, closeTo(8 * math.log(0.87) / math.ln2, 1e-9));
      expect(p.years, lessThan(0));
    });

    test('fitness is clamped to the span the evidence covers', () {
      final ref = friendVo2maxMedian(35, 'm')!;
      final far = fitnessPillar(ref + 40, 35, 'm')!;
      final cap = fitnessPillar(ref + 4 * 3.5, 35, 'm')!;
      expect(far.years, closeTo(cap.years, 1e-9));
    });

    test('regularity: one SD above the UK Biobank median is RR 0.813', () {
      final p = sleepRegularityPillar(81.0 + 10.7)!;
      expect(p.years, closeTo(8 * math.log(0.813) / math.ln2, 1e-9));
      expect(sleepRegularityPillar(81.0)!.years, closeTo(0, 1e-12));
    });

    test('sleep length: short and long carry Cappuccio\'s risks', () {
      List<double> nights(double h) => List.filled(7, h * 60);
      expect(sleepDurationPillar(nights(5.5))!.years,
          closeTo(8 * math.log(1.12) / math.ln2, 1e-9));
      expect(sleepDurationPillar(nights(9.5))!.years,
          closeTo(8 * math.log(1.30) / math.ln2, 1e-9));
      expect(sleepDurationPillar(nights(7.5))!.years, 0.0);
      expect(sleepDurationPillar(List.filled(6, 450)), isNull,
          reason: 'fewer than 7 nights');
    });
  });

  group('it refuses rather than guesses', () {
    test('no age, no sex, or out of range: no estimate, reasons named', () {
      final g = <HealthspanGap>[];
      expect(estimateHealthspan(age: null, sex: 'm', sri: 85, gaps: g), isNull);
      expect(g, contains(HealthspanGap.age));
      g.clear();
      expect(estimateHealthspan(age: 30, sex: null, sri: 85, gaps: g), isNull);
      expect(g, contains(HealthspanGap.sex));
      g.clear();
      expect(estimateHealthspan(age: 85, sex: 'f', sri: 85, gaps: g), isNull);
      expect(g, contains(HealthspanGap.ageRange));
    });

    test('one input is not enough; a missing input is absent, not zero', () {
      final g = <HealthspanGap>[];
      expect(estimateHealthspan(age: 34, sex: 'm', sri: 90, gaps: g), isNull);
      expect(g, containsAll([HealthspanGap.fitness, HealthspanGap.sleepDuration]));

      final est = estimateHealthspan(
        age: 34,
        sex: 'm',
        sri: 90,
        nightlySleepMin: List.filled(10, 7 * 60.0),
        gaps: g..clear(),
      )!;
      expect(est.pillars.map((p) => p.kind),
          isNot(contains(HealthspanPillarKind.fitness)));
      expect(g, [HealthspanGap.fitness]);
      expect(est.physiologicalAge,
          closeTo(34 + sleepRegularityPillar(90)!.years, 1e-9));
    });
  });

  testWidgets('the screen shows the estimate and what is missing', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(Brightness.light),
      home: HealthspanScreen(
        inputs: (
          age: 34,
          sex: 'm',
          vo2max: null,
          sri: 90.0,
          sleepMin: List.filled(10, 7 * 60.0),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Edad fisiológica'), findsOneWidget);
    expect(find.text('Tu edad: 34'), findsOneWidget);
    expect(
        find.text('Registra una carrera o una caminata rápida con GPS para '
            'estimarla.'),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('VO2max is the median of the newest three, newest first', () {
    expect(
        latestVo2max([
          {'vo2max_estimate': 40.0},
          {'vo2max_estimate': 50.0},
          {'vo2max_estimate': 45.0},
          {'vo2max_estimate': 10.0},
        ]),
        45.0);
    expect(latestVo2max([{'vo2max_estimate': null}]), isNull);
  });
}
