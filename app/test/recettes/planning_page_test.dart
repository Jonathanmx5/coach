import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/recettes/catalogue.dart';
import 'package:coach/recettes/planning.dart';
import 'package:coach/recettes/planning_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20); // vendredi
final lundi = DateTime(2026, 10, 5);
const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

class Banc {
  final planning = FauxPlanning();
  final journal = FauxJournal();

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      CoachApp(
        accueil: PlanningPage(
          utilisateur: lea,
          kcalCible: 2000,
          planning: planning,
          journal: journal,
          horloge: () => maintenant,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Planning? get plan => planning.parSemaine['u1/$lundi'];
}

void main() {
  testWidgets('première ouverture : la semaine est créée et enregistrée', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    expect(banc.plan, isNotNull);
    expect(banc.plan!.jours.length, 7);
    expect(find.textContaining('tes 2000 kcal'), findsOneWidget);
    expect(find.textContaining('Lun. 5 oct.'), findsOneWidget);
  });

  testWidgets('végétarien : tout le planning est régénéré sans viande', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(banc.plan!.vegetarien, isTrue);
    for (final j in banc.plan!.jours.values) {
      for (final r in j.values) {
        expect(recetteParId(r.recetteId).vegetarien, isTrue);
      }
    }
  });

  testWidgets('recette : ingrédients, ajout au journal à la date du repas', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    final repas = banc.plan!.jours[0]![Moment.dejeuner]!;
    final recette = recetteParId(repas.recetteId);

    await tester.tap(find.text(recette.nom).first);
    await tester.pumpAndSettle();
    expect(find.text('Ingrédients'), findsOneWidget);
    expect(find.text('Préparation'), findsOneWidget);

    await taper(tester, 'Ajouter au journal');
    expect(find.text('Repas ajouté au journal.'), findsOneWidget);
    final r = banc.journal.repasDe('u1').single;
    expect(r.nom, recette.nom);
    expect(r.date, DateTime(2026, 10, 5, 12));
    expect(r.moment, Moment.dejeuner);
    expect(r.macros.kcal, closeTo(recette.macros.kcal * repas.portions, 0.01));
  });

  testWidgets('changer de recette : le repas est remplacé', (tester) async {
    final banc = Banc();
    await banc.monter(tester);
    final avant = banc.plan!.jours[0]![Moment.dejeuner]!.recetteId;
    final autre = catalogueRecettes.firstWhere(
      (r) => r.moment == Moment.dejeuner && r.id != avant,
    );

    await tester.tap(find.text(recetteParId(avant).nom).first);
    await tester.pumpAndSettle();
    await taper(tester, 'Changer de recette');
    await tester.tap(find.text(autre.nom));
    await tester.pumpAndSettle();

    final apres = banc.plan!.jours[0]![Moment.dejeuner]!;
    expect(apres.recetteId, autre.id);
    expect(macrosDuRepas(apres).kcal, closeTo(2000 * 0.35, 2000 * 0.35 * 0.3));
  });

  testWidgets('courses : par rayon, cochage enregistré', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await tester.tap(find.byTooltip('Liste de courses'));
    await tester.pumpAndSettle();
    expect(find.text('Fruits et légumes'), findsOneWidget);

    final premiere = listeCourses(banc.plan!).first;
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(banc.plan!.coches, {premiere.cle});

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(banc.plan!.coches, isEmpty);
  });
}
