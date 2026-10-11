import 'dart:io';

import 'package:coach/app.dart';
import 'package:coach/entrainement/animation_exercice.dart';
import 'package:coach/entrainement/catalogue.dart';
import 'package:coach/entrainement/generateur.dart';
import 'package:coach/entrainement/modele.dart';
import 'package:coach/entrainement/seance_guidee_page.dart';
import 'package:coach/profil/modele.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

const profil = Profil(
  objectif: Objectif.forme,
  sexe: Sexe.femme,
  anneeNaissance: 1996,
  tailleCm: 170,
  poidsKg: 60,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: {TypeEntrainement.maison},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 30,
  problemeSante: false,
);

void main() {
  test('chaque animation annoncée a ses deux photos, et rien d\'oublié', () {
    for (final id in exercicesAnimes) {
      for (final i in [0, 1]) {
        expect(
          File('assets/exercices/${id}_$i.jpg').existsSync(),
          isTrue,
          reason: '$id photo $i',
        );
      }
    }
    final fichiers = Directory('assets/exercices')
        .listSync()
        .whereType<File>()
        .map(
          (f) => f.uri.pathSegments.last.replaceAll(RegExp(r'_[01]\.jpg$'), ''),
        )
        .toSet();
    expect(fichiers, exercicesAnimes);
  });

  test(
    'tous les exercices du catalogue sont animés, sauf les jumping jacks',
    () {
      final sans = [
        for (final e in catalogueExercices)
          if (!exercicesAnimes.contains(e.id)) e.id,
      ];
      expect(sans, ['jumping_jacks']);
    },
  );

  test('les étapes d\'effort portent l\'exercice, pas les repos', () {
    final s = genererRenforcement(
      lieu: Lieu.maison,
      materiel: const {},
      profil: profil,
      seancesFaites: 0,
    );
    for (final e in s.etapes) {
      if (e.repos || e.titre == 'Échauffement') {
        expect(e.exerciceId, isNull, reason: e.titre);
      } else {
        expect(e.exerciceId, isNotNull, reason: e.titre);
        expect(
          catalogueExercices.any((x) => x.id == e.exerciceId),
          isTrue,
          reason: e.titre,
        );
      }
    }
  });

  testWidgets('les deux positions alternent en boucle', (tester) async {
    await tester.pumpWidget(
      const CoachApp(
        accueil: Scaffold(body: AnimationExercice(exerciceId: 'pompes')),
      ),
    );
    CrossFadeState etat() => tester
        .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
        .crossFadeState;
    expect(etat(), CrossFadeState.showFirst);
    await tester.pump(const Duration(milliseconds: 1150));
    expect(etat(), CrossFadeState.showSecond);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(etat(), CrossFadeState.showFirst);
  });

  testWidgets('exercice sans photos : rien n\'est affiché', (tester) async {
    await tester.pumpWidget(
      const CoachApp(
        accueil: Scaffold(body: AnimationExercice(exerciceId: 'jumping_jacks')),
      ),
    );
    expect(find.byType(AnimatedCrossFade), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('séance guidée : l\'animation suit l\'exercice en cours', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final seance = genererRenforcement(
      lieu: Lieu.maison,
      materiel: const {},
      profil: profil,
      seancesFaites: 0,
    );
    await tester.pumpWidget(
      CoachApp(
        accueil: SeanceGuideePage(seance: seance, voix: FausseVoix()),
      ),
    );
    await tester.pumpAndSettle();
    // Étape 1 : l'échauffement, sans animation.
    expect(find.byType(AnimationExercice), findsNothing);

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    expect(find.byType(AnimationExercice), findsOneWidget);
    final premier = tester
        .widget<AnimationExercice>(find.byType(AnimationExercice))
        .exerciceId;
    expect(premier, seance.exercices.first.exercice.id);

    // Série suivante (répétitions ou minuteur), puis le repos : plus d'image.
    final etape = seance.etapes[1];
    await tester.tap(
      find.text(etape.secondes > 0 && etape.reps == 0 ? 'Passer' : 'Fait'),
    );
    await tester.pumpAndSettle();
    expect(seance.etapes[2].repos, isTrue);
    expect(find.byType(AnimationExercice), findsNothing);
  });
}
