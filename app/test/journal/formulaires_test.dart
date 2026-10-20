import 'package:coach/app.dart';
import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/journal/dialogues_aliment.dart';
import 'package:coach/journal/formulaires.dart';
import 'package:coach/journal/modele.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 12, 30);

/// Ouvre [page] par-dessus un écran d'accueil et rend ce qu'elle renvoie.
Future<List<Object?>> ouvrir(WidgetTester tester, Widget page) async {
  final resultats = <Object?>[];
  // Grand écran : tout le formulaire est construit.
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CoachApp(
      accueil: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => resultats.add(
                await Navigator.of(context)
                    .push<Object>(MaterialPageRoute(builder: (_) => page)),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
  return resultats;
}

void main() {
  testWidgets('activité : par défaut, elle commence il y a sa durée', (
    tester,
  ) async {
    final resultats = await ouvrir(
      tester,
      AjoutActivitePage(date: maintenant, poidsKg: 80),
    );

    await saisir(tester, 'Durée (min)', '45');
    expect(find.text('Heure de début'), findsOneWidget);
    expect(find.text('11:45'), findsOneWidget);
    await taper(tester, 'Enregistrer');

    final a = resultats.single! as Activite;
    expect(a.date, DateTime(2026, 10, 9, 11, 45));
    expect(a.minutes, 45);
  });

  testWidgets('activité : l\'heure de début choisie est gardée', (
    tester,
  ) async {
    final resultats = await ouvrir(
      tester,
      AjoutActivitePage(date: maintenant, poidsKg: 80),
    );

    await saisir(tester, 'Durée (min)', '45');
    await taper(tester, 'Heure de début');
    // Saisie au clavier plutôt qu'au cadran.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final champs = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(champs.at(0), '07');
    await tester.enterText(champs.at(1), '00');
    await taper(tester, 'OK');
    expect(find.text('07:00'), findsOneWidget);
    await taper(tester, 'Enregistrer');

    final a = resultats.single! as Activite;
    expect(a.date, DateTime(2026, 10, 9, 7));
  });

  testWidgets('repas saisi à la main : nom limité à 120 caractères', (
    tester,
  ) async {
    final resultats = await ouvrir(tester, AjoutRepasPage(date: maintenant));

    await saisir(tester, 'Nom du repas', 'x' * 450);
    await saisir(tester, 'Calories (kcal)', '400');
    await taper(tester, 'Enregistrer');

    final r = resultats.single! as Repas;
    expect(r.nom.length, longueurNomRepas);
  });

  testWidgets('aliment : nom limité à 60 caractères', (tester) async {
    AlimentEstime? aliment;
    await tester.pumpWidget(
      CoachApp(
        accueil: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => aliment = await showDialog<AlimentEstime>(
                context: context,
                builder: (_) => const DialogueAliment(),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await saisir(tester, "Nom de l'aliment", 'y' * 100);
    await saisir(tester, 'Quantité (g)', '50');
    await saisir(tester, 'Calories (kcal)', '100');
    await taper(tester, 'Enregistrer');

    expect(aliment!.nom.length, 60);
  });
}
