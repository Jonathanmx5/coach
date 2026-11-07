import 'package:coach/journal/modele.dart';
import 'package:coach/recettes/catalogue.dart';
import 'package:coach/recettes/modele.dart';
import 'package:coach/recettes/planning.dart';
import 'package:coach/recettes/planning_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final lundi = DateTime(2026, 10, 5);

void main() {
  test('catalogue : ids uniques, étapes, ingrédients, macros cohérentes', () {
    final ids = catalogueRecettes.map((r) => r.id).toSet();
    expect(ids.length, catalogueRecettes.length);
    for (final r in catalogueRecettes) {
      expect(r.ingredients, isNotEmpty, reason: r.id);
      expect(r.etapes, isNotEmpty, reason: r.id);
      final m = r.macros;
      final calculees = m.proteines * 4 + m.glucides * 4 + m.lipides * 9;
      expect(
        (calculees - m.kcal).abs() / m.kcal,
        lessThan(0.15),
        reason: '${r.id} : $calculees vs ${m.kcal}',
      );
    }
    for (final m in Moment.values) {
      expect(recettesPour(m, vegetarien: true).length, greaterThanOrEqualTo(2));
    }
  });

  test('catalogue : uniquement des recettes fitness et remise en forme', () {
    expect(catalogueRecettes.length, greaterThanOrEqualTo(25));
    for (final r in catalogueRecettes) {
      final m = r.macros;
      expect(recetteAdapteeFitness(r), isTrue, reason: r.id);
      expect(
        m.proteines * 4 / m.kcal,
        greaterThanOrEqualTo(0.16),
        reason: '${r.id} manque de protéines',
      );
      expect(
        m.lipides * 9 / m.kcal,
        lessThanOrEqualTo(0.42),
        reason: '${r.id} est trop gras',
      );
      expect(m.kcal, inInclusiveRange(100, 650), reason: r.id);
    }
    // Les plats gras ou sucrés retirés ne reviennent pas par erreur.
    for (final id in [
      'tartine_avocat',
      'curry_pois_chiches',
      'galettes_cacahuete',
    ]) {
      expect(recetteOuNull(id), isNull, reason: id);
    }
  });

  test('un planning enregistré avec une recette retirée est à refaire', () {
    final p = Planning.fromMap(DateTime(2026, 10, 5), {
      'repas': {
        '0': {
          'petitDejeuner': {'id': 'tartine_avocat', 'p': 1},
        },
      },
    });
    expect(estComplet(p), isFalse);
    expect(
      estComplet(
        genererPlanning(lundi: DateTime(2026, 10, 5), kcalCible: 2000),
      ),
      isTrue,
    );
  });

  test('lundiDe', () {
    expect(lundiDe(DateTime(2026, 10, 11, 23)), DateTime(2026, 10, 5));
    expect(lundiDe(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    expect(lundiDe(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
  });

  test('portions : pas de 0,25 entre 0,5 et 2', () {
    final r = recetteParId('porridge_banane'); // 430 kcal
    expect(portionsPour(r, 430), 1);
    expect(portionsPour(r, 645), 1.5);
    expect(portionsPour(r, 50), 0.5);
    expect(portionsPour(r, 5000), 2);
  });

  test('planning : 7 jours × 4 repas, calories proches de la cible', () {
    for (final cible in [1500.0, 2000.0, 2600.0]) {
      final p = genererPlanning(lundi: lundi, kcalCible: cible);
      expect(p.jours.length, 7);
      for (final j in p.jours.values) {
        expect(j.keys.toSet(), Moment.values.toSet());
        final kcal = macrosDuJour(j).kcal;
        expect(
          kcal,
          inInclusiveRange(cible * 0.8, cible * 1.2),
          reason: '$cible',
        );
      }
    }
  });

  test('planning : jamais deux fois la même recette de suite', () {
    final p = genererPlanning(lundi: lundi, kcalCible: 2000);
    for (var j = 0; j < 6; j++) {
      for (final m in Moment.values) {
        expect(
          p.jours[j]![m]!.recetteId,
          isNot(p.jours[j + 1]![m]!.recetteId),
          reason: '$j $m',
        );
      }
    }
    final suivante = genererPlanning(
      lundi: DateTime(2026, 10, 12),
      kcalCible: 2000,
    );
    expect(
      suivante.jours[0]![Moment.dejeuner]!.recetteId,
      isNot(p.jours[0]![Moment.dejeuner]!.recetteId),
    );
  });

  test('planning végétarien : aucune viande ni poisson', () {
    final p = genererPlanning(lundi: lundi, kcalCible: 2000, vegetarien: true);
    for (final j in p.jours.values) {
      for (final r in j.values) {
        expect(recetteParId(r.recetteId).vegetarien, isTrue);
      }
    }
  });

  test('courses : quantités additionnées, groupées par rayon', () {
    final p = Planning(
      lundi: lundi,
      jours: {
        0: {Moment.dejeuner: const RepasPlanifie('poulet_riz_brocoli', 2)},
        1: {Moment.dejeuner: const RepasPlanifie('poulet_riz_brocoli', 1)},
        2: {Moment.dejeuner: const RepasPlanifie('poke_bowl_saumon', 1)},
        3: {Moment.dejeuner: const RepasPlanifie('poke_bowl_saumon', 1)},
        4: {Moment.dejeuner: const RepasPlanifie('poke_bowl_saumon', 1)},
        5: {Moment.petitDejeuner: const RepasPlanifie('omelette_pain', 1)},
      },
    );
    final l = listeCourses(p);
    LigneCourse ligne(String nom) => l.firstWhere((x) => x.nom == nom);
    expect(ligne('Blanc de poulet').quantiteTexte, '450 g');
    expect(ligne('Riz').quantiteTexte, '420 g');
    expect(ligne('Avocat').quantite, 1.5);
    expect(ligne('Avocat').quantiteTexte, '2');
    expect(ligne('Œufs').quantiteTexte, '2');
    final rayons = l.map((x) => x.rayon.index).toList();
    expect([...rayons]..sort(), rayons);
  });

  test('quantités : arrondi à 5 près, kilos', () {
    LigneCourse g(double q) => LigneCourse(
      cle: 'a',
      nom: 'a',
      quantite: q,
      unite: Unite.g,
      rayon: Rayon.epicerie,
    );
    expect(g(1200).quantiteTexte, '1,2 kg');
    expect(g(2).quantiteTexte, '5 g');
    expect(g(101).quantiteTexte, '105 g');
  });

  test('sérialisation et cochage', () {
    final p = genererPlanning(lundi: lundi, kcalCible: 2000, vegetarien: true)
        .avecCoche('Riz|g', true)
        .avecRepas(
          0,
          Moment.dejeuner,
          const RepasPlanifie('chili_sin_carne', 1.25),
        );
    final relu = Planning.fromMap(lundi, p.toMap());
    expect(relu.vegetarien, isTrue);
    expect(relu.coches, {'Riz|g'});
    expect(relu.jours[0]![Moment.dejeuner]!.recetteId, 'chili_sin_carne');
    expect(relu.jours[0]![Moment.dejeuner]!.portions, 1.25);
    expect(relu.avecCoche('Riz|g', false).coches, isEmpty);
  });

  test('lecture tolérante : recette disparue ignorée', () {
    final p = Planning.fromMap(lundi, {
      'repas': {
        '0': {
          'dejeuner': {'id': 'inconnue', 'p': 1},
          'diner': {'id': 'soupe_lentilles', 'p': 1},
        },
      },
    });
    expect(p.jours[0]!.keys, [Moment.diner]);
  });

  test('dépôt : absent puis enregistré', () async {
    final depot = FirestorePlanningRepository(FakeFirebaseFirestore());
    expect(await depot.planning('u1', lundi).first, isNull);
    await depot.enregistrer(
      'u1',
      genererPlanning(lundi: lundi, kcalCible: 2000),
    );
    final lu = await depot.planning('u1', lundi).first;
    expect(lu!.jours.length, 7);
    expect(await depot.planning('u1', DateTime(2026, 10, 12)).first, isNull);
  });
}
