import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/recettes/avis.dart';
import 'package:coach/recettes/avis_repository.dart';
import 'package:coach/recettes/catalogue.dart';
import 'package:coach/recettes/idees_page.dart';
import 'package:coach/recettes/planning.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);
const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

void main() {
  group('construireDeck', () {
    test('toutes les recettes, sans doublon, reproductible', () {
      final a = construireDeck(avis: {}, objectif: Objectif.forme, graine: 7);
      final b = construireDeck(avis: {}, objectif: Objectif.forme, graine: 7);
      expect(a.length, catalogueRecettes.length);
      expect(a.map((r) => r.id).toSet().length, a.length);
      expect(a.map((r) => r.id), b.map((r) => r.id));
      final autre = construireDeck(
        avis: {},
        objectif: Objectif.forme,
        graine: 8,
      );
      expect(a.map((r) => r.id), isNot(autre.map((r) => r.id)));
    });

    test('moment et végétarien filtrent', () {
      final d = construireDeck(
        avis: {},
        objectif: Objectif.forme,
        graine: 1,
        moment: Moment.diner,
        vegetarien: true,
      );
      expect(d, isNotEmpty);
      expect(d.every((r) => r.moment == Moment.diner && r.vegetarien), isTrue);
    });

    test('les recettes aimées sont gardées de côté', () {
      final d = construireDeck(
        avis: {'chili_sin_carne': Avis.aime},
        objectif: Objectif.forme,
        graine: 1,
      );
      expect(d.map((r) => r.id), isNot(contains('chili_sin_carne')));
      expect(
        recettesAimees({'chili_sin_carne': Avis.aime}).single.id,
        'chili_sin_carne',
      );
    });

    test('les recettes refusées reviennent très rarement (~5 %)', () {
      final avis = {for (final r in catalogueRecettes) r.id: Avis.refuse};
      var revenues = 0;
      const essais = 200;
      for (var g = 0; g < essais; g++) {
        revenues += construireDeck(
          avis: avis,
          objectif: Objectif.forme,
          graine: g,
        ).length;
      }
      final part = revenues / (essais * catalogueRecettes.length);
      expect(part, inInclusiveRange(0.02, 0.09));
    });

    test(
      'muscle : les recettes riches en protéines passent plus souvent devant',
      () {
        double rangMoyen(Objectif o, String id) {
          var somme = 0;
          const essais = 300;
          for (var g = 0; g < essais; g++) {
            final d = construireDeck(avis: {}, objectif: o, graine: g);
            somme += d.indexWhere((r) => r.id == id);
          }
          return somme / essais;
        }

        // Poulet-riz-brocoli : 32 % des calories en protéines.
        expect(
          rangMoyen(Objectif.muscle, 'poulet_riz_brocoli'),
          lessThan(rangMoyen(Objectif.forme, 'poulet_riz_brocoli')),
        );
      },
    );
  });

  test('planning : les refusées sont écartées, les aimées reviennent plus', () {
    final lundi = DateTime(2026, 10, 5);
    final avis = {
      'poulet_riz_brocoli': Avis.refuse,
      'chili_sin_carne': Avis.aime,
    };
    final p = genererPlanning(lundi: lundi, kcalCible: 2000, avis: avis);
    final dej = [
      for (var j = 0; j < 7; j++) p.jours[j]![Moment.dejeuner]!.recetteId,
    ];
    expect(dej, isNot(contains('poulet_riz_brocoli')));
    expect(
      dej.where((i) => i == 'chili_sin_carne').length,
      greaterThanOrEqualTo(2),
    );
    for (var j = 0; j < 6; j++) {
      expect(dej[j], isNot(dej[j + 1]));
    }
  });

  test('planning : sans avis, rien ne change', () {
    final lundi = DateTime(2026, 10, 5);
    final a = genererPlanning(lundi: lundi, kcalCible: 2000);
    final b = genererPlanning(lundi: lundi, kcalCible: 2000, avis: const {});
    expect(a.toMap(), b.toMap());
  });

  test('dépôt : noter, relire, effacer', () async {
    final depot = FirestoreAvisRepository(FakeFirebaseFirestore());
    expect(await depot.avis('u1').first, isEmpty);
    await depot.noter('u1', 'a', Avis.aime);
    await depot.noter('u1', 'b', Avis.refuse);
    expect(await depot.avis('u1').first, {'a': Avis.aime, 'b': Avis.refuse});
    await depot.noter('u1', 'a', null);
    expect(await depot.avis('u1').first, {'b': Avis.refuse});
  });

  group('écran', () {
    Future<FauxAvis> monter(
      WidgetTester tester, {
      Map<String, Avis>? avis,
    }) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final faux = FauxAvis();
      if (avis != null) faux.parUid['u1'] = avis;
      await tester.pumpWidget(
        CoachApp(
          accueil: IdeesPage(
            utilisateur: lea,
            objectif: Objectif.forme,
            kcalCible: 2000,
            avis: faux,
            horloge: () => maintenant,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return faux;
    }

    testWidgets('bouton j\'aime : la carte part et l\'avis est enregistré', (
      tester,
    ) async {
      final faux = await monter(tester);
      expect(find.textContaining('kcal pour toi'), findsWidgets);

      await tester.tap(find.byTooltip('J\'aime, pour une prochaine fois'));
      await tester.pumpAndSettle();

      expect(faux.de('u1').values, [Avis.aime]);
    });

    testWidgets('balayer à gauche = je n\'aime pas', (tester) async {
      final faux = await monter(tester);

      await tester.fling(find.byType(Image).first, const Offset(-600, 0), 1500);
      await tester.pumpAndSettle();

      expect(faux.de('u1').values, [Avis.refuse]);
    });

    testWidgets('balayer à droite = j\'aime', (tester) async {
      final faux = await monter(tester);

      await tester.fling(find.byType(Image).first, const Offset(600, 0), 1500);
      await tester.pumpAndSettle();

      expect(faux.de('u1').values, [Avis.aime]);
    });

    testWidgets('un petit glissement revient à sa place', (tester) async {
      final faux = await monter(tester);

      await tester.drag(find.byType(Image).first, const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(faux.de('u1'), isEmpty);
    });

    testWidgets('toucher la carte ouvre la recette complète', (tester) async {
      await monter(tester);

      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();

      expect(find.text('Ingrédients'), findsOneWidget);
      expect(find.text('Préparation'), findsOneWidget);
      expect(find.text('Ajouter au journal'), findsNothing);
    });

    testWidgets('filtre par repas : seuls des dîners sont proposés', (
      tester,
    ) async {
      final faux = await monter(tester);

      await taper(tester, 'Dîner');
      await tester.tap(find.byTooltip("J'aime, pour une prochaine fois"));
      await tester.pumpAndSettle();

      final id = faux.de('u1').keys.single;
      expect(recetteParId(id).moment, Moment.diner);
    });

    testWidgets('mes envies : liste, ouverture, retrait', (tester) async {
      final faux = await monter(tester, avis: {'chili_sin_carne': Avis.aime});

      await tester.tap(find.byTooltip('Mes envies'));
      await tester.pumpAndSettle();
      expect(find.text('Chili sin carne'), findsOneWidget);

      await tester.tap(find.byTooltip('Retirer de mes envies'));
      await tester.pumpAndSettle();
      expect(faux.de('u1'), isEmpty);
      expect(find.textContaining('Aucune envie'), findsOneWidget);
    });

    testWidgets('plus de carte : message de fin', (tester) async {
      await monter(
        tester,
        avis: {for (final r in catalogueRecettes) r.id: Avis.aime},
      );
      expect(find.textContaining('fait le tour des idées'), findsOneWidget);
    });
  });
}
