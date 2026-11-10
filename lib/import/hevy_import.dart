// HEVY — strength workouts from the Hevy app (api.hevyapp.com, Hevy Pro key).
//
// What it adds that the band cannot know: WHAT was lifted. The band measures
// the session (heart rate, strain, calories, zones); Hevy says it was bench
// press 4 × 8 at 80 kg. So a Hevy workout becomes:
//   * the sets, in `strength_set` (the table the in-app strength logger
//     already uses), keyed `hevy:<exercise title>`;
//   * on a band session that overlaps it when there is one (the band already
//     scored that window — the sets are attached to it, its type set to
//     weight training if it was something else);
//   * otherwise a new session over Hevy's start/end, scored from the band's
//     1 Hz substrate exactly like a hand-logged workout (`logManualWorkout`,
//     source `hevy`) — unscored, not invented, if the band was off.
// Sessions then flow everywhere a workout does: Home's activities, strain,
// the strength pillar of the physiological age, the coach (`v_sessions`,
// `v_strength_sets`).
//
// Read-only against Hevy: nothing is ever written back. The key lives in the
// keychain, never in prefs or a backup.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../compute/manual_session.dart' show ManualWindowException;
import '../data/db.dart';
import '../data/healthspan_inputs.dart' show kStrengthSessionTypes;
import '../data/local_repository.dart';

/// The session type a Hevy workout is logged as (catalogue "Weight training").
const String kHevySessionType = 'weight_training';

/// The `source` stamped on sessions Hevy created.
const String kHevySource = 'hevy';

/// Strength-set keys from Hevy: `hevy:<exercise title>`, readable as is.
const String kHevyExercisePrefix = 'hevy:';

/// First sync reaches this far back; later ones re-read from the last sync
/// minus [kHevyRelookback] so a workout edited in Hevy afterwards is caught.
const Duration kHevyFirstLookback = Duration(days: 90);
const Duration kHevyRelookback = Duration(days: 3);

class HevyException implements Exception {
  final String message;
  final int? status;
  const HevyException(this.message, {this.status});
  @override
  String toString() => message;
}

/// The window of a Hevy workout in epoch seconds, or null when it has no
/// usable one (missing, unparsable, or ending before it starts).
({int start, int end})? hevyWindow(Map<String, dynamic> w) {
  final s = DateTime.tryParse('${w['start_time'] ?? ''}');
  final e = DateTime.tryParse('${w['end_time'] ?? ''}');
  if (s == null || e == null) return null;
  final start = s.millisecondsSinceEpoch ~/ 1000;
  final end = e.millisecondsSinceEpoch ~/ 1000;
  return end > start ? (start: start, end: end) : null;
}

/// A Hevy workout's sets as `strength_set` rows, in the order lifted. Warm-up,
/// drop and failure sets are kept and named in `note`; a set with neither reps,
/// load nor duration carries nothing and is dropped. RPE is stored whole, as
/// the column is.
List<Map<String, Object?>> hevySetsOf(Map<String, dynamic> w, int atTs) {
  final out = <Map<String, Object?>>[];
  final exercises = (w['exercises'] as List?) ?? const [];
  for (final ex in exercises) {
    if (ex is! Map) continue;
    final title = '${ex['title'] ?? ''}'.trim();
    if (title.isEmpty) continue;
    final sets = (ex['sets'] as List?) ?? const [];
    var i = 0;
    for (final st in sets) {
      if (st is! Map) continue;
      final reps = (st['reps'] as num?)?.toInt();
      final load = (st['weight_kg'] as num?)?.toDouble();
      final secs = (st['duration_seconds'] as num?)?.toInt();
      if (reps == null && load == null && secs == null) continue;
      final type = '${st['type'] ?? 'normal'}';
      out.add({
        'exercise_key': '$kHevyExercisePrefix$title',
        'set_index': i++,
        'reps': reps,
        'load_kg': load,
        'rpe': (st['rpe'] as num?)?.round(),
        'hold_sec': secs,
        'rest_sec': null,
        'at_ts': atTs,
        'note': type == 'normal' ? '' : type,
      });
    }
  }
  return out;
}

/// `exercise title → exercise_template_id` for one workout, so the muscles of
/// each lift can be looked up once per template.
Map<String, String> hevyTemplatesOf(Map<String, dynamic> w) => {
      for (final ex in (w['exercises'] as List?) ?? const [])
        if (ex is Map &&
            '${ex['title'] ?? ''}'.trim().isNotEmpty &&
            ex['exercise_template_id'] != null)
          '${ex['title']}'.trim(): '${ex['exercise_template_id']}',
    };

/// The muscles of a Hevy exercise template, as `exercise_def` stores them.
Map<String, List<String>> hevyMusclesOf(Map<String, dynamic> template) => {
      'primary': [
        if ('${template['primary_muscle_group'] ?? ''}'.isNotEmpty)
          '${template['primary_muscle_group']}',
      ],
      'secondary': [
        for (final m
            in (template['secondary_muscle_groups'] as List?) ?? const [])
          '$m',
      ],
    };

/// The finished session a Hevy window should be attached to: the one it
/// overlaps most, provided they overlap by at least half of the SHORTER of
/// the two (a band-detected fragment of the gym session, or the session the
/// band scored around it). Null = log a new one.
Map<String, dynamic>? hevyAttachTarget(
    List<Map<String, dynamic>> candidates, int start, int end) {
  Map<String, dynamic>? best;
  var bestOverlap = 0;
  for (final r in candidates) {
    final s = (r['start_ts'] as num?)?.toInt();
    final e = (r['end_ts'] as num?)?.toInt();
    if (s == null || e == null || e <= s) continue;
    if ('${r['status'] ?? ''}' != 'done') continue;
    final overlap = (e < end ? e : end) - (s > start ? s : start);
    final shorter = (e - s) < (end - start) ? (e - s) : (end - start);
    if (overlap * 2 >= shorter && overlap > bestOverlap) {
      best = r;
      bestOverlap = overlap;
    }
  }
  return best;
}

class HevyApi {
  static const base = 'https://api.hevyapp.com/v1';
  final String apiKey;
  final http.Client _c;
  HevyApi(this.apiKey, {http.Client? client}) : _c = client ?? http.Client();

  /// One page of workouts, newest first.
  Future<({List<Map<String, dynamic>> workouts, int pageCount})> workouts(
      int page,
      {int pageSize = 10}) async {
    final resp = await _c
        .get(Uri.parse('$base/workouts?page=$page&pageSize=$pageSize'),
            headers: {'api-key': apiKey, 'accept': 'application/json'})
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw HevyException('Hevy refused the key (${resp.statusCode}).',
          status: resp.statusCode);
    }
    // Past the last page Hevy answers 404 rather than an empty list.
    if (resp.statusCode == 404) return (workouts: const <Map<String, dynamic>>[], pageCount: page - 1);
    if (resp.statusCode != 200) {
      throw HevyException('Hevy error (${resp.statusCode}).',
          status: resp.statusCode);
    }
    final j = jsonDecode(utf8.decode(resp.bodyBytes));
    if (j is! Map) throw const HevyException('Unexpected reply from Hevy.');
    return (
      workouts: [
        for (final w in (j['workouts'] as List?) ?? const [])
          if (w is Map) w.cast<String, dynamic>(),
      ],
      pageCount: (j['page_count'] as num?)?.toInt() ?? page,
    );
  }

  /// One exercise template (name, primary and secondary muscle groups), or
  /// null when Hevy has no such template.
  Future<Map<String, dynamic>?> exerciseTemplate(String id) async {
    final resp = await _c
        .get(Uri.parse('$base/exercise_templates/${Uri.encodeComponent(id)}'),
            headers: {'api-key': apiKey, 'accept': 'application/json'})
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(resp.bodyBytes));
    return j is Map ? j.cast<String, dynamic>() : null;
  }

  void close() => _c.close();
}

/// The key, in the keychain, and when the last sync finished.
class HevyStore {
  static const _kKey = 'hevy_api_key';
  static const _kLastSync = 'hevy_last_sync_ms';
  static const _secure = FlutterSecureStorage();
  static const _apple =
      IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  static Future<String?> key() async {
    try {
      final k = await _secure.read(key: _kKey, iOptions: _apple);
      return k == null || k.trim().isEmpty ? null : k.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> setKey(String? key) async {
    final k = key?.trim() ?? '';
    if (k.isEmpty) {
      await _secure.delete(key: _kKey, iOptions: _apple);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLastSync);
    } else {
      await _secure.write(key: _kKey, value: k, iOptions: _apple);
    }
  }

  static Future<DateTime?> lastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastSync);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> markSynced(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastSync, at.millisecondsSinceEpoch);
  }
}

typedef HevySyncResult = ({
  int created,
  int attached,
  int updated,
  int skipped,
  int sets,
});

class HevySync {
  static bool _running = false;

  /// Pull Hevy workouts since the last sync (or [kHevyFirstLookback]) and
  /// file them as described at the top of this file. Idempotent: a workout
  /// already filed has its sets replaced, never duplicated. One at a time —
  /// a second call while one runs returns null.
  static Future<HevySyncResult?> run(
    LocalRepository repo, {
    String? apiKey,
    http.Client? client,
    DateTime? now,
    int maxPages = 40,
  }) async {
    if (_running) return null;
    _running = true;
    final key = apiKey ?? await HevyStore.key();
    if (key == null) {
      _running = false;
      return null;
    }
    final api = HevyApi(key, client: client);
    final t = now ?? DateTime.now();
    final last = await HevyStore.lastSync();
    final cutoff = (last == null
            ? t.subtract(kHevyFirstLookback)
            : last.subtract(kHevyRelookback))
        .millisecondsSinceEpoch ~/
        1000;
    var created = 0, attached = 0, updated = 0, skipped = 0, sets = 0;
    final templates = <String, String>{};
    try {
      pages:
      for (var page = 1; page <= maxPages; page++) {
        final r = await api.workouts(page);
        if (r.workouts.isEmpty) break;
        for (final w in r.workouts) {
          final win = hevyWindow(w);
          if (win == null) {
            skipped++;
            continue;
          }
          // Newest first: the first one older than the cutoff ends the walk.
          if (win.start < cutoff) break pages;
          final rows = hevySetsOf(w, win.start);
          templates.addAll(hevyTemplatesOf(w));
          final outcome = await _file(repo, win.start, win.end, rows);
          switch (outcome) {
            case 'created':
              created++;
            case 'attached':
              attached++;
            case 'updated':
              updated++;
            default:
              skipped++;
          }
          if (outcome != 'skipped') sets += rows.length;
        }
        if (page >= r.pageCount) break;
      }
      // The muscles of every lift not described yet, so Home can count the
      // week's sets per muscle group. Bounded per sync; the rest next time.
      try {
        final known = await LocalDb.exerciseDefs(
            templates.keys.map((t) => '$kHevyExercisePrefix$t'));
        var fetched = 0;
        for (final e in templates.entries) {
          final key = '$kHevyExercisePrefix${e.key}';
          if (known.containsKey(key) || fetched >= 60) continue;
          fetched++;
          final tpl = await api.exerciseTemplate(e.value);
          if (tpl == null) continue;
          await LocalDb.putExerciseDef(key, e.key, hevyMusclesOf(tpl),
              equipment: '${tpl['equipment'] ?? ''}');
        }
      } catch (_) {
        // Muscles are a nicety; the workouts above are already filed.
      }
      await HevyStore.markSynced(t);
      return (
        created: created,
        attached: attached,
        updated: updated,
        skipped: skipped,
        sets: sets,
      );
    } finally {
      api.close();
      _running = false;
    }
  }

  static Future<String> _file(LocalRepository repo, int start, int end,
      List<Map<String, Object?>> rows) async {
    // Already filed by an earlier sync: a Hevy-created session starts exactly
    // here, or a session in the window already carries Hevy sets.
    final nearby = await LocalDb.sessionsInRange(start - 6 * 3600, end);
    for (final r in nearby) {
      final id = r['id'];
      if (id is! String) continue;
      final own = r['source'] == kHevySource &&
          (r['start_ts'] as num?)?.toInt() == start;
      if (own || await _hasHevySets(id, start)) {
        await LocalDb.replaceStrengthSets(id, rows);
        return 'updated';
      }
    }
    final target = hevyAttachTarget(nearby, start, end);
    if (target != null) {
      final id = target['id'] as String;
      // The athlete logged sets for this session in the app themselves: theirs
      // stand, Hevy's are not mixed in.
      if ((await LocalDb.strengthSets(id)).isNotEmpty) return 'skipped';
      await LocalDb.replaceStrengthSets(id, rows);
      if (!kStrengthSessionTypes.contains('${target['type']}')) {
        await LocalDb.setSessionType(id, kHevySessionType);
      }
      return 'attached';
    }
    try {
      final r = await repo.logManualWorkout(
          startTs: start,
          endTs: end,
          type: kHevySessionType,
          source: kHevySource);
      final id = r['workout_id'];
      if (id is! String) return 'skipped';
      await LocalDb.replaceStrengthSets(id, rows);
      return 'created';
    } on ManualWindowException {
      return 'skipped';
    }
  }

  static Future<bool> _hasHevySets(String sessionId, int start) async {
    final s = await LocalDb.strengthSets(sessionId);
    return s.any((r) =>
        '${r['exercise_key']}'.startsWith(kHevyExercisePrefix) &&
        (r['at_ts'] as num?)?.toInt() == start);
  }
}
