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

Iterable<HomeBarPainter> _bars(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<HomeBarPainter>();

void main() {
  testWidgets('bars read recovery, sleep, strain, top to bottom', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(d: _day)));
    await t.pumpAndSettle();
    final recovery = t.getCenter(find.text('Recovery')).dy;
    final sleep = t.getCenter(find.text('Sleep')).dy;
    final strain = t.getCenter(find.text('Strain')).dy;
    expect(recovery, lessThan(sleep));
    expect(sleep, lessThan(strain));
  });

  testWidgets('the headline number appears once; bars carry the others',
      (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(d: _day)));
    await t.pumpAndSettle();
    expect(find.text('72'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);
    expect(find.text('8.4'), findsOneWidget);
  });

  testWidgets('the strain bar carries the day\'s target zone', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(d: _day)));
    await t.pumpAndSettle();
    final banded = _bars(t).where((r) => r.bandFrom != null).toList();
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
    expect(_bars(t).where((r) => r.bandFrom != null), isEmpty);
  });

  testWidgets('reduced motion paints the finished bars on the first frame',
      (t) async {
    _tall(t);
    await t.pumpWidget(
        _host(const RingTrio(d: _day), reduceMotion: true));
    await t.pump();
    expect(_bars(t).map((r) => r.v), contains(closeTo(.72, 1e-9)));
  });

  testWidgets('with motion the bars fill in, then finish', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(d: _day)));
    await t.pump(const Duration(milliseconds: 100));
    expect(_bars(t).map((r) => r.v), isNot(contains(closeTo(.72, 1e-9))));
    await t.pumpAndSettle();
    expect(_bars(t).map((r) => r.v), contains(closeTo(.72, 1e-9)));
  });

  testWidgets('better than yesterday says by how much', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(
        d: HomeData(
            readiness: Metric(value: 72, confidence: .8, tier: MetricTier.high),
            recoveryState: 'final',
            readinessYesterday: 63,
            readinessWeekMax: 70))));
    await t.pumpAndSettle();
    expect(find.text('▲ 9 vs yesterday'), findsOneWidget);
    expect(find.text('BEST THIS WEEK'), findsOneWidget);
  });

  testWidgets('no delta on a provisional number', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(
        d: HomeData(
            readiness: Metric(value: 72, confidence: .8, tier: MetricTier.high),
            recoveryState: 'provisional',
            readinessYesterday: 63))));
    await t.pumpAndSettle();
    expect(find.textContaining('vs yesterday'), findsNothing);
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

  testWidgets('the day\'s sessions are listed, oldest first, with strain',
      (t) async {
    _tall(t);
    final day = DateTime(2026, 5, 20);
    int at(int h, int m) =>
        DateTime(day.year, day.month, day.day, h, m).millisecondsSinceEpoch ~/
        1000;
    await t.pumpWidget(_host(HomeScreen(
        data: HomeData(
          dayId: '2026-05-20',
          readiness: const Metric(
              value: 72, confidence: .8, tier: MetricTier.high),
          sessions: [
            {
              'type': 'running',
              'start_ts': at(7, 5),
              'end_ts': at(7, 50),
              'duration_min': 45,
              'strain': 11.2,
            },
            {
              'type': 'cycling',
              'start_ts': at(18, 0),
              'end_ts': at(18, 30),
              'duration_min': 30,
            },
          ],
        ),
        hour: 9)));
    await t.pumpAndSettle();
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('11.2'), findsOneWidget);
    expect(find.textContaining('45m'), findsOneWidget);
    expect(find.textContaining('30m'), findsOneWidget);
    expect(t.getTopLeft(find.textContaining('45m')).dy,
        lessThan(t.getTopLeft(find.textContaining('30m')).dy));
  });

  testWidgets('no sessions, no activities section', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const HomeScreen(data: _day, hour: 9)));
    await t.pumpAndSettle();
    expect(find.text('Activities'), findsNothing);
  });

  testWidgets('a final recovery tints the ring card; provisional does not',
      (t) async {
    _tall(t);
    Color? cardOf(WidgetTester t) => t
        .widget<Surface>(find
            .descendant(of: find.byType(RingTrio), matching: find.byType(Surface))
            .first)
        .color;
    await t.pumpWidget(_host(const RingTrio(d: _day)));
    await t.pumpAndSettle();
    final p = P.of(t.element(find.byType(RingTrio)));
    expect(cardOf(t), isNot(p.card));
    await t.pumpWidget(_host(const RingTrio(
        d: HomeData(
            readiness: Metric(value: 28, confidence: .8, tier: MetricTier.high),
            recoveryState: 'provisional'))));
    await t.pumpAndSettle();
    expect(cardOf(t), p.card);
  });

  testWidgets('Rise and SweepIn finish at once under reduced motion',
      (t) async {
    await t.pumpWidget(_host(
        Column(children: [
          const Rise(3, child: Text('section')),
          SweepIn(builder: (c, v) => Text('t=$v')),
        ]),
        reduceMotion: true));
    await t.pump();
    expect(
        find.ancestor(of: find.text('section'), matching: find.byType(Opacity)),
        findsNothing);
    expect(find.text('t=1.0'), findsOneWidget);
  });

  testWidgets('risen() keys by position and type', (t) async {
    final a = risen([const Text('a'), const SizedBox()]);
    expect((a[0] as Rise).key, const ValueKey((0, Text)));
    expect((a[1] as Rise).key, const ValueKey((1, SizedBox)));
  });

  testWidgets('calibrating: Recovery and Strain shown greyed, and say so',
      (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(
        d: HomeData(
            readiness: Metric(note: 'need_baseline:have=2,need=14'),
            readinessCalibrating: (value: 63.4, nights: 2, need: 14),
            strain: Metric(note: 'need_baseline:have=1,need=3'),
            strainCalibrating: 7.2))));
    await t.pumpAndSettle();
    expect(find.text('63'), findsOneWidget);
    expect(find.text('Calibrating · 3 of 14'), findsOneWidget);
    expect(find.text('7.2'), findsOneWidget);
    expect(find.text('Calibrating'), findsOneWidget);
  });

  testWidgets('no estimate: the calibrating absence as before', (t) async {
    _tall(t);
    await t.pumpWidget(_host(const RingTrio(
        d: HomeData(readiness: Metric(note: 'need_baseline:have=2,need=14')))));
    await t.pumpAndSettle();
    expect(find.textContaining('Calibrating ·'), findsNothing);
  });

  testWidgets('a new value glides from the old one, not from empty',
      (t) async {
    _tall(t);
    Widget trio(num rv) => _host(RingTrio(
        d: HomeData(
            readiness:
                Metric(value: rv, confidence: .8, tier: MetricTier.high))));
    await t.pumpWidget(trio(40));
    await t.pumpAndSettle();
    await t.pumpWidget(trio(80));
    await t.pump(const Duration(milliseconds: 50));
    final mid = _bars(t).map((r) => r.v).firstWhere((v) => v > 0);
    expect(mid, greaterThan(.39));
    expect(mid, lessThan(.8));
    await t.pumpAndSettle();
    expect(find.text('80'), findsOneWidget);
    expect(find.text('40'), findsNothing);
  });
}

