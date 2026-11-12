// Iteration 4 on Home: the deterministic training call (P-01), the
// evolution card (P-03), the freshness line for the other tabs (P-08), the
// "how it is computed" page and the first-weeks note about grey estimates
// (P-04). Each at 1.0x and at iOS's largest text, 3.1x, in its empty,
// calibrating and with-data states.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/ui2/screens/screens.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(S.x4), child: child),
            ),
          ),
        ),
      ),
    );

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

const _drivers = [
  {'label': 'resp', 'contribution': 0.2},
  {'label': 'hrv', 'contribution': -1.1},
  {'label': 'rhr', 'contribution': -0.6},
  {'label': 'temp', 'contribution': -0.1},
];

void main() {
  for (final scale in [1.0, 3.1]) {
    group('at ${scale}x', () {
      testWidgets('each recovery band makes its own call', (t) async {
        _phone(t);
        for (final (score, call) in [
          (80.0, 'A good day for intensity'),
          (50.0, 'A normal day: train as planned'),
          (30.0, 'Keep it light today'),
          (10.0, 'A day to recover'),
        ]) {
          await t.pumpWidget(
              _host(DecisionLine(readiness: score), scale: scale));
          expect(find.text(call), findsOneWidget, reason: '$score');
          expect(t.takeException(), isNull);
        }
      });

      testWidgets('the call names what helped and what held it back',
          (t) async {
        _phone(t);
        await t.pumpWidget(_host(
            const DecisionLine(readiness: 34, drivers: _drivers),
            scale: scale));
        expect(find.text('Helping: Breathing rate'), findsOneWidget);
        // Two at most, in the order the composite gave them.
        expect(find.text('Holding it back: HRV, Resting heart rate'),
            findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('calibrating: says so and makes no call', (t) async {
        _phone(t);
        await t.pumpWidget(_host(
            const DecisionLine(readiness: null, calibrating: true),
            scale: scale));
        expect(
            find.text('No training call yet: recovery is still calibrating'),
            findsOneWidget);
        expect(find.textContaining('intensity'), findsNothing);
        expect(t.takeException(), isNull);
      });

      testWidgets('evolution: changed, stable and not enough days',
          (t) async {
        _phone(t);
        await t.pumpWidget(_host(
            const EvolutionCard([
              (label: 'HRV', relevant: true, delta: '−12 %'),
              (label: 'Resting heart rate', relevant: false, delta: ''),
              (label: 'Sleep', relevant: null, delta: ''),
            ]),
            scale: scale));
        expect(find.text('−12 % vs your usual'), findsOneWidget);
        expect(find.text('Stable'), findsOneWidget);
        expect(find.text('Not enough days yet'), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('how it is computed: every headline number, no overflow',
          (t) async {
        _phone(t);
        await t.pumpWidget(MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (c) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: const HowComputedScreen(),
            ),
          ),
        ));
        expect(find.textContaining('How these numbers'), findsWidgets);
        expect(find.text('Recovery'), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('first weeks: the grey-number note only with an estimate',
          (t) async {
        _phone(t);
        const note = 'Grey numbers are estimates that start from a general '
            'adult reference. They become yours as nights add up.';
        await t.pumpWidget(_host(
            Builder(
                builder: (c) =>
                    firstWeekCard(c, days: 2, strainScored: false)),
            scale: scale));
        expect(find.text(note), findsNothing);
        await t.pumpWidget(_host(
            Builder(
                builder: (c) => firstWeekCard(c,
                    days: 2, strainScored: false, estimates: true)),
            scale: scale));
        expect(find.text(note), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    });
  }

  testWidgets('no score and no calibration: nothing is drawn', (t) async {
    await t.pumpWidget(_host(const DecisionLine(readiness: null)));
    expect(find.byType(Surface), findsNothing);
    expect(DecisionLine.has(readiness: null, calibrating: false), isFalse);
    expect(DecisionLine.has(readiness: null, calibrating: true), isTrue);
  });

  testWidgets('no rows: the evolution card is empty', (t) async {
    await t.pumpWidget(_host(const EvolutionCard([])));
    expect(find.byType(Surface), findsNothing);
  });

  testWidgets('freshness line: nothing to say without band data', (t) async {
    await t.pumpWidget(_host(Builder(builder: dataFreshnessLine)));
    expect(find.byType(Text), findsNothing);
    expect(t.takeException(), isNull);
  });
}
