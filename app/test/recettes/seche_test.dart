import 'dart:io';

import 'package:coach/journal/modele.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/recettes/avis.dart';
import 'package:coach/recettes/catalogue.dart';
import 'package:coach/recettes/modele.dart';
import 'package:coach/recettes/recettes_seche.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les recettes de sèche respectent leurs critères', () {
    expect(recettesSeche.length, greaterThanOrEqualTo(30));
    for (final r in recettesSeche) {
      expect(recettePourSeche(r), isTrue, reason: r.id);
      expect(recetteAdapteeFitness(r), isTrue, reason: r.id);
      // Les calories collent aux macros (4-4-9), à 15 % près.
      final m = r.macros;
      final calcule = 4 * m.proteines + 4 * m.glucides + 9 * m.lipides;
      expect((calcule - m.kcal).abs() / m.kcal, lessThan(0.15), reason: r.id);
      expect(
        File('assets/recettes/${r.id}.jpg').existsSync(),
        isTrue,
        reason: r.id,
      );
    }
  });

  test('chaque moment a des idées de sèche', () {
    for (final m in Moment.values) {
      expect(
        recettesSeche.where((r) => r.moment == m).length,
        greaterThan(3),
        reason: '$m',
      );
    }
  });

  test('identifiants uniques dans tout le catalogue', () {
    final ids = catalogueRecettes.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('filtre sèche : seulement des recettes pour une sèche', () {
    final deck = construireDeck(
      avis: const {},
      objectif: Objectif.perte,
      graine: 1,
      seche: true,
    );
    expect(deck, isNotEmpty);
    expect(deck.every(recettePourSeche), isTrue);
  });

  test('perte de poids : les recettes de sèche sont favorisées', () {
    final r = recettesSeche.first;
    expect(
      affinite(r, Objectif.perte),
      greaterThan(affinite(r, Objectif.forme)),
    );
  });
}
