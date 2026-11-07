import 'dart:async';
import 'dart:typed_data';

import 'package:coach/app.dart';
import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/journal/calculs.dart';
import 'package:coach/journal/detail_repas_page.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/modele.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

const cibles = CiblesJour(
  kcal: 2080,
  proteines: 128,
  glucides: 250,
  lipides: 58,
);

final repas = Repas(
  id: 'r1',
  date: DateTime(2026, 10, 9, 12),
  moment: Moment.dejeuner,
  nom: 'Salade, Sauce',
  macros: const Macros(kcal: 160, proteines: 2, glucides: 8, lipides: 13),
  source: SourceRepas.photo,
  photoId: '0',
  aliments: const [
    AlimentEstime(
      nom: 'Salade',
      grammes: 100,
      macros: Macros(kcal: 20, proteines: 2, glucides: 3),
    ),
    AlimentEstime(
      nom: 'Sauce',
      grammes: 5,
      macros: Macros(kcal: 140, glucides: 5, lipides: 13),
    ),
  ],
);

/// Photos qui comptent leurs lectures.
class PhotosComptees extends FausPhotosRepas {
  var lectures = 0;

  @override
  Future<Uint8List?> lire(String id) {
    lectures++;
    return super.lire(id);
  }
}

class Banc {
  final photos = PhotosComptees()..photos['0'] = Uint8List.fromList([1, 2, 3]);
  final modifies = <Repas>[];

  /// Ce que rend l'écriture : par défaut, l'accusé du serveur n'arrive
  /// jamais (hors ligne).
  Future<void> Function(Repas) ecriture = (_) => Completer<void>().future;

  Future<void> monter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CoachApp(
        accueil: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DetailRepasPage(
                      repas: repas,
                      dejaMange: Macros.zero,
                      cibles: cibles,
                      objectif: Objectif.forme,
                      photos: photos,
                      onModifier: (r) {
                        modifies.add(r);
                        return ecriture(r);
                      },
                    ),
                  ),
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
  }
}

void main() {
  testWidgets('− sans effet sur 5 g : rien n\'est « modifié »', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await tester.tap(find.byTooltip('Diminuer : Sauce'));
    await tester.pump();
    expect(find.text('Enregistrer les modifications'), findsNothing);

    // + fait bien bouger une petite portion.
    await tester.tap(find.byTooltip('Augmenter : Sauce'));
    await tester.pump();
    expect(find.text('10 g · 280 kcal'), findsOneWidget);
    expect(find.text('Enregistrer les modifications'), findsOneWidget);
  });

  testWidgets('la photo est lue une fois, pas à chaque appui', (tester) async {
    final banc = Banc();
    await banc.monter(tester);
    expect(find.byType(Image), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Augmenter : Salade'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(banc.photos.lectures, 1);
    expect(tester.widget<Image>(find.byType(Image)).gaplessPlayback, isTrue);
  });

  testWidgets('hors ligne : la page se ferme sans attendre le serveur', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Collation'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer les modifications'));
    // Un second appui pendant la fermeture ne fait rien.
    await tester.tap(
      find.text('Enregistrer les modifications'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(banc.modifies, hasLength(1));
    expect(banc.modifies.single.moment, Moment.collation);
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.text('Composition'), findsNothing);
  });

  testWidgets('écriture refusée : un message le dit', (tester) async {
    final banc = Banc()
      ..ecriture = (_) async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    await banc.monter(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Collation'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.textContaining("n'a pas pu être enregistrée"), findsOneWidget);
  });

  testWidgets('portion changée : nom refait à partir des aliments', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await tester.tap(find.byTooltip('Augmenter : Salade'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();
    expect(banc.modifies.single.nom, 'Salade, Sauce');
    expect(banc.modifies.single.aliments.first.grammes, 110);
  });
}
