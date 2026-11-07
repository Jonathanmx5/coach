import 'dart:io';

import 'package:coach/app.dart';
import 'package:coach/entrainement/animation_exercice.dart';
import 'package:coach/entrainement/catalogue.dart';
import 'package:coach/entrainement/generateur.dart';
import 'package:coach/entrainement/mobilite.dart';
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

  test('tous les exercices du catalogue sont animés', () {
    final sans = [
      for (final e in catalogueExercices)
        if (!exercicesAnimes.contains(e.id)) e.id,
    ];
    expect(sans, isEmpty);
  });

  test('les étapes d\'effort portent l\'exercice, pas les repos', () {
    final s = genererRenforcement(
      lieu: Lieu.maison,
      materiel: const {},
      profil: profil,
      seancesFaites: 0,
    );
    for (final e in s.etapes) {
      if (e.repos) {
        expect(e.exerciceId, isNull, reason: e.titre);
      } else if (e.titre == 'Échauffement') {
        expect(exercicesAnimes, contains(e.exerciceId));
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

  testWidgets('exercice inconnu : rien n\'est affiché', (tester) async {
    await tester.pumpWidget(
      const CoachApp(
        accueil: Scaffold(body: AnimationExercice(exerciceId: 'inconnu')),
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
    // Étape 1 : l'échauffement, avec ses photos.
    expect(find.byType(AnimationExercice), findsOneWidget);

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    expect(find.byType(AnimationExercice), findsOneWidget);
    final premier = tester
        .widget<AnimationExercice>(find.byType(AnimationExercice))
        .exerciceId;
    expect(premier, seance.exercices.first.exercice.id);

    // Puis le repos : l'aperçu de l'exercice qui suit, avec son nom.
    final etape = seance.etapes[1];
    await tester.tap(
      find.text(etape.secondes > 0 && etape.reps == 0 ? 'Passer' : 'Fait'),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(seance.etapes[2].repos, isTrue);
    final suite = seance.etapes[3];
    expect(find.text('À suivre : ${suite.titre}'), findsOneWidget);
    expect(
      tester
          .widget<AnimationExercice>(find.byType(AnimationExercice))
          .exerciceId,
      suite.exerciceId,
    );
  });

  test('les étirements des routines ont leurs photos, sauf la respiration', () {
    for (final r in Routine.values) {
      for (final e in routine(r).etapes) {
        if (e.titre == 'Respiration ventrale') {
          expect(e.exerciceId, isNull);
        } else {
          expect(exercicesAnimes, contains(e.exerciceId), reason: e.titre);
        }
      }
    }
  });

  test('chaque vidéo existe et a des photos de repli', () {
    for (final id in exercicesVideo) {
      expect(File('assets/videos/$id.mp4').existsSync(), isTrue, reason: id);
      expect(exercicesAnimes, contains(id));
    }
    final fichiers = Directory('assets/videos')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.mp4', ''))
        .toSet();
    expect(fichiers, exercicesVideo);
  });
}
