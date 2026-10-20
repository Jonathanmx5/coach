import 'package:coach/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('décimales à la française', () {
    expect(formatDecimal(79.5), '79,5');
    expect(formatDecimal(80), '80,0');
    expect(formatDecimal(18.349, decimales: 2), '18,35');
  });

  test('millilitres en litres', () {
    expect(formatLitres(1500), '1,50');
    expect(formatLitres(250), '0,25');
    expect(formatLitres(0), '0,00');
  });

  test('tronquer : coupe avec « … » sans casser un émoji', () {
    expect(tronquer('Riz', 5), 'Riz');
    expect(tronquer('abcdef', 5), 'abcd…');
    expect(tronquer('abcdef', 5).length, 5);
    // L'émoji (2 unités UTF-16) occupe les positions 3 et 4 : il est retiré
    // en entier plutôt que coupé en deux.
    final coupe = tronquer('abc🍕defg', 5);
    expect(coupe, 'abc…');
    expect(coupe.length, lessThanOrEqualTo(5));
  });
}
