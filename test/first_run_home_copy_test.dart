// The first-run sentences reach the screen through presentationText, which
// only translates an English literal it knows. A sentence that whyFromNote
// returns but the map does not list shows up in English in every locale.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/l10n/presentation_text.dart';
import 'package:openstrap_edge/models/metric.dart';

void main() {
  final note = whyFromNote('no readiness inputs present — "—" (never imputed).')!;

  test('the no-night sentence is translated wherever it is shown', () {
    for (final code in ['de', 'es', 'fr', 'hi', 'ru', 'th', 'zh']) {
      final l = lookupAppLocalizations(Locale(code));
      expect(presentationText(l, note), l.homeRecoveryNoNightToScore,
          reason: code);
      expect(presentationText(l, note), isNot(note), reason: code);
    }
  });

  test('the derive card no longer promises last night on its own', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.homeAnalyzingTitle, isNot(contains('last night')));
    expect(en.homeAnalyzingFirstBody, contains('a night with the band on'));
    final es = lookupAppLocalizations(const Locale('es'));
    expect(es.homeAnalyzingTitle, 'Actualizando tus números');
  });

  test('derive progress reads as a day count', () {
    expect(lookupAppLocalizations(const Locale('en')).homeAnalyzingProgress(3, 12),
        'Day 3 of 12.');
    expect(lookupAppLocalizations(const Locale('es')).homeAnalyzingProgress(3, 12),
        'Día 3 de 12.');
  });
}
