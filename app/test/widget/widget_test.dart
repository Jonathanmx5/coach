import 'package:coach/bienetre/hydratation.dart';
import 'package:coach/widget/donnees_widget.dart';
import 'package:coach/widget/rappel_widget.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

DonneesWidget donnees({
  double brulees = 1500,
  double mangees = 1000,
  int eau = 1000,
}) => DonneesWidget(
  brulees: brulees,
  objectifBrule: 2000,
  mangees: mangees,
  objectifMange: 2000,
  proteines: 64,
  objectifProteines: 128,
  eauMl: eau,
  objectifEauMl: 2500,
);

void main() {
  test('chiffres du widget : progrès, eau et bilan', () {
    final d = donnees();
    expect(d.progres, [0.75, 0.5, 0.5, 0.4]);
    expect(d.eauTexte, '1,00 / 2,50 L');
    expect(d.bilanLigne, 'Bilan −500 kcal');
    expect(donnees(mangees: 1700).bilanLigne, 'Bilan +200 kcal');
  });

  test('objectif nul : pas de division par zéro', () {
    const d = DonneesWidget(
      brulees: 10,
      objectifBrule: 0,
      mangees: 0,
      objectifMange: 0,
      proteines: 0,
      objectifProteines: 0,
      eauMl: 0,
      objectifEauMl: 0,
    );
    expect(d.progres, [0, 0, 0, 0]);
  });

  test('égalité : un arrondi près, donc pas de renvoi inutile', () {
    expect(donnees(brulees: 1500.2), donnees(brulees: 1499.8));
    expect(
      donnees(brulees: 1500.2).hashCode,
      donnees(brulees: 1499.8).hashCode,
    );
    expect(donnees(eau: 1000), isNot(donnees(eau: 1250)));
    expect(donnees(mangees: 1000), isNot(donnees(mangees: 1010)));
  });

  group('boutons d\'eau du widget', () {
    final matin = DateTime(2026, 10, 9, 8, 30);

    test('l\'eau est enregistrée et le texte du widget mis à jour', () async {
      final depot = FauxBienEtre();
      final stock = FauxStockageWidget()
        ..valeurs['eau_jour'] = '2026-10-09'
        ..valeurs['eau_ml'] = '750'
        ..valeurs['eau_objectif_ml'] = '2650';

      final total = await ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 250,
        maintenant: matin,
        depot: depot,
        stockage: stock,
      );

      expect(total, 1000);
      expect(depot.eauDe('u1').single.ml, 250);
      expect(depot.eauDe('u1').single.date, matin);
      expect(stock.valeurs['eau_ml'], '1000');
      expect(stock.valeurs['eau_texte'], '1,00 / 2,65 L');
      expect(stock.rafraichissements, 1);
    });

    test('un autre jour, on repart de zéro', () async {
      final stock = FauxStockageWidget()
        ..valeurs['eau_jour'] = '2026-10-08'
        ..valeurs['eau_ml'] = '2400'
        ..valeurs['eau_objectif_ml'] = '2000';
      final total = await ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 500,
        maintenant: matin,
        depot: FauxBienEtre(),
        stockage: stock,
      );
      expect(total, 500);
      expect(stock.valeurs['eau_jour'], '2026-10-09');
      expect(stock.valeurs['eau_texte'], '0,50 / 2,00 L');
    });

    test('sans données de l\'appli : objectif par défaut de 2 L', () async {
      final stock = FauxStockageWidget();
      await ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 250,
        maintenant: matin,
        depot: FauxBienEtre(),
        stockage: stock,
      );
      expect(stock.valeurs['eau_texte'], '0,25 / 2,00 L');
    });

    test('deux appuis de suite s\'additionnent', () async {
      final depot = FauxBienEtre();
      final stock = FauxStockageWidget();
      await ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 250,
        maintenant: matin,
        depot: depot,
        stockage: stock,
      );
      final total = await ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 500,
        maintenant: matin,
        depot: depot,
        stockage: stock,
      );
      expect(total, 750);
      expect(totalEauMl(depot.eauDe('u1')), 750);
    });
  });

  test('la clé du jour est zéro-remplie', () {
    expect(cleDuJour(DateTime(2026, 1, 5, 23)), '2026-01-05');
  });
}
