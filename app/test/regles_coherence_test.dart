import 'dart:io';

import 'package:coach/compte/donnees_compte.dart';
import 'package:coach/sauvegarde/sauvegarde.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les règles Firestore et le code décrivent les mêmes collections et les
/// mêmes champs : un ajout d'un seul côté ferait refuser les écritures en
/// production, sans qu'aucun test Dart (FakeFirebaseFirestore n'applique pas
/// les règles) ne le voie.
void main() {
  final regles = File('../firebase/firestore.rules').readAsStringSync();

  Set<String> chaines(String texte) => {
    for (final m in RegExp(r"'(\w+)'").allMatches(texte)) m.group(1)!,
  };

  test('les collections lisibles sont celles effacées avec le compte', () {
    final liste = RegExp(r'collection in \[([^\]]*)\]')
        .firstMatch(regles)!
        .group(1)!;
    expect(chaines(liste), FirestoreDonneesCompte.collections.toSet());
  });

  /// Collection → fonction de validation, lues dans documentValide.
  Map<String, String> validations() => {
    for (final m in RegExp(
      r"collection == '(\w+)' && (\w+)\(",
    ).allMatches(regles))
      m.group(1)!: m.group(2)!,
  };

  test('chaque collection a sa validation en écriture, et pas d\'autre', () {
    expect(
      validations().keys.toSet(),
      FirestoreDonneesCompte.collections.toSet(),
    );
    // Plus de joker récursif : aucune sous-collection imbriquée.
    expect(regles, isNot(contains('=**')));
  });

  test('les champs importables sont ceux acceptés par les règles', () {
    final fonctions = validations();
    for (final e in champsImportables.entries) {
      final nom = fonctions[e.key];
      expect(nom, isNotNull, reason: e.key);
      final corps = RegExp(
        'function $nom\\(d\\) \\{(.*?)\\n    \\}',
        dotAll: true,
      ).firstMatch(regles)!.group(1)!;
      final hasOnly = RegExp(
        r'hasOnly\(\[(.*?)\]\)',
        dotAll: true,
      ).firstMatch(corps)!.group(1)!;
      expect(chaines(hasOnly), e.value, reason: e.key);
    }
  });
}
