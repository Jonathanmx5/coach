import 'package:coach/journal/table_ciqual.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recherche : mots par début, sans accents, courts d\'abord', () async {
    final table = await TableCiqual.charger();
    expect(table.aliments.length, greaterThan(3000));
    final r = table.chercher('quinoa cuit');
    expect(r, isNotEmpty);
    expect(r.first.nom.toLowerCase(), contains('quinoa'));
    expect(table.chercher('creme brulee'), isNotEmpty);
    expect(table.chercher(''), isEmpty);
    expect(table.chercher('zzzzqq'), isEmpty);
  });

  test('un aliment Ciqual donne les apports de la portion', () async {
    final table = await TableCiqual.charger();
    final riz = table.chercher('riz basmati cuit').first;
    final a = riz.pour(200);
    expect(a.grammes, 200);
    expect(a.macros.kcal, closeTo(riz.kcal * 2, 1e-9));
    expect(a.reference, riz.nom);
    expect(a.nom.length, lessThanOrEqualTo(60));
  });
}
