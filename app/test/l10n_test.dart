import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Clés de premier niveau de l'ARB, dans l'ordre, doublons compris (un
/// décodage JSON ne garderait que la dernière définition).
List<String> clesArb(String contenu) => [
  for (final ligne in contenu.split('\n'))
    if (RegExp(r'^  "([^"]+)"\s*:').firstMatch(ligne) case final m?) m[1]!,
];

void main() {
  test('les clés sont lues ligne à ligne, doublons compris', () {
    const arb = '{\n  "a": "x",\n  "@a": {\n    "b": 1\n  },\n  "a": "y"\n}\n';
    expect(clesArb(arb), ['a', '@a', 'a']);
  });

  test("l'ARB français ne contient aucune clé en double", () {
    final cles = clesArb(File('lib/l10n/app_fr.arb').readAsStringSync());
    expect(cles, isNotEmpty);
    final vues = <String>{};
    final doublons = [
      for (final c in cles)
        if (!vues.add(c)) c,
    ];
    expect(doublons, isEmpty);
  });
}
