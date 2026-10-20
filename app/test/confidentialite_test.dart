import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Textes de confidentialité : ce que l'appli et ses documents promettent
/// doit rester vérifiable, et aucune adresse e-mail n'y est publiée.
void main() {
  final arb = jsonDecode(
    File('lib/l10n/app_fr.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  final politique = File('../CONFIDENTIALITE.md').readAsStringSync();
  final publication = File('../PUBLICATION.md').readAsStringSync();
  final courriel = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');

  test('accord photo : pas de durée de conservation, traitement hors UE', () {
    final texte = arb['consentPhotoTexte'] as String;
    expect(texte, isNot(contains('jours')));
    expect(texte, isNot(contains('durée')));
    expect(texte, isNot(contains('conserver')));
    expect(
      texte,
      contains(
        "hors de l'Union européenne, par Google ou par "
        'Cloudflare',
      ),
    );
    expect(texte, contains('offre payante'));
    expect(texte, contains('entraîner'));
    expect(texte, contains('précision'));
  });

  test('montre : le poids importé est annoncé comme enregistré en ligne', () {
    final texte = arb['montreAide'] as String;
    expect(texte, isNot(contains('sans rien envoyer')));
    expect(texte, contains('seul ton poids le plus récent est enregistré'));
  });

  test('politique : Gemini sans durée non vérifiée, hors UE annoncé', () {
    expect(politique, isNot(contains('55 jours')));
    expect(politique, isNot(contains('durée limitée')));
    expect(
      politique,
      contains(
        "traitée hors de l'Union européenne, par Google ou par "
        'Cloudflare',
      ),
    );
    expect(politique, contains('précision'));
  });

  test('politique : diagnostic et sécurité déclarés', () {
    expect(politique, contains('## Diagnostic et sécurité'));
    expect(politique, contains('Crashlytics'));
    expect(politique, contains('Play Integrity'));
    expect(politique, contains('api.github.com'));
    expect(politique, contains('Sauvegarde automatique'));
  });

  test("effacement sans l'appli : identifiant seul, aucune adresse e-mail", () {
    expect(courriel.hasMatch(politique), isFalse);
    expect(courriel.hasMatch(publication), isFalse);
    expect(politique, contains("uniquement l'identifiant de compte"));
    expect(politique, contains('aucune autre donnée personnelle'));
    expect(
      politique,
      isNot(contains("l'adresse e-mail de votre compte Google")),
    );
    expect(
      publication,
      contains('TODO : remplacer par une adresse ou une page dédiée'),
    );
    expect(politique, isNot(contains('TODO')));
  });

  test('formulaire Play : journaux, identifiants et texte libre déclarés', () {
    expect(publication, contains('journaux de plantage'));
    expect(publication, contains("identifiants d'appareil"));
    expect(publication, contains('texte libre'));
    expect(publication, isNot(contains('temps limité')));
  });
}
