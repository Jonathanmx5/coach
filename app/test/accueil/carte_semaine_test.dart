import 'package:coach/accueil/carte_semaine.dart';
import 'package:coach/app.dart';
import 'package:coach/poids/pesees_repository.dart';
import 'package:coach/sante/suivi.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'semaine_commun.dart';

class Banc {
  final journal = FauxJournal();
  final pesees = FauxPesees();
  late final suivi = Suivi(sante: FauxSante(), horloge: () => maintenant);
  var ouvertures = 0;

  Future<void> monter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CoachApp(
        accueil: Scaffold(
          body: SingleChildScrollView(
            child: CarteSemaine(
              uid: 'u1',
              profil: profil,
              suivi: suivi,
              journal: journal,
              pesees: pesees,
              horloge: () => maintenant,
              onJournal: () => ouvertures++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Le texte entier d'un chiffre de la carte (chiffre et objectif).
Finder exact(String texte) => find.textContaining(
  RegExp('^${RegExp.escape(texte)}\$'),
  findRichText: true,
);

void main() {
  testWidgets('la semaine du journal, des séances et du poids', (tester) async {
    final banc = Banc();
    banc.journal.repasParUid['u1'] = [
      repas(19, cible.toDouble(), proteines: 120),
      repas(17, cible * 0.5, proteines: 60),
    ];
    banc.journal.activitesParUid['u1'] = [activite(16), activite(20)];
    await banc.pesees.ajouter('u1', kg: 81, date: DateTime(2026, 10, 10, 7));
    await banc.pesees.ajouter('u1', kg: 80.4, date: DateTime(2026, 10, 18, 7));
    // Trop ancienne : hors de la fenêtre lue par la carte.
    await banc.pesees.ajouter('u1', kg: 95, date: DateTime(2026, 9, 1, 7));
    await banc.monter(tester);

    expect(find.text('Ma semaine'), findsOneWidget);
    expect(find.text('7 derniers jours'), findsOneWidget);
    // Moyenne des deux jours notés, aujourd'hui exclu.
    expect(
      find.textContaining(
        RegExp('^${(cible * 0.75).round()} / '),
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(exact('1 / 2'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^90 / '), findRichText: true),
      findsOne,
    );
    expect(exact('2 / 3'), findsOneWidget);
    expect(find.textContaining('−0,6 kg', findRichText: true), findsOne);
    expect(find.text("poids moyen, comparé à la semaine d'avant"), findsOne);

    // Seulement deux semaines de pesées, et les repas des 7 jours d'avant.
    expect(banc.pesees.depuisDemandes, [DateTime(2026, 10, 7)]);
    expect(banc.journal.debutsRepas, [DateTime(2026, 10, 13)]);

    await tester.tap(find.text('Ma semaine'));
    expect(banc.ouvertures, 1);
  });

  testWidgets('semaine vide : invitation à noter ses repas', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    expect(
      find.textContaining('Aucun repas noté', findRichText: true),
      findsOne,
    );
    expect(find.text('aucune pesée cette semaine'), findsOneWidget);
    expect(exact('0 / 3'), findsOneWidget);
    expect(exact('0 / 0'), findsOneWidget);
  });

  testWidgets('un nouveau repas noté met la carte à jour', (tester) async {
    final banc = Banc();
    await banc.monter(tester);
    expect(
      find.textContaining('Aucun repas noté', findRichText: true),
      findsOne,
    );

    await banc.journal.ajouterRepas('u1', repas(18, 1800, proteines: 100));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(RegExp(r'^1800 / '), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Aucun repas noté', findRichText: true),
      findsNothing,
    );
  });

  test('pesées Firestore : seulement depuis la date demandée', () async {
    final depot = FirestorePeseesRepository(FakeFirebaseFirestore());
    await depot.ajouter('u1', kg: 82, date: DateTime(2026, 9, 1));
    await depot.ajouter('u1', kg: 80, date: DateTime(2026, 10, 15));
    await depot.ajouter('u1', kg: 81, date: DateTime(2026, 10, 7));

    final recentes = await depot
        .observer('u1', depuis: DateTime(2026, 10, 7))
        .first;
    expect(recentes.map((p) => p.kg), [81, 80]);
    expect(await depot.observer('u1').first, hasLength(3));
  });
}
