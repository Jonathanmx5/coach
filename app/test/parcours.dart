import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gestes communs aux tests d'écrans.
Future<void> taper(WidgetTester tester, String texte) async {
  await tester.ensureVisible(find.text(texte).last);
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
Future<void> remplirJusquaSante(WidgetTester tester, {bool sante = false}) async {
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
