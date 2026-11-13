// FORK MODULE — the one door to trends.dart for anything that draws them
// (DECISIONS.md D-15).
//
// The bootstrap in [trendOf] is far too heavy for a frame, and nothing on
// the read seam's hot path (`getToday`) may call this. A screen that shows a
// trend asks for it when it opens; the answer is computed once in
// `Isolate.run` and kept in memory until the series it came from changes.

import 'dart:isolate';

import '../../data/day_label.dart';
import '../../data/db.dart';
import '../derivation_engine.dart' show kAlgoVersion;
import 'trends.dart';

abstract final class TrendService {
  // key → (the series' last date, today, kAlgoVersion) and the trend it gave.
  // A new night, a new day or a new algorithm version each make a new key.
  static final Map<String, ((String?, String, int), Trend)> _cache = {};

  /// The trend of the stored series [key] (`metric_series`, the user's own
  /// measured days only), ending today.
  static Future<Trend> of(String key) async {
    final rows = await LocalDb.metricSeries(key, measuredOnly: true);
    final today = todayLabel();
    final stamp = (
      rows.isEmpty ? null : rows.last['date'] as String?,
      today,
      kAlgoVersion,
    );
    final hit = _cache[key];
    if (hit != null && hit.$1 == stamp) return hit.$2;
    final points = _points(rows);
    final trend = await Isolate.run(_job(points, dayNumberOf(today)!));
    _cache[key] = (stamp, trend);
    return trend;
  }

  static List<TrendPoint> _points(List<Map<String, dynamic>> rows) => [
    for (final r in rows)
      if (dayNumberOf(r['date'] as String? ?? '') case final day?)
        if (r['value'] case final num v) (day: day, value: v.toDouble()),
  ];

  /// [days] days before the local day [split] against the [days] from it on,
  /// over the same stored series [of] reads. Not cached: the user changes the
  /// question on every tap and the answer is a few hundred means.
  static Future<PeriodChange> periods(
    String key, {
    required String split,
    required int days,
  }) async {
    final points =
        _points(await LocalDb.metricSeries(key, measuredOnly: true));
    return Isolate.run(_periodJob(points, dayNumberOf(split)!, days));
  }

  static PeriodChange Function() _periodJob(
    List<TrendPoint> points,
    int split,
    int days,
  ) => () => periodChange(points, split: split, days: days);

  /// The stored values of [key] on the last [days] local days, oldest first.
  static Future<List<double>> lastDays(String key, int days) async {
    final today = dayNumberOf(todayLabel())!;
    return [
      for (final p
          in _points(await LocalDb.metricSeries(key, measuredOnly: true)))
        if (p.day > today - days && p.day <= today) p.value,
    ];
  }

  // Built in a static so the closure holds the points and nothing else.
  static Trend Function() _job(List<TrendPoint> points, int today) =>
      () => trendOf(points, today: today);

  /// Forget everything (a reset, a restore, a test).
  static void clear() => _cache.clear();
}
