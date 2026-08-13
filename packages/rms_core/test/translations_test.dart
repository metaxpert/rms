import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The shared catalogue's parity. See the per-app copy of this test for why a
/// missing key is worse than an untranslated screen.
void main() {
  Map<String, dynamic> arb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  Set<String> keysOf(Map<String, dynamic> catalogue) =>
      catalogue.keys.where((key) => !key.startsWith('@')).toSet();

  test('every English key is translated into Urdu', () {
    final en = keysOf(arb('l10n/rms_en.arb'));
    final ur = keysOf(arb('l10n/rms_ur.arb'));

    expect(en.difference(ur), isEmpty, reason: 'untranslated');
    expect(ur.difference(en), isEmpty, reason: 'translated but unused');
  });

  test('a placeholder in English survives into Urdu', () {
    final en = arb('l10n/rms_en.arb');
    final ur = arb('l10n/rms_ur.arb');
    final placeholder = RegExp(r'\{(\w+)[,}]');

    for (final key in keysOf(en)) {
      final source = en[key];
      final target = ur[key];
      if (source is! String || target is! String) continue;
      expect(
        placeholder.allMatches(target).map((m) => m.group(1)).toSet(),
        placeholder.allMatches(source).map((m) => m.group(1)).toSet(),
        reason: 'placeholders differ in "$key"',
      );
    }
  });
}
