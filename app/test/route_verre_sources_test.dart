import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tout écran poussé passe par `routeVerre` : une `MaterialPageRoute` nue
/// n'aurait pas de fond de verre (Scaffold transparent sur fond vide).
void main() {
  test('aucune MaterialPageRoute en dehors de route_verre.dart', () {
    final fautifs = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.replaceAll(r'\', '/').endsWith('lib/route_verre.dart') &&
            f.readAsStringSync().contains('MaterialPageRoute'))
          f.path,
    ];
    expect(fautifs, isEmpty);
  });
}
