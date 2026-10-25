import 'package:coach/journal/preferences_analyse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('la taille de l\'assiette passe avant la précision', () {
    expect(indiceAvecAssiette('', null), '');
    expect(indiceAvecAssiette('  sauce à part ', null), 'sauce à part');
    expect(indiceAvecAssiette('', 26), 'Assiette de 26 cm de diamètre.');
    expect(
      indiceAvecAssiette('la moitié', 24),
      'Assiette de 24 cm de diamètre. la moitié',
    );
  });

  test('clé d\'aliment : sans accents, majuscules ni parenthèses', () {
    expect(cleAliment('Riz (basmati)'), 'riz');
    expect(cleAliment('  Pâtes  complètes '), 'pates completes');
    expect(cleAliment('Œuf dur'), 'oeuf dur');
  });

  test('étalonnage : moyenne géométrique, rapports bornés', () {
    var e = etalonner(null, 1.2);
    expect(e.nombre, 1);
    expect(e.facteur, closeTo(1.2, 1e-9));
    // Un seul repas ne suffit pas.
    expect(facteurAppris(e), 1);
    e = etalonner(e, 1.2);
    expect(facteurAppris(e), closeTo(1.2, 1e-9));
    // Une saisie aberrante (×10) compte comme ×2 au plus.
    final f = etalonner(etalonner(null, 1), 10);
    expect(f.facteur, closeTo(1.41421, 1e-4));
    // Écart de moins de 5 % : on ne touche à rien ; borné à 0,6 et 1,6.
    expect(facteurAppris(const Etalonnage(1.03, 5)), 1);
    expect(facteurAppris(const Etalonnage(3, 5)), 1.6);
    expect(facteurAppris(const Etalonnage(0.3, 5)), 0.6);
  });

  test('apprendre : par aliment, après deux repas', () async {
    final p = PreferencesAnalyseMemoire();
    await p.apprendre('Pâtes', estime: 200, retenu: 250);
    expect(p.facteurPour('pates'), 1);
    await p.apprendre('pâtes (penne)', estime: 200, retenu: 250);
    expect(p.facteurPour('Pâtes'), closeTo(1.25, 1e-9));
    expect(p.facteurPour('Riz'), 1);
    // Valeurs absurdes ignorées.
    await p.apprendre('Riz', estime: 0, retenu: 100);
    expect(p.appris.containsKey('riz'), isFalse);
    await p.oublier();
    expect(p.facteurPour('Pâtes'), 1);
  });

  test('au plus 200 aliments retenus, les plus anciens oubliés', () async {
    final p = PreferencesAnalyseMemoire();
    for (var i = 0; i < 205; i++) {
      await p.apprendre('aliment $i', estime: 100, retenu: 120);
    }
    expect(p.appris.length, PreferencesAnalyseMemoire.maxAliments);
    expect(p.appris.containsKey('aliment 0'), isFalse);
    expect(p.appris.containsKey('aliment 204'), isTrue);
  });

  test('gardé sur le téléphone et relu au démarrage', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PreferencesAnalyseLocales.charger();
    expect(p.assietteCm, isNull);
    await p.definirAssiette(26);
    await p.apprendre('Riz', estime: 100, retenu: 80);
    await p.apprendre('Riz', estime: 100, retenu: 80);

    final relu = await PreferencesAnalyseLocales.charger();
    expect(relu.assietteCm, 26);
    expect(relu.facteurPour('riz'), closeTo(0.8, 1e-9));

    await relu.definirAssiette(null);
    expect((await PreferencesAnalyseLocales.charger()).assietteCm, isNull);

    // Données abîmées : on repart de zéro sans planter.
    SharedPreferences.setMockInitialValues({
      'analyse_etalonnage': '{pas du json',
      'analyse_assiette_cm': 999,
    });
    final abime = await PreferencesAnalyseLocales.charger();
    expect(abime.assietteCm, isNull);
    expect(abime.appris, isEmpty);
  });

  test('huile et sauce peu visibles : valeurs ajoutées', () {
    expect(
      grasAjoutes(
        huile: QuantiteGras.aucune,
        sauce: QuantiteGras.aucune,
        nomHuile: 'Huile',
        nomSauce: 'Sauce',
      ),
      isEmpty,
    );
    final un = grasAjoutes(
      huile: QuantiteGras.unPeu,
      sauce: QuantiteGras.beaucoup,
      nomHuile: 'Huile',
      nomSauce: 'Sauce',
    );
    expect(un.map((a) => a.nom), ['Huile', 'Sauce']);
    expect(un[0].macros.kcal, 45);
    expect(un[0].grammes, 5);
    expect(un[1].macros.kcal, 200);
    // Ajoutés à la main : jamais « à vérifier ».
    expect(un.any((a) => a.aVerifier), isFalse);
  });
}
