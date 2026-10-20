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
}
