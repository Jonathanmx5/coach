import 'dart:async';

import 'package:coach/app.dart';
import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/journal/calculs.dart';
import 'package:coach/journal/catalogue.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/journal/photo_repas_page.dart';
import 'package:coach/journal/preferences_analyse.dart';
import 'package:coach/journal/repas_recents.dart';
import 'package:coach/journal/verdict.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import '../parcours.dart';

const riz = AlimentEstime(
  nom: 'Riz',
  grammes: 100,
  macros: Macros(kcal: 130, proteines: 3, glucides: 28, lipides: 0),
  confiance: 0.9,
);
const poulet = AlimentEstime(
  nom: 'Poulet',
  grammes: 100,
  macros: Macros(kcal: 165, proteines: 31, glucides: 0, lipides: 4),
  confiance: 0.8,
);
const cibles = CiblesJour(
  kcal: 2080,
  proteines: 128,
  glucides: 250,
  lipides: 58,
);

/// Photos dont l'écriture attend le feu vert du test (téléphone lent).
class PhotosLentes extends FausPhotosRepas {
  final feu = Completer<void>();
  var ecritures = 0;

  @override
  Future<String> enregistrer(Uint8List octets) async {
    ecritures++;
    await feu.future;
    return super.enregistrer(octets);
  }
}

/// Une analyse qui lève une erreur ordinaire (pas une [AnalyseEchouee]).
class AnalyseCassee extends FausseAnalyse {
  @override
  Future<ResultatAnalyse> analyser(Uint8List jpeg, {String? indice}) async {
    appels++;
    throw StateError('jeton illisible');
  }
}

/// Un catalogue qui renvoie une donnée d'un type inattendu.
class CatalogueBizarre implements CatalogueProduits {
  @override
  Future<ProduitOff?> chercher(String codeBarres) async => throw TypeError();
}

class Banc {
  FausseAnalyse analyse = FausseAnalyse(aliments: [riz, poulet]);
  FausPhotosRepas photos = FausPhotosRepas();
  CatalogueProduits catalogue = FauxCatalogue();
  PrisePhoto prise = (_) async => Uint8List.fromList([1, 2, 3]);
  final resultats = <Object?>[];

  /// Réponse de l'utilisateur à la demande d'accord pour l'IA, et nombre de
  /// fois où elle a été posée.
  bool accord = true;
  int demandesAccord = 0;

  /// Repas des derniers jours proposés ; null : pas de liste.
  List<Repas>? recents;
  Macros dejaMange = Macros.zero;
  PreferencesAnalyse preferences = PreferencesAnalyseMemoire();

  Future<void> monter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CoachApp(
        accueil: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => resultats.add(
                  await Navigator.of(context).push<Object>(
                    MaterialPageRoute(
                      builder: (_) => PhotoRepasPage(
                        date: DateTime(2026, 10, 9, 12),
                        analyse: analyse,
                        prise: prise,
                        photos: photos,
                        catalogue: catalogue,
                        scan: (_) async => '3017620422003',
                        cibles: cibles,
                        dejaMange: dejaMange,
                        accordPhoto: (_) async {
                          demandesAccord++;
                          return accord;
                        },
                        recents: recents == null ? null : Future.value(recents),
                        preferences: preferences,
                      ),
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

  Future<void> analyser(WidgetTester tester) async {
    await taper(tester, 'Prendre une photo');
    await taper(tester, 'Analyser ce repas');
  }
}

/// Appuie sur [texte] sans attendre la fin des animations (un indicateur
/// d'attente tourne pendant l'enregistrement).
Future<void> appuyer(WidgetTester tester, String texte) async {
  await tester.ensureVisible(find.text(texte).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(texte).last);
  await tester.pump();
}

void main() {
  group('pas des boutons + et − de portion', () {
    test('au moins 5 g, même pour une petite portion', () {
      expect(portionSuivante(10, 1), 15);
      expect(portionSuivante(20, -1), 15);
      expect(portionSuivante(5, -1), 5);
      expect(portionSuivante(25, -1), 20);
      expect(portionSuivante(15, 1), 20);
    });

    test('environ 10 % pour une grosse portion, arrondi à 5 g', () {
      expect(portionSuivante(100, 1), 110);
      expect(portionSuivante(110, -1), 100);
      expect(portionSuivante(200, 1), 220);
    });
  });

  test('nom du repas coupé à 200 caractères', () {
    final long = [
      for (var i = 0; i < 8; i++)
        AlimentEstime(
          nom: 'Sauce crémeuse aux champignons et à l\'échalote n°$i',
          grammes: 50,
          macros: Macros.zero,
        ),
    ];
    final nom = nomDuRepas(long);
    expect(nom.length, 200);
    expect(nom.endsWith('…'), isTrue);
    expect(nomDuRepas([riz, poulet]), 'Riz, Poulet');
  });

  group('analyse plus juste', () {
    testWidgets('la taille de l\'assiette part avec la photo', (tester) async {
      final banc = Banc()
        ..preferences = PreferencesAnalyseMemoire(assietteCm: 26);
      await banc.monter(tester);
      await banc.analyser(tester);

      expect(banc.analyse.indices.single, 'Assiette de 26 cm de diamètre.');
    });

    testWidgets('sans assiette réglée, rien de plus n\'est envoyé', (
      tester,
    ) async {
      final banc = Banc();
      await banc.monter(tester);
      await banc.analyser(tester);

      expect(banc.analyse.indices.single, '');
    });

    testWidgets('huile et sauce peu visibles : ajoutées au repas', (
      tester,
    ) async {
      final banc = Banc();
      await banc.monter(tester);
      await banc.analyser(tester);
      expect(find.text('295 kcal'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Beaucoup').first);
      await tester.pump();
      expect(find.text('430 kcal'), findsOneWidget); // + 15 g d'huile

      await tester.tap(find.widgetWithText(ChoiceChip, 'Un peu').last);
      await tester.pump();
      expect(find.text('505 kcal'), findsOneWidget); // + un peu de sauce

      await taper(tester, 'Enregistrer');
      final repas = banc.resultats.single! as Repas;
      expect(repas.macros.kcal, 505);
      expect(repas.aliments.map((a) => a.nom), [
        'Riz',
        'Poulet',
        'Huile de cuisson',
        'Sauce',
      ]);
    });

    testWidgets('portion apprise : appliquée, signalée, puis réapprise', (
      tester,
    ) async {
      final prefs = PreferencesAnalyseMemoire();
      // Deux repas où le riz gardé faisait 1,5 fois l'estimation.
      await prefs.apprendre('Riz', estime: 100, retenu: 150);
      await prefs.apprendre('Riz', estime: 100, retenu: 150);
      final banc = Banc()..preferences = prefs;
      await banc.monter(tester);
      await banc.analyser(tester);

      expect(find.text('150 g · 195 kcal'), findsOneWidget);
      expect(
        find.text("Portion ajustée d'après tes corrections (+50 %)"),
        findsOneWidget,
      );
      expect(find.text('100 g · 165 kcal'), findsOneWidget); // poulet intact

      // L'utilisateur garde 110 g de poulet : c'est appris.
      await tester.tap(find.byTooltip('Augmenter : Poulet'));
      await tester.pump();
      await taper(tester, 'Enregistrer');
      await tester.pumpAndSettle();

      expect(prefs.appris['poulet']!.facteur, closeTo(1.1, 1e-9));
      expect(prefs.appris['riz']!.nombre, 3);
      expect(prefs.appris['riz']!.facteur, closeTo(1.5, 1e-9));
    });

    testWidgets('code-barres : rien n\'est appris', (tester) async {
      final prefs = PreferencesAnalyseMemoire();
      final banc = Banc()
        ..preferences = prefs
        ..catalogue = FauxCatalogue(
          produit: const ProduitOff(
            nom: 'Muesli',
            pour100g: Macros(
              kcal: 400,
              proteines: 10,
              glucides: 60,
              lipides: 12,
            ),
          ),
        );
      await banc.monter(tester);
      await taper(tester, 'Scanner un produit');
      await saisir(tester, 'Quantité mangée (g)', '50');
      await taper(tester, 'Ajouter');
      expect(find.text('Gras peu visible'), findsNothing);
      await taper(tester, 'Enregistrer');

      expect(prefs.appris, isEmpty);
    });
  });

  testWidgets('petite portion : + et − la font bouger de 5 g', (tester) async {
    final banc = Banc()
      ..analyse.aliments = [
        const AlimentEstime(
          nom: 'Huile',
          grammes: 10,
          macros: Macros(kcal: 90, lipides: 10),
        ),
      ];
    await banc.monter(tester);
    await banc.analyser(tester);

    await tester.tap(find.byTooltip('Augmenter : Huile'));
    await tester.pump();
    expect(find.text('15 g · 135 kcal'), findsOneWidget);
    await tester.tap(find.byTooltip('Diminuer : Huile'));
    await tester.tap(find.byTooltip('Diminuer : Huile'));
    await tester.pump();
    expect(find.text('5 g · 45 kcal'), findsOneWidget);
  });

  testWidgets('chaque ligne nomme son aliment (lecteur d\'écran)', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    await banc.analyser(tester);

    final cases = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect([for (final c in cases) c.semanticLabel], ['Riz', 'Poulet']);
    expect(find.byTooltip('Diminuer : Poulet'), findsOneWidget);
    expect(find.byTooltip('Augmenter : Riz'), findsOneWidget);
  });

  testWidgets('boutons des tuiles : zone tactile de 48 dp', (tester) async {
    final banc = Banc();
    await banc.monter(tester);
    await banc.analyser(tester);

    for (final nom in ['Calories', 'Protéines', 'Glucides', 'Lipides']) {
      final taille = tester.getSize(
        find.ancestor(
          of: find.byTooltip('Augmenter : $nom'),
          matching: find.byType(IconButton),
        ),
      );
      expect(taille.width, greaterThanOrEqualTo(48));
      expect(taille.height, greaterThanOrEqualTo(48));
    }
    // La valeur tient sur une ligne.
    expect(find.text('295 kcal'), findsOneWidget);
  });

  testWidgets('décocher après une correction : total cohérent enregistré', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    await banc.analyser(tester);

    // Le poulet a 4 g de lipides : on en retire 4.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Diminuer : Lipides'));
      await tester.pump();
    }
    expect(find.text('259 kcal'), findsOneWidget);

    // Sans le poulet, il ne reste aucun lipide à retirer : le riz garde ses
    // 130 kcal au lieu de tomber à 94.
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    expect(find.text('130 kcal'), findsOneWidget);
    await taper(tester, 'Enregistrer');
    final r = banc.resultats.single! as Repas;
    expect(r.macros.kcal, 130);
    expect(r.macros.lipides, 0);
  });

  testWidgets(
    'réanalyser : correction oubliée, aliment ajouté à la main gardé',
    (tester) async {
      final banc = Banc()
        ..analyse.aliments = [
          const AlimentEstime(
            nom: 'Plat brun',
            grammes: 200,
            macros: Macros(kcal: 300, proteines: 10, glucides: 30, lipides: 10),
            confiance: 0.3,
          ),
        ];
      await banc.monter(tester);
      await banc.analyser(tester);

      await taper(tester, 'Ajouter un aliment');
      await tester.enterText(
        find.widgetWithText(TextField, "Nom de l'aliment"),
        "Huile d'olive",
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Quantité (g)'),
        '10',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Calories (kcal)'),
        '90',
      );
      await taper(tester, 'Enregistrer');
      // 300 + 90 = 390, puis −100 kcal à la main.
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byTooltip('Diminuer : Calories'));
        await tester.pump();
      }
      expect(find.text('290 kcal'), findsOneWidget);

      banc.analyse.aliments = [riz];
      await taper(tester, 'Analyser à nouveau');

      // Riz (130) + huile (90), sans le −100 de l'ancien résultat.
      expect(find.text("Huile d'olive"), findsOneWidget);
      expect(find.text('Plat brun'), findsNothing);
      expect(find.text('220 kcal'), findsOneWidget);
      await taper(tester, 'Enregistrer');
      final r = banc.resultats.single! as Repas;
      expect(r.nom, "Riz, Huile d'olive");
      expect(r.macros.kcal, 220);
    },
  );

  testWidgets('double appui sur Enregistrer : un seul repas, une seule photo', (
    tester,
  ) async {
    final photos = PhotosLentes();
    final banc = Banc()..photos = photos;
    await banc.monter(tester);
    await banc.analyser(tester);

    await appuyer(tester, 'Enregistrer');
    final bouton = find.ancestor(
      of: find.byType(CircularProgressIndicator),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(bouton).onPressed, isNull);
    await tester.tap(bouton, warnIfMissed: false);
    await tester.pump();

    photos.feu.complete();
    await tester.pumpAndSettle();
    expect(photos.ecritures, 1);
    expect(photos.photos, hasLength(1));
    expect(banc.resultats, hasLength(1));
    expect(banc.resultats.single, isA<Repas>());
    // La page d'accueil est toujours là.
    expect(find.text('Ouvrir'), findsOneWidget);
  });

  testWidgets('retour pendant l\'écriture : la photo n\'est pas gardée', (
    tester,
  ) async {
    final photos = PhotosLentes();
    final banc = Banc()..photos = photos;
    await banc.monter(tester);
    await banc.analyser(tester);

    await appuyer(tester, 'Enregistrer');
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    photos.feu.complete();
    await tester.pumpAndSettle();

    expect(banc.resultats, [null]);
    expect(photos.photos, isEmpty);
    expect(find.text('Ouvrir'), findsOneWidget);
  });

  testWidgets('erreur imprévue de l\'analyse : on peut réessayer', (
    tester,
  ) async {
    final banc = Banc()..analyse = AnalyseCassee();
    await banc.monter(tester);
    await banc.analyser(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Saisir à la main'), findsOneWidget);
    await taper(tester, 'Réessayer');
    expect(banc.analyse.appels, 2);
  });

  testWidgets('accès à l\'appareil photo refusé : message et galerie', (
    tester,
  ) async {
    final sources = <SourcePhoto>[];
    final banc = Banc()
      ..prise = (source) async {
        sources.add(source);
        if (source == SourcePhoto.appareil) {
          throw PlatformException(code: 'camera_access_denied');
        }
        return Uint8List.fromList([1, 2, 3]);
      };
    await banc.monter(tester);

    await taper(tester, 'Prendre une photo');
    expect(
      find.textContaining('Accès à l\'appareil photo refusé'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(SnackBarAction, 'Galerie'));
    await tester.pumpAndSettle();

    expect(sources, [SourcePhoto.appareil, SourcePhoto.galerie]);
    expect(find.text('Analyser ce repas'), findsOneWidget);
  });

  testWidgets('produit scanné illisible : retour au choix avec un message', (
    tester,
  ) async {
    final banc = Banc()..catalogue = CatalogueBizarre();
    await banc.monter(tester);

    await taper(tester, 'Scanner un produit');

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('illisibles'), findsOneWidget);
    expect(find.text('Prendre une photo'), findsOneWidget);
  });

  testWidgets('aliment corrigé à la main : plus « À vérifier »', (
    tester,
  ) async {
    final banc = Banc()
      ..analyse.aliments = [
        const AlimentEstime(
          nom: 'Riz ?',
          grammes: 150,
          macros: Macros(kcal: 195, proteines: 4, glucides: 42),
          confiance: 0.4,
        ),
      ];
    await banc.monter(tester);
    await banc.analyser(tester);
    expect(find.text('À vérifier'), findsOneWidget);

    await tester.tap(find.text('Riz ?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, "Nom de l'aliment"),
      'Quinoa',
    );
    await taper(tester, 'Enregistrer');

    expect(find.text('Quinoa'), findsOneWidget);
    expect(find.text('À vérifier'), findsNothing);
    await taper(tester, 'Enregistrer');
    final r = banc.resultats.single! as Repas;
    expect(r.aliments.single.aVerifier, isFalse);
    expect(r.aliments.single.confiance, isNull);
  });

  testWidgets('les trois choix sont séparés', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    final appareil = tester.getRect(
      find.ancestor(
        of: find.text('Prendre une photo'),
        matching: find.byType(Card),
      ),
    );
    final galerie = tester.getRect(
      find.ancestor(
        of: find.text('Choisir dans la galerie'),
        matching: find.byType(Card),
      ),
    );
    expect(galerie.top - appareil.bottom, greaterThanOrEqualTo(12));
  });

  group('accord pour l\'IA', () {
    testWidgets('demandé seulement au choix d\'une photo', (tester) async {
      final banc = Banc();
      await banc.monter(tester);
      expect(banc.demandesAccord, 0);

      await taper(tester, 'Scanner un produit');
      expect(banc.demandesAccord, 0);
      await taper(tester, 'Prendre une photo');
      expect(banc.demandesAccord, 1);
      expect(find.text('Analyser ce repas'), findsOneWidget);
    });

    testWidgets('refusé : pas de photo, les autres choix restent', (
      tester,
    ) async {
      var prises = 0;
      final banc = Banc()
        ..accord = false
        ..prise = (_) async {
          prises++;
          return Uint8List.fromList([1, 2, 3]);
        };
      await banc.monter(tester);

      await taper(tester, 'Prendre une photo');

      expect(prises, 0);
      expect(banc.analyse.appels, 0);
      expect(
        find.textContaining('la photo n\'est pas envoyée'),
        findsOneWidget,
      );
      expect(find.text('Scanner un produit'), findsOneWidget);
      expect(find.text('Saisir à la main'), findsOneWidget);
    });

    testWidgets('sans relais : ni photo ni accord, le scanner reste', (
      tester,
    ) async {
      final banc = Banc()..analyse.disponible = false;
      await banc.monter(tester);

      expect(find.textContaining('Sans analyse par IA'), findsOneWidget);
      expect(find.text('Prendre une photo'), findsNothing);
      expect(find.text('Choisir dans la galerie'), findsNothing);
      expect(find.text('Scanner un produit'), findsOneWidget);
      expect(banc.demandesAccord, 0);
    });
  });

  group('analyses photo restantes', () {
    testWidgets('affichées quand le relais les donne', (tester) async {
      final banc = Banc()..analyse.restantes = 3;
      await banc.monter(tester);
      await banc.analyser(tester);

      expect(
        find.text('Encore 3 analyses photo possibles aujourd\'hui.'),
        findsOneWidget,
      );
    });

    testWidgets('une seule restante : message au singulier', (tester) async {
      final banc = Banc()..analyse.restantes = 1;
      await banc.monter(tester);
      await banc.analyser(tester);
      expect(
        find.text('Encore 1 analyse photo possible aujourd\'hui.'),
        findsOneWidget,
      );
    });

    testWidgets('rien quand le relais n\'en dit rien', (tester) async {
      final banc = Banc();
      await banc.monter(tester);
      await banc.analyser(tester);

      expect(find.byKey(const ValueKey('analyses-restantes')), findsNothing);
    });
  });

  group('repas récents', () {
    final hier = Repas(
      id: 'r1',
      date: DateTime(2026, 10, 8, 19, 30),
      moment: Moment.diner,
      nom: 'Riz, Poulet',
      macros: const Macros(kcal: 295, proteines: 34, glucides: 28, lipides: 4),
      source: SourceRepas.photo,
      description: 'Poulet au riz',
      aliments: const [riz, poulet],
      photoId: '1760000000000000',
      verdict: const Verdict(
        feu: Feu.rouge,
        points: ['ancien'],
        conclusion: 'ancien',
      ),
    );

    testWidgets('un appui : même repas, daté du jour affiché, sans photo', (
      tester,
    ) async {
      final banc = Banc()
        ..recents = [hier]
        ..dejaMange = const Macros(kcal: 1000);
      await banc.monter(tester);

      expect(find.text('Repas récents'), findsOneWidget);
      expect(find.text('Dîner du jeu. 8 oct. · 295 kcal'), findsOneWidget);
      await taper(tester, 'Riz, Poulet');

      final r = banc.resultats.single! as Repas;
      expect(r.id, isNull);
      expect(r.photoId, isNull);
      expect(r.date, DateTime(2026, 10, 9, 12));
      expect(r.moment, Moment.diner);
      expect(r.nom, 'Riz, Poulet');
      expect(r.macros.kcal, 295);
      expect(r.aliments, hasLength(2));
      expect(r.description, 'Poulet au riz');
      // Le verdict est celui de la nouvelle journée, pas l'ancien.
      expect(r.verdict!.points, isNot(contains('ancien')));
      expect(r.verdict!.budget, startsWith('Il te reste 785 kcal'));
      expect(banc.demandesAccord, 0);
    });

    testWidgets('aucun repas récent : pas de section', (tester) async {
      final banc = Banc()..recents = const [];
      await banc.monter(tester);

      expect(find.text('Repas récents'), findsNothing);
    });
  });

  test('repas récents : du plus récent, sans doublon ni repas sans nom', () {
    Repas r(String nom, int jour, double kcal) => Repas(
      date: DateTime(2026, 10, jour, 12),
      moment: Moment.dejeuner,
      nom: nom,
      macros: Macros(kcal: kcal),
      source: SourceRepas.manuel,
    );
    final liste = repasRecents([
      r('Salade', 3, 300),
      r('Pâtes', 5, 600),
      r('salade ', 7, 300),
      r('', 8, 100),
      r('Salade', 6, 450),
    ]);
    expect(
      [for (final x in liste) '${x.nom}@${x.date.day}'],
      ['salade @7', 'Salade@6', 'Pâtes@5'],
    );
    expect(
      repasRecents([for (var i = 1; i <= 20; i++) r('Plat $i', i, 100)]),
      hasLength(maxRecents),
    );
  });
}
