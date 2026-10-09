import 'package:coach/profil/saisie.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepte la virgule décimale française', () {
    expect(lireNombre('72,5'), 72.5);
  });

  test('accepte le point décimal', () {
    expect(lireNombre('72.5'), 72.5);
  });

  test('ignore les espaces autour', () {
    expect(lireNombre(' 180 '), 180);
  });

  test('refuse une saisie vide', () {
    expect(lireNombre(''), isNull);
  });

  test('refuse du texte', () {
    expect(lireNombre('abc'), isNull);
  });

  test('refuse plusieurs séparateurs', () {
    expect(lireNombre('1,2,3'), isNull);
  });
}
