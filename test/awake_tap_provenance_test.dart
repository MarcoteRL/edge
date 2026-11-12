// The "I'm awake" tap and a later edit of the night's end both store
// `sleep_override.source = 'manual'`. An analysis that wants the tap as a
// wake label (docs/development/ALGORITHMS.md §4, ALG-S1) tells them apart by
//
//   source = 'manual' AND abs(created_at - offset_ts) <= 60
//
// because the tap stores "now" as the window's end and the row is stamped in
// the same breath. This file pins that rule AND its two known limits, so a
// change to either write path fails here instead of silently relabelling
// nights.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:openstrap_edge/data/db.dart';

/// The rule, as the offline analysis applies it.
const awakeTapRule = "source = 'manual' AND abs(created_at - offset_ts) <= 60";

Future<bool> _isTap(String dayId) async {
  final db = await LocalDb.instance;
  final rows = await db.rawQuery(
    'SELECT 1 FROM sleep_override WHERE day_id = ? AND $awakeTapRule',
    [dayId],
  );
  return rows.isNotEmpty;
}

int _sec(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

void main() {
  const dbName = 'awake_tap_provenance_test.db';
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await LocalDb.close();
    LocalDb.dbName = dbName;
    await databaseFactory.deleteDatabase(
      p.join(await databaseFactory.getDatabasesPath(), dbName),
    );
  });
  tearDownAll(() async {
    await LocalDb.close();
    await databaseFactory.deleteDatabase(
      p.join(await databaseFactory.getDatabasesPath(), dbName),
    );
  });

  test('the tap path still stores "now" as the end of the night', () {
    // `markAwakeNow` is the only writer the rule recognises. If it stops
    // passing the current instant as the offset, the rule is void.
    final src = File('lib/state/app_state.dart').readAsStringSync();
    final start = src.indexOf('Future<bool> markAwakeNow()');
    expect(start, greaterThan(0));
    final body = src.substring(start, src.indexOf('\n  }\n', start));
    expect(body, contains('final now = DateTime.now();'));
    expect(
      body.replaceAll(RegExp(r'\s+'), ' '),
      contains('DateTime.fromMillisecondsSinceEpoch(onset * 1000), now)'),
    );
  });

  test('a tap (end = now) matches the rule', () async {
    final now = DateTime.now();
    await LocalDb.putSleepOverride(
      dayId: '2026-11-10',
      onsetTs: _sec(now) - 8 * 3600,
      offsetTs: _sec(now),
      source: 'manual',
    );
    expect(await _isTap('2026-11-10'), isTrue);
  });

  test('an edit whose end is in the past does not match', () async {
    final now = DateTime.now();
    await LocalDb.putSleepOverride(
      dayId: '2026-11-11',
      onsetTs: _sec(now) - 10 * 3600,
      offsetTs: _sec(now) - 2 * 3600,
      source: 'manual',
    );
    expect(await _isTap('2026-11-11'), isFalse);
  });

  test('a confirmed or rejected night never matches', () async {
    final now = DateTime.now();
    for (final (day, source) in [
      ('2026-11-08', 'confirmed'),
      ('2026-11-09', 'rejected'),
    ]) {
      await LocalDb.putSleepOverride(
        dayId: day,
        onsetTs: _sec(now) - 8 * 3600,
        offsetTs: _sec(now),
        source: source,
      );
      expect(await _isTap(day), isFalse, reason: source);
    }
  });

  test('LIMIT 1: a later edit replaces the tap, and the label is gone',
      () async {
    final now = DateTime.now();
    const day = '2026-11-12';
    await LocalDb.putSleepOverride(
      dayId: day,
      onsetTs: _sec(now) - 8 * 3600,
      offsetTs: _sec(now),
      source: 'manual',
    );
    expect(await _isTap(day), isTrue);
    await LocalDb.putSleepOverride(
      dayId: day,
      onsetTs: _sec(now) - 8 * 3600,
      offsetTs: _sec(now) - 3600,
      source: 'manual',
    );
    final db = await LocalDb.instance;
    expect(
      await db.query('sleep_override', where: 'day_id = ?', whereArgs: [day]),
      hasLength(1),
      reason: 'one row per day: the edit replaced the tap',
    );
    expect(await _isTap(day), isFalse);
  });

  test('LIMIT 2: an edit ending in the current minute looks like a tap',
      () async {
    // The editor stores whole minutes. Set the end to "this minute" right
    // after waking and the row is within 60 s of its own timestamp: the rule
    // cannot tell it from a tap. Rare, and harmless for ALG-S1 (the end IS
    // about now either way), but it is a limit, not an accident.
    final now = DateTime.now();
    final thisMinute = _sec(now) - _sec(now) % 60;
    await LocalDb.putSleepOverride(
      dayId: '2026-11-07',
      onsetTs: thisMinute - 8 * 3600,
      offsetTs: thisMinute,
      source: 'manual',
    );
    expect(await _isTap('2026-11-07'), isTrue);
  });
}
