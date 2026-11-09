// Home's hero redesign: rings in day order with the reading inside the dial,
// the strain target drawn on the strain ring, a vitals row measured against
// the user's own usual, and motion that collapses under reduced motion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:openstrap_edge/models/metric.dart';
import 'package:openstrap_edge/ui2/screens/screens.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

const _day = HomeData(
  name: 'Alex',
  dayId: '2026-05-20',
  readiness: Metric(value: 72, confidence: .8, tier: MetricTier.high),
  sleepMin: Metric(value: 432, confidence: .8, tier: MetricTier.high),
  strain: Metric(value: 8.4, confidence: .8, tier: MetricTier.high),
  strainTarget: {'value': 12.0, 'low': 10.0, 'high': 14.0},
  rhr: Metric(value: 54, confidence: .8, tier: MetricTier.high),
  hrv: Metric(value: 68, confidence: .8, tier: MetricTier.high),
  resp: Metric(value: 14.8, confidence: .8, tier: MetricTier.high),
  hrvUsual: 61,
  rhrUsual: 54.4,
  respUsual: 14.6,
);

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      ),
    );

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(390, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Iterable<Ring> _rings(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<Ring>();

void main() {
  testWidgets('rings read sleep, recovery, strain, left to right', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(d: _day)));
    await t.pumpAndSettle();
    final sleep = t.getCenter(find.text('SLEEP')).dx;
    final recovery = t.getCenter(find.text('RECOVERY')).dx;
    final strain = t.getCenter(find.text('STRAIN')).dx;
    expect(sleep, lessThan(recovery));
    expect(recovery, lessThan(strain));
  });

  testWidgets('the reading is drawn inside its ring, once', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(d: _day)));
    await t.pumpAndSettle();
    expect(find.text('72'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);
    expect(find.text('8.4'), findsOneWidget);
  });

  testWidgets('the strain ring carries the day\'s target zone', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(d: _day)));
    await t.pumpAndSettle();
    final banded = _rings(t).where((r) => r.bandFrom != null).toList();
    expect(banded, hasLength(1));
    expect(banded.single.bandFrom, closeTo(10 / 21, 1e-9));
    expect(banded.single.bandTo, closeTo(14 / 21, 1e-9));
  });

  testWidgets('no target, no band', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(
        d: HomeData(
            strain: Metric(value: 8.4, confidence: .8, tier: MetricTier.high)))));
    await t.pumpAndSettle();
    expect(_rings(t).where((r) => r.bandFrom != null), isEmpty);
  });

  testWidgets('reduced motion paints the finished ring on the first frame',
      (t) async {
    _tall(t);
    await t.pumpWidget(
        _host(const RingTrio(d: _day), reduceMotion: true));
    await t.pump();
    expect(_rings(t).map((r) => r.t), everyElement(1.0));
  });

  testWidgets('with motion the ring sweeps in, then finishes', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(d: _day)));
    await t.pump(const Duration(milliseconds: 100));
    expect(_rings(t).any((r) => r.t < 1), isTrue);
    await t.pumpAndSettle();
    expect(_rings(t).map((r) => r.t), everyElement(1.0));
  });

  testWidgets('vitals: each reading against its usual, resting HR once',
      (t) async {
    _tall(t);
    await t.pumpWidget(_host(const HomeScreen(data: _day, hour: 9)));
    await t.pumpAndSettle();
    expect(find.text('68'), findsOneWidget);
    expect(find.text('Usual 61 ms'), findsOneWidget);
    // 68 vs 61 is past the 5% band: one arrow, up.
    expect(find.byIcon(LucideIcons.arrowUp), findsOneWidget);
    // 54 vs 54.4 and 14.8 vs 14.6 sit inside their bands: no arrow.
    expect(find.byIcon(LucideIcons.arrowDown), findsNothing);
    // Drawn in the vitals row, and no longer a second time in the glance.
    expect(find.text('54'), findsOneWidget);
    expect(find.text('Heart rate'), findsNothing);
  });

  testWidgets('no usual yet: the reading, no arrow, no claim', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const HomeScreen(
        data: HomeData(
          dayId: '2026-05-20',
          sleepMin: Metric(value: 432, confidence: .8, tier: MetricTier.high),
          hrv: Metric(value: 68, confidence: .8, tier: MetricTier.high),
        ),
        hour: 9)));
    await t.pumpAndSettle();
    expect(find.text('68'), findsOneWidget);
    expect(find.textContaining('Usual'), findsNothing);
    expect(find.byIcon(LucideIcons.arrowUp), findsNothing);
  });

  testWidgets('absent resting HR still gets its written absence', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const HomeScreen(
        data: HomeData(
          dayId: '2026-05-20',
          readiness: Metric(value: 72, confidence: .8, tier: MetricTier.high),
          strain: Metric(value: 8.4, confidence: .8, tier: MetricTier.high),
        ),
        hour: 9)));
    await t.pumpAndSettle();
    expect(find.textContaining('No resting heart rate'), findsOneWidget);
  });
}
