import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Parity between the catalogues.
///
/// A key present in English and missing in Urdu does not fail loudly — it falls
/// back to English, so a translated screen ends up half in each language
/// mid-sentence. That reads worse than not translating the screen at all, and
/// it is invisible to anyone who does not speak both. So it is a test.
void main() {
  Map<String, dynamic> arb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  Set<String> keysOf(Map<String, dynamic> catalogue) => catalogue.keys
      // `@@locale` is metadata; `@key` entries are placeholder declarations,
      // which only the template carries.
      .where((key) => !key.startsWith('@'))
      .toSet();

  test('every English key is translated into Urdu', () {
    final en = keysOf(arb('l10n/app_en.arb'));
    final ur = keysOf(arb('l10n/app_ur.arb'));

    expect(en.difference(ur), isEmpty, reason: 'untranslated');
    expect(ur.difference(en), isEmpty, reason: 'translated but unused');
  });

  test('a placeholder in English survives into Urdu', () {
    // A dropped `{count}` turns "3 orders are ready" into "orders are ready",
    // which is worse than English.
    final en = arb('l10n/app_en.arb');
    final ur = arb('l10n/app_ur.arb');
    final placeholder = RegExp(r'\{(\w+)[,}]');

    for (final key in keysOf(en)) {
      final source = en[key];
      final target = ur[key];
      if (source is! String || target is! String) continue;
      final expected =
          placeholder.allMatches(source).map((m) => m.group(1)).toSet();
      final actual =
          placeholder.allMatches(target).map((m) => m.group(1)).toSet();
      expect(actual, expected, reason: 'placeholders differ in "$key"');
    }
  });

  test('no key is translated that nothing uses', () {
    // A translator's time is not free, and a key orphaned by a refactor is
    // indistinguishable from one that is merely hard to find. Scanning the
    // source is the only way to tell.
    final keys = keysOf(arb('l10n/app_en.arb'));
    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final orphans = keys
        .where((key) => !RegExp('\\.$key\\b').hasMatch(source))
        .toList();
    expect(orphans, isEmpty, reason: 'translated but never shown');
  });
}
