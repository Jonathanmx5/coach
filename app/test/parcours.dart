import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gestes communs aux tests d'écrans.
Future<void> taper(WidgetTester tester, String texte) async {
  // Les listes longues ne construisent pas ce qui est hors écran.
  if (find.text(texte).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(texte),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(find.text(texte).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(texte).last);
  await tester.pumpAndSettle();
}

Future<void> saisir(WidgetTester tester, String champ, String valeur) async {
  await tester.enterText(find.widgetWithText(TextField, champ), valeur);
  await tester.pumpAndSettle();
}

/// Répond à tout le questionnaire jusqu'à l'étape santé incluse
/// (perte, homme, 30 ans, 180 cm, 80,5 kg, un peu actif, salle, débutant,
/// 3 jours, 45 min).
Future<void> remplirJusquaSante(
  WidgetTester tester, {
  bool sante = false,
}) async {
  await taper(tester, 'Perdre du poids');
  await taper(tester, 'Suivant');
  await taper(tester, 'Homme');
  await saisir(tester, 'Âge', '30');
  await taper(tester, 'Suivant');
  await saisir(tester, 'Taille (cm)', '180');
  await saisir(tester, 'Poids (kg)', '80,5');
  await taper(tester, 'Suivant');
  await taper(tester, 'Un peu actif');
  await taper(tester, 'Suivant');
  await taper(tester, 'Salle de sport');
  await taper(tester, 'Suivant');
  await taper(tester, 'Débutant');
  await taper(tester, 'Suivant');
  await taper(tester, '3');
  await taper(tester, '45 min');
  await taper(tester, 'Suivant');
  await taper(tester, sante ? 'Oui' : 'Non');
}

/// Depuis l'étape santé : répond « Non » à la montre et passe à la suite.
Future<void> sansMontre(WidgetTester tester) async {
  await taper(tester, 'Suivant');
  await taper(tester, 'Non');
  await taper(tester, 'Suivant');
}

/// Fait défiler la liste jusqu'à [cible] (construite seulement si visible).
Future<void> defilerJusqua(WidgetTester tester, Finder cible) async {
  if (cible.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      cible,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
}
