// T-02 — the contract between the pipeline's `day_result.payload_json` and the
// read seam (lib/data/local_repository_impl.dart).
//
// The payload has no declared schema: the read seam indexes it by string keys
// and casts. test/fixtures/day_payload_contract.json pins, for every payload path
// whose keys the read seam names, the JSON types (with `null` and `absent`)
// that the WHOOP freeze goldens carry at the current kAlgoVersion.
//
// It fails when
//   * a key the seam reads changes type, becomes nullable, appears or
//     disappears in the pipeline's output (the goldens moved);
//   * kAlgoVersion is bumped and the contract was not regenerated and
//     reviewed with it;
//   * the seam stops naming a key the contract still lists (stale contract).
//
// Regenerate with `python3 tool/payload_contract.py` AFTER a deliberate bump
// has regenerated the goldens, and read the diff: it is the list of shape
// changes the seam must survive.
//
// Limit, stated: types are the ones the synthetic golden days produce. A
// path the goldens always fill can still be null on a real, thinner day — the
// seam must keep treating every read as nullable (AGENTS §3.3).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/derivation_engine.dart';

String _type(Object? v) => switch (v) {
      null => 'null',
      bool _ => 'bool',
      num _ => 'number',
      String _ => 'string',
      List _ => 'list',
      _ => 'map',
    };

void _walk(Object? v, String path, Map<String, Set<String>> out, int depth,
    int maxDepth) {
  (out[path] ??= {}).add(_type(v));
  if (v is Map && depth < maxDepth) {
    for (final e in v.entries) {
      _walk(e.value, '$path.${e.key}', out, depth + 1, maxDepth);
    }
  }
}

void main() {
  final contract = (jsonDecode(
          File('test/fixtures/day_payload_contract.json').readAsStringSync()) as Map)
      .cast<String, dynamic>();
  final paths = (contract['paths'] as Map).map(
      (k, v) => MapEntry(k as String, {for (final t in v as List) t as String}));
  final maxDepth = contract['max_depth'] as int;

  test('the contract was written for this kAlgoVersion', () {
    expect(contract['algo_version'], kAlgoVersion,
        reason: 'kAlgoVersion moved. Regenerate the goldens (owner approval), '
            'then `python3 tool/payload_contract.py`, and review the diff.');
  });

  test('every contract key is still named by the read seam', () {
    final seam = File('lib/data/local_repository_impl.dart').readAsStringSync();
    final literals = {
      for (final m in RegExp(r"'([a-z][a-z0-9_]*)'").allMatches(seam))
        m.group(1)!,
    };
    final stale = [
      for (final p in paths.keys)
        if (!p.split('.').every(literals.contains)) p,
    ];
    expect(stale, isEmpty,
        reason: 'the seam no longer names these: regenerate the contract');
  });

  test('the goldens carry exactly the contracted shape', () {
    final perDay = <Map<String, Set<String>>>[];
    final files = Directory('test/fixtures/whoop_freeze')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);
    for (final f in files) {
      final rows = (jsonDecode(f.readAsStringSync()) as Map)['day_result'] as List;
      for (final row in rows) {
        final out = <String, Set<String>>{};
        for (final e in ((row as Map)['payload_json'] as Map).entries) {
          _walk(e.value, e.key as String, out, 1, maxDepth);
        }
        perDay.add(out);
      }
    }
    final wrong = <String>[];
    for (final e in paths.entries) {
      final seen = <String>{
        for (final day in perDay) ...(day[e.key] ?? const {'absent'}),
      };
      if (seen.length != e.value.length || !seen.containsAll(e.value)) {
        wrong.add('${e.key}: contract ${e.value.toList()..sort()}, '
            'goldens ${seen.toList()..sort()}');
      }
    }
    expect(wrong, isEmpty,
        reason: 'the payload shape moved without the contract. If the change '
            'is intended it needs a kAlgoVersion bump (AGENTS §3.4).');
  });
}
