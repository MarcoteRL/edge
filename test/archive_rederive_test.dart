// DATA-02 — re-deriving days from `substrate_archive`.
//
// The owner's acceptance criteria, each pinned here on synthetic days:
//
//  1. ROUND TRIP. Derive a day from live rows, archive and prune it, re-derive
//     it from the archive under the same kAlgoVersion: `payload_json` and
//     `metric_series` are byte-identical. Covers a normal day with R-R beats,
//     a day with gaps and — when the run's TZ has them (test-files.yml
//     `tz=Europe/Madrid`) — a local day spanning two UTC buckets and the 23 h
//     and 25 h days of a clock change.
//  2. FAITHFUL DECODE. What the re-derive reads back is exactly what the live
//     tables held: every column the derive reads, `device_id` and
//     `beat_index` included, for the primary band and a second device.
//  3. READ ONLY. Nothing is put back into `decoded_onehz` / `decoded_rr`; a
//     second that is both live and archived is read once, the live row.
//  4. IMMUTABLE AND IDEMPOTENT. Older-version rows are untouched, a complete
//     current row is never derived over, a second pass does nothing, days go
//     oldest first, and the baselines afterwards are the ones a from-scratch
//     derive of the same data gives.
//  5. HONEST FAILURES. An unreadable archive leaves the day on its version,
//     is counted under `archive_rederive_failures` — never under
//     `substrate_archive_failures`, which decides deletions — and is given up
//     on after three passes.
//  6. SAFE TO RUN. It yields to a band offload and picks up where it stopped.
//
// "Same version" needs one trick: a binary has one kAlgoVersion, so the days
// under test are relabelled one version down (and their stored scalars
// nudged, standing in for an older algorithm's output) before the re-derive.
//
// THE REFERENCE IS A SETTLED LIVE DERIVE. A day's bundle also reads state that
// is not substrate — the baseline history, the sleep profile, calibration —
// so the live result compared against is the one derived with that state
// settled (two forced passes that agree), not the day's first-ever derive.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/derivation_engine.dart';
import 'package:openstrap_edge/compute/profile.dart';
import 'package:openstrap_edge/data/day_label.dart';
import 'package:openstrap_edge/data/db.dart';
import 'package:openstrap_edge/data/models.dart';
import 'package:openstrap_edge/data/substrate_archive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/synthetic_day.dart';

const _profile = Profile(ageYears: 32, weightKg: 72, heightCm: 176, sex: 'm');
const _old = kAlgoVersion - 1;

int _sec(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

Future<void> _open(String name) async {
  SharedPreferences.setMockInitialValues({});
  await LocalDb.close();
  LocalDb.dbName = name;
  await databaseFactory.deleteDatabase(
    p.join(await databaseFactory.getDatabasesPath(), name),
  );
}

/// Commit [days] as a WHOOP drain would, leaving out every second for which
/// [skip] is true (a gap) and any second an earlier day already committed.
Future<void> _commit(
  List<SyntheticDay> days, {
  bool Function(int recTs)? skip,
  String deviceId = LocalDb.kPrimaryDeviceId,
  int counterOffset = 0,
  int hrOffset = 0,
}) async {
  var committed = 0;
  for (final d in days) {
    for (final (raws, samples) in d.primaryBatches()) {
      final keep = [
        for (var j = 0; j < raws.length; j++)
          if (raws[j].recTs! > committed && !(skip?.call(raws[j].recTs!) ?? false))
            j,
      ];
      if (keep.isEmpty) continue;
      await LocalDb.commitSyncBatch(
        [
          for (final j in keep)
            RawRecord(
              counter: raws[j].counter + counterOffset,
              packetType: raws[j].packetType,
              hex: '${raws[j].hex}$deviceId',
              capturedAt: raws[j].capturedAt,
              recTs: raws[j].recTs,
            ),
        ],
        [
          for (final j in keep)
            Sample(
              tsEpoch: samples[j].tsEpoch,
              counter: samples[j].counter + counterOffset,
              hr: samples[j].hr == 0 ? 0 : samples[j].hr + hrOffset,
              rrIntervalsMs: samples[j].rrIntervalsMs,
              ax: samples[j].ax,
              ay: samples[j].ay,
              az: samples[j].az,
            ),
        ],
        deviceFamily: 'gen5',
        deviceId: deviceId,
      );
      committed = raws[keep.last].recTs!;
    }
  }
}

/// A day's stored result at [version]: the bundle exactly as stored, and
/// every scalar `metric_series` holds for the date.
Future<(String?, String)> _stored(String day, int version) async {
  final db = await LocalDb.instance;
  final row = await db.query('day_result',
      columns: ['payload_json'],
      where: 'day_id = ? AND algo_version = ?',
      whereArgs: [day, version]);
  final series = await db.rawQuery(
      'SELECT key, value FROM metric_series WHERE date = ? ORDER BY key', [day]);
  return (
    row.isEmpty ? null : row.first['payload_json'] as String,
    jsonEncode(series),
  );
}

Future<String> _rolling() async {
  final db = await LocalDb.instance;
  return jsonEncode(await db.rawQuery(
      "SELECT key, payload_json FROM baselines "
      "WHERE key IN ('rolling', 'rolling_artifact') ORDER BY key"));
}

Future<int> _count(String sql, [List<Object?> args = const []]) async =>
    ((await (await LocalDb.instance).rawQuery(sql, args)).first.values.first
            as num?)
        ?.toInt() ??
    0;

/// Move [days]' current-version results one version down and nudge their
/// stored scalars: what the database of an older build looks like.
Future<void> _makeOld(List<String> days, {bool keepOldRows = false}) async {
  final db = await LocalDb.instance;
  final marks = List.filled(days.length, '?').join(',');
  if (keepOldRows) {
    await db.delete('day_result',
        where: 'algo_version = ? AND day_id IN ($marks)',
        whereArgs: [kAlgoVersion, ...days]);
  } else {
    await db.rawUpdate(
        'UPDATE day_result SET algo_version = ? '
        'WHERE algo_version = ? AND day_id IN ($marks)',
        [_old, kAlgoVersion, ...days]);
    await db.rawUpdate(
        'UPDATE metric_series SET value = value + 7 '
        "WHERE key IN ('rhr', 'rmssd', 'ln_rmssd') AND date IN ($marks)",
        days);
  }
  for (final t in ['sleep_session_candidates', 'wake_day_features']) {
    await db.delete(t,
        where: 'algo_version = ? AND day_id IN ($marks)',
        whereArgs: [kAlgoVersion, ...days]);
  }
  await db.delete('compute_freshness',
      where: 'key = ?', whereArgs: [DerivationEngine.archiveRederiveKey]);
}

/// Six synthetic days from [base]; the two after the first are derived live,
/// archived, and re-derived. Returns nothing: every claim is an `expect`.
Future<void> _roundTrip(String name, DateTime base,
    {bool failures = false}) async {
  await _open(name);
  final days = [
    for (var i = 0; i < 6; i++)
      SyntheticDay(DateTime(base.year, base.month, base.day + i)),
  ];
  DateTime at(int i) => DateTime(base.year, base.month, base.day + i);
  final targets = [dayLabelOf(at(1)), dayLabelOf(at(2))];
  final cut = _sec(at(3));
  // The second target has a 2.5 h gap in its morning.
  final gapFrom = _sec(at(2).add(const Duration(hours: 10)));
  await _commit(days, skip: (t) => t >= gapFrom && t < gapFrom + 9000);

  await DerivationEngine().run(_profile, heavy: true);
  await DerivationEngine().run(_profile, heavy: true);

  // The reference: a forced live derive of the two days, twice. Agreeing
  // with itself is the precondition for comparing anything against it.
  await DerivationEngine().runDays(_profile, targets.toSet(), force: true);
  final first = [for (final d in targets) await _stored(d, kAlgoVersion)];
  await DerivationEngine().runDays(_profile, targets.toSet(), force: true);
  final live = [for (final d in targets) await _stored(d, kAlgoVersion)];
  expect(live, first, reason: 'precondition: a settled live derive is stable');
  for (final (payload, _) in live) {
    expect(payload, isNotNull, reason: 'precondition: the day derived');
  }
  final liveRolling = await _rolling();

  // Archive and prune both days (and the evening the third day's night
  // starts in — which is why that day is not one of the targets).
  await LocalDb.pruneDecodedBeforeRecTs(cut,
      cursorName: LocalDb.kDecodedPrunedBeforeCursor);
  expect(await _count('SELECT COUNT(*) FROM decoded_onehz WHERE rec_ts < ?', [cut]), 0);
  expect(await _count('SELECT COUNT(*) FROM substrate_archive'), greaterThan(0));
  final liveRows = (
    await _count('SELECT COUNT(*) FROM decoded_onehz'),
    await _count('SELECT COUNT(*) FROM decoded_rr'),
  );
  final buckets = await _count('SELECT COUNT(*) FROM substrate_archive');

  await _makeOld(targets);
  final old = [for (final d in targets) await _stored(d, _old)];
  expect(old.map((r) => r.$1), live.map((r) => r.$1));

  final seen = <String>[];
  DerivationEngine.debugOnArchiveRederive = seen.add;
  addTearDown(() => DerivationEngine.debugOnArchiveRederive = null);

  // 6. A band offload in progress: nothing is re-derived, and it is not
  // called finished.
  await DerivationEngine(offloadActive: () => true).run(_profile, heavy: true);
  expect(seen, isEmpty);
  expect((await DerivationEngine.archiveRederiveReport())?['finished'], isFalse);
  expect(await LocalDb.daysBelowVersion(kAlgoVersion), containsAll(targets));

  // The offload is over: the next heavy pass picks the days up.
  await DerivationEngine().run(_profile, heavy: true);
  expect(seen, targets, reason: 'oldest first');

  // 1. Byte-identical to the live derive.
  for (var i = 0; i < targets.length; i++) {
    final (payload, series) = await _stored(targets[i], kAlgoVersion);
    expect(payload, live[i].$1, reason: '${targets[i]} payload_json');
    expect(series, live[i].$2, reason: '${targets[i]} metric_series');
  }
  // 4. The older rows were not touched; the baselines are the live ones.
  expect([for (final d in targets) (await _stored(d, _old)).$1],
      old.map((r) => r.$1));
  expect(await _rolling(), liveRolling);
  // 3. Nothing went back into the live tables, nothing left the archive.
  expect(await _count('SELECT COUNT(*) FROM decoded_onehz WHERE rec_ts < ?', [cut]), 0);
  expect(await _count('SELECT COUNT(*) FROM decoded_rr WHERE rec_ts < ?', [cut]), 0);
  expect(
    (
      await _count('SELECT COUNT(*) FROM decoded_onehz'),
      await _count('SELECT COUNT(*) FROM decoded_rr'),
    ),
    liveRows,
  );
  expect(await _count('SELECT COUNT(*) FROM substrate_archive'), buckets);

  final report = (await DerivationEngine.archiveRederiveReport())!;
  expect(report['rederived'], 2);
  expect(report['kept'], isEmpty);
  expect(report['finished'], isTrue);
  expect(await LocalDb.computeFreshness(SubstrateArchive.failuresKey), isNull);

  // 4. A second pass (and a third, forced to look again) writes nothing.
  final db = await LocalDb.instance;
  Future<String> everything() async => jsonEncode([
        await db.rawQuery('SELECT day_id, algo_version, payload_json, '
            'finalized, partial FROM day_result ORDER BY day_id, algo_version'),
        await db.rawQuery('SELECT * FROM metric_series ORDER BY date, key'),
        await _rolling(),
      ]);
  final before = await everything();
  seen.clear();
  await DerivationEngine().run(_profile, heavy: true);
  await db.delete('compute_freshness',
      where: 'key = ?', whereArgs: [DerivationEngine.archiveRederiveKey]);
  await DerivationEngine().run(_profile, heavy: true);
  expect(seen, isEmpty, reason: 'a complete current row is never derived over');
  expect(await everything(), before);

  if (!failures) return;

  // 5. The archive cannot be read: every bucket's blob is garbage.
  await _makeOld(targets, keepOldRows: true);
  await db.rawUpdate("UPDATE substrate_archive SET blob = x'0011223344'");
  seen.clear();
  for (var pass = 0; pass < 5; pass++) {
    await DerivationEngine().run(_profile, heavy: true);
  }
  expect(seen.length, targets.length * DerivationEngine.archiveRederiveMaxFailures,
      reason: 'three passes each, then given up on');
  for (var i = 0; i < targets.length; i++) {
    expect((await _stored(targets[i], kAlgoVersion)).$1, isNull);
    expect((await _stored(targets[i], _old)).$1, old[i].$1,
        reason: 'the day keeps its version');
  }
  final counted = jsonDecode((await LocalDb.computeFreshness(
          SubstrateArchive.rederiveFailuresKey))!['payload_json'] as String)
      as Map;
  expect(counted, {
    for (final d in targets) d: DerivationEngine.archiveRederiveMaxFailures,
  });
  expect(await LocalDb.computeFreshness(SubstrateArchive.failuresKey), isNull,
      reason: 'a read failure never feeds the count that decides deletions');
  final failed = (await DerivationEngine.archiveRederiveReport())!;
  expect(failed['kept'], {'unreadable': targets.length});
  expect(failed['finished'], isTrue);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDown(() async {
    DerivationEngine.debugOnArchiveRederive = null;
    await LocalDb.close();
  });

  test(
    'a day re-derived from the archive is the day derived live',
    () => _roundTrip('archive_rederive_roundtrip.db', DateTime(2026, 7, 12),
        failures: true),
    timeout: const Timeout(Duration(minutes: 30)),
  );

  // Local days that do not line up with the archive's UTC buckets, and the
  // two days a year that are not 24 h long. Meaningful only in a zone that
  // has both; test-files.yml runs this file with tz=Europe/Madrid.
  final dst = DateTime(2026, 3, 30).difference(DateTime(2026, 3, 29)).inHours != 24;
  for (final (label, base) in [
    ('23 h day', DateTime(2026, 3, 27)),
    ('25 h day', DateTime(2026, 10, 23)),
  ]) {
    test(
      'round trip across a clock change ($label)',
      () => _roundTrip(
          'archive_rederive_dst_${base.month}.db', base),
      skip: dst ? false : 'needs a zone with a clock change (TZ=Europe/Madrid)',
      timeout: const Timeout(Duration(minutes: 30)),
    );
  }

  test('a hole in the archive keeps the day on its version', () async {
    await _open('archive_rederive_hole.db');
    final base = DateTime(2026, 7, 12);
    DateTime at(int i) => DateTime(base.year, base.month, base.day + i);
    await _commit([for (var i = 0; i < 5; i++) SyntheticDay(at(i))]);
    final target = dayLabelOf(at(1));
    await DerivationEngine().run(_profile, heavy: true);
    await DerivationEngine().run(_profile, heavy: true);
    await LocalDb.pruneDecodedBeforeRecTs(_sec(at(2)),
        cursorName: LocalDb.kDecodedPrunedBeforeCursor);
    await _makeOld([target]);
    final old = await _stored(target, _old);
    // Every archived second of the day's own waking hours is gone.
    final db = await LocalDb.instance;
    final from = _sec(at(1).add(const Duration(hours: 8)));
    await db.delete('substrate_archive',
        where: 'to_ts >= ? AND from_ts >= ?',
        whereArgs: [from, _sec(at(1)) - 86400 + 1]);
    expect(await LocalDb.substrateArchiveEarliestTs(), isNotNull);

    await DerivationEngine().run(_profile, heavy: true);
    expect((await _stored(target, kAlgoVersion)).$1, isNull);
    expect(await _stored(target, _old), old);
    final report = (await DerivationEngine.archiveRederiveReport())!;
    expect(report['rederived'], 0);
    expect(report['kept'].keys.single, anyOf('less_data', 'no_gain'));
  }, timeout: const Timeout(Duration(minutes: 15)));

  test('what the re-derive reads is what the live tables held', () async {
    await _open('archive_rederive_read.db');
    final base = DateTime(2026, 7, 12);
    final day = SyntheticDay(DateTime(base.year, base.month, base.day + 1));
    // Two devices over the same seconds: the primary band and a second one.
    await _commit([day]);
    await _commit([day],
        deviceId: 'second', counterOffset: 1000000, hrOffset: 9);
    final from = _sec(day.start), to = _sec(day.end);
    Future<List<Map<String, dynamic>>> liveOneHz() =>
        LocalDb.decodedOneHzBatchByRecTsRange(
            limit: 1 << 30, fromRecTs: from, toRecTs: to);
    final onehz = await liveOneHz();
    final rr = await LocalDb.decodedRrByRecTsRange(fromRecTs: from, toRecTs: to);
    expect(onehz.map((r) => r['device_id']).toSet(), {'', 'second'});
    expect(rr, isNotEmpty);

    // Prune up to the day's local midnight: the evening is archived, the day
    // itself stays live — the re-derive's window straddles the two.
    final cut = _sec(DateTime(base.year, base.month, base.day + 1));
    await LocalDb.pruneDecodedBeforeRecTs(cut);
    expect((await liveOneHz()).length, lessThan(onehz.length));

    Future<RehydratedSubstrate> read() async {
      final s = await LocalDb.rehydratedSubstrate();
      await s.load(from, to);
      return s;
    }

    List<Map<String, dynamic>> all(RehydratedSubstrate s) {
      final out = <Map<String, dynamic>>[];
      while (true) {
        final page = s.oneHzPage(from, to, offset: out.length, limit: 2000);
        out.addAll(page);
        if (page.length < 2000) return out;
      }
    }

    final s = await read();
    expect(all(s), onehz);
    expect(s.rr(from, to), rr);
    // A sub-range, as the page loop asks for beats.
    expect(s.rr(cut - 600, cut + 600), [
      for (final r in rr)
        if ((r['rec_ts'] as int) >= cut - 600 &&
            (r['rec_ts'] as int) <= cut + 600)
          r,
    ]);

    // A re-offloaded second that is also archived: the live row is the one
    // read, once; reading it changed neither table.
    final redo = [
      for (final (raws, samples) in day.primaryBatches(batch: 600))
        if (raws.first.recTs! >= cut - 3600 && raws.last.recTs! < cut)
          (raws, samples),
    ].first;
    await LocalDb.commitSyncBatch(
      redo.$1,
      [
        for (final x in redo.$2)
          Sample(
            tsEpoch: x.tsEpoch,
            counter: x.counter,
            hr: 201,
            rrIntervalsMs: x.rrIntervalsMs,
            ax: x.ax,
            ay: x.ay,
            az: x.az,
          ),
      ],
      deviceFamily: 'gen5',
    );
    final liveBelow = await _count(
        'SELECT COUNT(*) FROM decoded_onehz WHERE rec_ts < ?', [cut]);
    expect(liveBelow, redo.$1.length);
    final again = all(await read());
    expect(again.length, onehz.length, reason: 'no second is read twice');
    final lo = redo.$1.first.recTs!, hi = redo.$1.last.recTs!;
    expect(
      {
        for (final r in again)
          if (r['device_id'] == '' &&
              (r['rec_ts'] as int) >= lo &&
              (r['rec_ts'] as int) <= hi)
            r['hr'],
      },
      {201},
    );
    expect(
        await _count('SELECT COUNT(*) FROM decoded_onehz WHERE rec_ts < ?', [cut]),
        liveBelow,
        reason: 'reading never writes');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
