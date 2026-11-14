// Fork-only guard: gen-l10n silently falls back to English for a key a locale
// lacks, which is how the Spanish UI ended up with 621 English strings. This
// fails when an upstream merge brings English copy that Spanish hasn't got.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/l10n/app_localizations.dart';

void main() {
  Map<String, dynamic> arb(String code) =>
      jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('Spanish covers the English messages and preserves ICU arguments', () {
    final en = arb('en');
    final es = arb('es');
    final keys = en.keys.where((key) => !key.startsWith('@')).toSet();
    expect(es['@@locale'], 'es');
    expect(keys.difference(es.keys.toSet()), isEmpty);
    for (final key in keys) {
      expect(es[key], isA<String>(), reason: key);
      expect((es[key] as String).trim(), isNotEmpty, reason: key);
      final metadata = en['@$key'] as Map<String, dynamic>?;
      final arguments = metadata?['placeholders'] as Map<String, dynamic>?;
      for (final argument in arguments?.keys ?? <String>[]) {
        expect(
          RegExp('\\{${RegExp.escape(argument)}(?:\\}|,)')
              .hasMatch(es[key] as String),
          isTrue,
          reason: '$key must preserve $argument',
        );
      }
    }
  });

  test('Spanish plurals and placeholders render', () {
    final es = lookupAppLocalizations(const Locale('es'));
    expect(es.homeFirstWeekSoFar(1), '1 día grabado hasta ahora');
    expect(es.homeFirstWeekSoFar(4), '4 días grabados hasta ahora');
    expect(es.homeRecoveryStartsIn(3),
        'La recuperación empieza dentro de 3 noches');
    // The activity catalogue had a select with no Spanish case at all, so
    // every quick-start tile read in English. Upstream's wording since the
    // 2026-11-14 merge (spanish_coverage_test pins the same).
    expect(es.activityCatalogueName('krunning', 'Running'), 'Carrera');
    expect(es.activityCatalogueName('kweighttraining', 'Weight training'),
        'Entrenamiento con pesas');
    expect(es.activityCatalogueName('kunknownsport', 'Unknown sport'),
        'Unknown sport');
    expect(es.whoopFirmwareWarningTitle,
        'Si tienes una WHOOP: no vuelvas a conectarla a la app de WHOOP');
  });
}
