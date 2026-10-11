import 'package:coach/compte/donnees_compte.dart';
import 'package:coach/journal/analyse_photo.dart';

import 'dart:typed_data';

import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/journal/journal_page.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/sante/modele.dart';
import 'package:coach/sante/sante_service.dart';
import 'package:coach/sante/suivi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);
const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

// Perte simple : base 1780, cible 2080, 128 g de protéines, 80 kg.
const profil = Profil(
  objectif: Objectif.perte,
  sexe: Sexe.homme,
  anneeNaissance: 1996,
  tailleCm: 180,
  poidsKg: 80,
  typeDeVie: TypeDeVie.peuActif,
  typesEntrainement: {TypeEntrainement.salle},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 45,
  problemeSante: false,
);

class Banc {
  Banc({Suivi? suivi})
    : suivi =
          suivi ??
          Suivi(
            sante: FauxSante(dispo: DispoSante.indisponible),
            horloge: () => maintenant,
          );

  final journal = FauxJournal();
  final Suivi suivi;
  final analyse = FausseAnalyse();
  final consentements = FauxConsentements({Consentement.photo});
  final planning = FauxPlanning();
  Uint8List? photo = Uint8List.fromList([1, 2, 3]);
  final sources = <SourcePhoto>[];
  final photosRepas = FausPhotosRepas();

  Future<void> monter(WidgetTester tester) async {
    // Grand écran : le résultat de la photo est long, tout doit être construit.
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CoachApp(
        accueil: JournalPage(
          utilisateur: lea,
          enregistre: ProfilEnregistre(
            profil: profil,
            reperes: calculerReperes(profil, maintenant: maintenant),
          ),
          journal: journal,
          suivi: suivi,
          horloge: () => maintenant,
          analyse: analyse,
          planning: planning,
          avis: FauxAvis(),
          consentements: consentements,
          photosRepas: photosRepas,
          prise: (source) async {
            sources.add(source);
            return photo;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> repas(double kcal, {double p = 0}) => journal.ajouterRepas(
    'u1',
    Repas(
      date: DateTime(2026, 10, 9, 12),
      moment: Moment.dejeuner,
      nom: 'Déj',
      macros: Macros(kcal: kcal, proteines: p),
      source: SourceRepas.manuel,
    ),
  );

  Future<void> activite(double kcal) => journal.ajouterActivite(
    'u1',
    Activite(
      date: DateTime(2026, 10, 9, 18),
      type: TypeActivite.velo,
      minutes: 60,
      intensite: Intensite.moderee,
      kcal: kcal,
    ),
  );
}

String texteDe(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(ValueKey(cle))).data!;

/// Le bouton de l'onglet Repas ouvre directement « Photo du repas ».
Future<void> ouvrirPhoto(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

/// Le repas se saisit à la main depuis l'écran « Photo du repas ».
Future<void> saisieManuelle(WidgetTester tester) async {
  await ouvrirPhoto(tester);
  await taper(tester, 'Saisir à la main');
}

/// Photo prise, précision facultative, analyse lancée.
Future<void> analyserUnePhoto(WidgetTester tester, {String? precision}) async {
  await ouvrirPhoto(tester);
  await taper(tester, 'Prendre une photo');
  if (precision != null) {
    await saisir(tester, 'Une précision ? (facultatif)', precision);
  }
  await taper(tester, 'Analyser ce repas');
}

void main() {
  testWidgets('bilan : mangé, dépensé et solde', (tester) async {
    final banc = Banc();
    await banc.repas(600, p: 30);
    await banc.activite(600);
    await banc.monter(tester);

    expect(texteDe(tester, 'valeur-mange'), '600 kcal');
    expect(texteDe(tester, 'valeur-depense'), '2736 kcal');
    expect(texteDe(tester, 'valeur-solde'), '−2136 kcal');
    expect(find.text('Déficit'), findsOneWidget);
  });

  testWidgets("jour d'effort : objectif relevé et jour intense", (
    tester,
  ) async {
    final banc = Banc();
    await banc.activite(1000);
    await banc.monter(tester);

    expect(find.text('Jour intense'), findsOneWidget);
    expect(find.text("Objectif du jour : 2780 kcal"), findsOneWidget);
  });

  testWidgets('jour de repos : objectif du profil', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    expect(find.text('Jour de repos'), findsOneWidget);
    expect(find.text('Objectif du jour : 2080 kcal'), findsOneWidget);
  });

  testWidgets('avec la montre : calories totales de la montre', (tester) async {
    final suivi = Suivi(
      sante: FauxSante(
        points: [
          PointSante(
            type: TypeMesure.kcalTotales,
            debut: DateTime(2026, 10, 9, 8),
            fin: DateTime(2026, 10, 9, 19),
            valeur: 2500,
          ),
        ],
      ),
      horloge: () => maintenant,
    );
    await tester.runAsync(() => suivi.charger(montre: true));
    final banc = Banc(suivi: suivi);
    await banc.monter(tester);

    expect(texteDe(tester, 'valeur-depense'), '2500 kcal');
  });

  testWidgets('ajouter un repas à la main', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await saisieManuelle(tester);
    await saisir(tester, 'Nom du repas', 'Pâtes');
    await saisir(tester, 'Calories (kcal)', '650,5');
    await saisir(tester, 'Protéines (g)', '24');
    await taper(tester, 'Enregistrer');

    final r = banc.journal.repasDe('u1').single;
    expect(r.nom, 'Pâtes');
    expect(r.macros.kcal, 650.5);
    expect(r.macros.proteines, 24);
    expect(r.source, SourceRepas.manuel);
    expect(texteDe(tester, 'valeur-mange'), '651 kcal');
  });

  testWidgets('repas sans calories : refusé', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await saisieManuelle(tester);
    await taper(tester, 'Enregistrer');

    expect(find.text('Entre un nombre valide.'), findsOneWidget);
    expect(banc.journal.repasDe('u1'), isEmpty);
  });

  testWidgets('supprimer un repas', (tester) async {
    final banc = Banc();
    await banc.repas(600);
    await banc.monter(tester);

    await defilerJusqua(tester, find.byTooltip('Supprimer'));
    await tester.tap(find.byTooltip('Supprimer').first);
    await tester.pumpAndSettle();

    expect(banc.journal.repasDe('u1'), isEmpty);
    expect(texteDe(tester, 'valeur-mange'), '0 kcal');
  });

  testWidgets('jour précédent : journal de la veille, suivant désactivé', (
    tester,
  ) async {
    final banc = Banc();
    await banc.repas(600);
    await banc.monter(tester);

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Jour précédent'));
    await tester.pumpAndSettle();

    expect(texteDe(tester, 'valeur-mange'), '0 kcal');
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('repas ajouté un jour passé : daté de ce jour', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await tester.tap(find.byTooltip('Jour précédent'));
    await tester.pumpAndSettle();
    await saisieManuelle(tester);
    await saisir(tester, 'Calories (kcal)', '400');
    await taper(tester, 'Enregistrer');

    expect(banc.journal.repasDe('u1').single.date, DateTime(2026, 10, 8, 12));
  });

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

  testWidgets('sans relais : la saisie à la main s\'ouvre', (tester) async {
    final banc = Banc();
    banc.analyse.disponible = false;
    await banc.monter(tester);

    await ouvrirPhoto(tester);

    expect(find.textContaining('Sans analyse par IA'), findsOneWidget);
    expect(find.text('Calories (kcal)'), findsOneWidget);
    expect(banc.analyse.appels, 0);
  });

  testWidgets('photo : appareil ou galerie, la source est transmise', (
    tester,
  ) async {
    final banc = Banc();
    banc.analyse.aliments = [riz];
    await banc.monter(tester);

    await ouvrirPhoto(tester);
    await taper(tester, 'Choisir dans la galerie');
    expect(banc.sources, [SourcePhoto.galerie]);
    expect(find.text('Analyser ce repas'), findsOneWidget);
    await taper(tester, 'Changer de photo');
    await taper(tester, 'Prendre une photo');
    expect(banc.sources, [SourcePhoto.galerie, SourcePhoto.appareil]);
  });

  testWidgets('un repas photographié se rouvre avec son analyse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final banc = Banc();
    banc.analyse.aliments = [riz, poulet];
    banc.analyse.description = 'Poulet au riz';
    await banc.monter(tester);

    await analyserUnePhoto(tester);
    await taper(tester, 'Enregistrer');
    final enregistre = banc.journal.repasDe('u1').single;
    expect(enregistre.aliments, hasLength(2));
    expect(enregistre.description, 'Poulet au riz');

    await tester.tap(find.text('Riz, Poulet'));
    await tester.pumpAndSettle();
    expect(find.text('Composition'), findsOneWidget);
    expect(find.textContaining('Poulet au riz'), findsWidgets);
    expect(find.text('Le verdict du coach'), findsOneWidget);
    expect(find.text('100 g · 165 kcal'), findsOneWidget);
    expect(enregistre.photoId, isNotNull);
    expect(banc.photosRepas.photos, hasLength(1));
    expect(find.byType(Image), findsOneWidget);

    // Supprimer le repas efface aussi sa photo.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    expect(banc.journal.repasDe('u1'), isEmpty);
    expect(banc.photosRepas.photos, isEmpty);
  });

  testWidgets('un repas saisi à la main : résumé sans analyse', (tester) async {
    final banc = Banc();
    await banc.repas(400, p: 20);
    await banc.monter(tester);

    await tester.tap(find.byIcon(Icons.restaurant).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('analyse détaillée'), findsOneWidget);
    expect(find.text('Composition'), findsNothing);
  });

  testWidgets('photo : annulée au choix, on reste sur le choix', (
    tester,
  ) async {
    final banc = Banc();
    banc.photo = null;
    await banc.monter(tester);

    await ouvrirPhoto(tester);
    await taper(tester, 'Prendre une photo');

    expect(banc.analyse.appels, 0);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);
    expect(banc.journal.repasDe('u1'), isEmpty);
  });

  testWidgets('photo : la précision de l\'utilisateur part avec la photo', (
    tester,
  ) async {
    final banc = Banc();
    banc.analyse.aliments = [riz];
    await banc.monter(tester);

    await analyserUnePhoto(tester, precision: 'sauce à part');

    expect(banc.analyse.indices, ['sauce à part']);
    expect(find.text('Riz'), findsOneWidget);
  });

  testWidgets('photo : sans précision, rien n\'est ajouté', (tester) async {
    final banc = Banc();
    banc.analyse.aliments = [riz];
    await banc.monter(tester);

    await analyserUnePhoto(tester);

    expect(banc.analyse.indices.single, anyOf(isNull, isEmpty));
  });

  testWidgets('photo : on décoche un aliment et on enregistre', (tester) async {
    final banc = Banc();
    banc.analyse.aliments = [riz, poulet];
    await banc.monter(tester);

    await analyserUnePhoto(tester);
    expect(find.textContaining('Estimation par IA'), findsOneWidget);
    expect(find.text('295 kcal'), findsOneWidget);
    expect(find.text('34 g'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    await taper(tester, 'Enregistrer');

    final r = banc.journal.repasDe('u1').single;
    expect(r.nom, 'Riz');
    expect(r.macros.kcal, 130);
    expect(r.source, SourceRepas.photo);
  });

  testWidgets('photo : + et − ajustent la portion de 10 %', (tester) async {
    final banc = Banc();
    banc.analyse.aliments = [riz];
    await banc.monter(tester);
    await analyserUnePhoto(tester);

    await tester.tap(find.byTooltip('Augmenter la portion'));
    await tester.pump();
    expect(find.text('110 g · 143 kcal'), findsOneWidget);

    await tester.tap(find.byTooltip('Diminuer la portion'));
    await tester.tap(find.byTooltip('Diminuer la portion'));
    await tester.pump();
    expect(find.text('90 g · 117 kcal'), findsOneWidget);
    await taper(tester, 'Enregistrer');
    expect(banc.journal.repasDe('u1').single.macros.kcal, closeTo(117, 0.01));
  });

  testWidgets('photo : on corrige le nom et la portion', (tester) async {
    final banc = Banc();
    banc.analyse.aliments = [riz];
    await banc.monter(tester);
    await analyserUnePhoto(tester);

    await tester.tap(find.text('Riz'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, "Nom de l'aliment"),
      'Riz complet',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Quantité (g)'),
      '200',
    );
    await taper(tester, 'Enregistrer');
    expect(find.text('Riz complet'), findsOneWidget);
    expect(find.text('200 g · 260 kcal'), findsOneWidget);

    await taper(tester, 'Enregistrer');
    final r = banc.journal.repasDe('u1').single;
    expect(r.nom, 'Riz complet');
    expect(r.macros.kcal, 260);
  });

  testWidgets('photo : on ajoute un aliment oublié par l\'IA', (tester) async {
    final banc = Banc();
    banc.analyse.aliments = [riz];
    await banc.monter(tester);
    await analyserUnePhoto(tester);

    await taper(tester, 'Ajouter un aliment');
    await tester.enterText(
      find.widgetWithText(TextField, "Nom de l'aliment"),
      'Pain',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Quantité (g)'),
      '50',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Calories (kcal)'),
      '130',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Protéines (g)'),
      '4',
    );
    await taper(tester, 'Enregistrer');

    expect(find.text('50 g · 130 kcal'), findsOneWidget);
    expect(find.text('260 kcal'), findsOneWidget);
    expect(find.text('7 g'), findsOneWidget);
    await taper(tester, 'Enregistrer');
    final r = banc.journal.repasDe('u1').single;
    expect(r.nom, 'Riz, Pain');
    expect(r.macros.kcal, 260);
  });

  testWidgets('photo : un aliment sans nom ou sans calories est refusé', (
    tester,
  ) async {
    final banc = Banc();
    banc.analyse.aliments = [riz];
    await banc.monter(tester);
    await analyserUnePhoto(tester);

    await taper(tester, 'Ajouter un aliment');
    await taper(tester, 'Enregistrer');
    expect(find.text("Donne un nom à l'aliment."), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, "Nom de l'aliment"),
      'Pain',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Quantité (g)'),
      '50',
    );
    await taper(tester, 'Enregistrer');
    expect(
      find.textContaining('Entre une valeur entre 0 et 5000'),
      findsOneWidget,
    );
  });

  testWidgets('photo : un aliment incertain est signalé « À vérifier »', (
    tester,
  ) async {
    final banc = Banc();
    banc.analyse.aliments = [
      riz,
      const AlimentEstime(
        nom: 'Sauce',
        grammes: 30,
        macros: Macros(kcal: 60),
        confiance: 0.3,
      ),
    ];
    await banc.monter(tester);
    await analyserUnePhoto(tester);

    expect(find.text('À vérifier'), findsOneWidget);
  });

  testWidgets('photo : l\'effet du repas sur la journée est montré', (
    tester,
  ) async {
    final banc = Banc();
    banc.analyse.aliments = [riz];
    banc.journal.repasParUid['u1'] = [
      Repas(
        date: maintenant,
        moment: Moment.dejeuner,
        nom: 'x',
        macros: const Macros(kcal: 500, proteines: 20),
        source: SourceRepas.manuel,
      ),
    ];
    await banc.monter(tester);
    await analyserUnePhoto(tester);

    // Objectif du jour : 2080 kcal, 128 g de protéines.
    expect(find.text('Le verdict du coach'), findsOneWidget);
    expect(find.textContaining('Il te resterait 1450 kcal'), findsOneWidget);
  });

  testWidgets('photo : « Saisir à la main » depuis le résultat', (
    tester,
  ) async {
    final banc = Banc();
    banc.analyse.aliments = [riz];
    await banc.monter(tester);
    await analyserUnePhoto(tester);

    await taper(tester, 'Saisir à la main');

    expect(find.text('Calories (kcal)'), findsOneWidget);
    expect(banc.journal.repasDe('u1'), isEmpty);
  });

  testWidgets('photo : échec réseau puis réessai', (tester) async {
    final banc = Banc();
    banc.analyse.echec = CauseAnalyse.reseau;
    banc.analyse.aliments = [riz];
    await banc.monter(tester);

    await analyserUnePhoto(tester);
    expect(
      find.textContaining('Pas de connexion pour analyser'),
      findsOneWidget,
    );

    banc.analyse.echec = null;
    await taper(tester, 'Réessayer');
    expect(find.text('Riz'), findsOneWidget);
    expect(banc.analyse.appels, 2);
  });

  testWidgets('photo : quota atteint, pas de réessai', (tester) async {
    final banc = Banc();
    banc.analyse.echec = CauseAnalyse.quota;
    await banc.monter(tester);

    await analyserUnePhoto(tester);
    expect(find.textContaining('limite de photos'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('photo : illisible, on peut changer de photo', (tester) async {
    final banc = Banc();
    banc.analyse.echec = CauseAnalyse.illisible;
    await banc.monter(tester);

    await analyserUnePhoto(tester);
    await taper(tester, 'Changer de photo');

    expect(find.text('Prendre une photo'), findsOneWidget);
  });

  testWidgets('photo : aucun aliment reconnu', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await analyserUnePhoto(tester);
    expect(find.textContaining("Je ne vois pas d'aliment"), findsOneWidget);
  });

  testWidgets('photo : accord refusé, la saisie à la main s\'ouvre', (
    tester,
  ) async {
    final banc = Banc();
    await banc.consentements.definir('u1', Consentement.photo, false);
    banc.analyse.aliments = [riz];
    await banc.monter(tester);

    await ouvrirPhoto(tester);
    expect(find.text("Envoyer la photo pour l'analyse ?"), findsOneWidget);
    await taper(tester, 'Refuser');

    expect(banc.analyse.appels, 0);
    expect(banc.consentements.accordesMaintenant, isEmpty);
    expect(find.text('Calories (kcal)'), findsOneWidget);
  });

  testWidgets('photo : accord donné, enregistré, puis analyse', (tester) async {
    final banc = Banc();
    await banc.consentements.definir('u1', Consentement.photo, false);
    banc.analyse.aliments = [riz];
    await banc.monter(tester);

    await ouvrirPhoto(tester);
    await taper(tester, 'Accepter');
    await taper(tester, 'Prendre une photo');
    await taper(tester, 'Analyser ce repas');

    expect(banc.consentements.accordesMaintenant, {Consentement.photo});
    expect(banc.analyse.appels, 1);
    expect(find.text('Riz'), findsOneWidget);
  });

  testWidgets('le bouton + ouvre directement la photo, sans menu', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await ouvrirPhoto(tester);

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Scanner un produit'), findsNothing);
    expect(find.text('Ajouter une activité'), findsNothing);
    expect(find.text('Ajouter un repas'), findsNothing);
  });

  testWidgets('un produit protéiné : carton vert, description et apports', (
    tester,
  ) async {
    final banc = Banc();
    banc.analyse.description = 'Gâteau de semoule protéiné Aldi';
    banc.analyse.aliments = [
      const AlimentEstime(
        nom: 'Gâteau de semoule protéiné',
        grammes: 250,
        macros: Macros(kcal: 202, proteines: 20, glucides: 22, lipides: 3.75),
        sucres: 11.5,
        satures: 2.5,
        confiance: 0.9,
      ),
    ];
    await banc.monter(tester);
    await analyserUnePhoto(tester, precision: 'la moitié du pot');

    expect(banc.analyse.indices, ['la moitié du pot']);
    expect(find.text("C'est un carton vert !"), findsOneWidget);
    expect(
      find.text('Il s\'agit de : Gâteau de semoule protéiné Aldi'),
      findsOneWidget,
    );
    expect(find.text('202 kcal'), findsOneWidget);
    expect(find.text('20 g'), findsOneWidget);
    expect(find.text('dont 12 g de sucres'), findsOneWidget);
    expect(find.text('dont 3 g de saturés'), findsOneWidget);
    expect(
      find.textContaining('20 g de protéines pour 202 kcal'),
      findsOneWidget,
    );
    expect(find.textContaining('Validé !'), findsOneWidget);
  });

  testWidgets('beaucoup de sucre : carton rouge', (tester) async {
    final banc = Banc();
    banc.analyse.aliments = [
      const AlimentEstime(
        nom: 'Bonbons',
        grammes: 100,
        macros: Macros(kcal: 350, proteines: 2, glucides: 85, lipides: 0.5),
        sucres: 60,
      ),
    ];
    await banc.monter(tester);
    await analyserUnePhoto(tester);

    expect(find.text("C'est un carton rouge !"), findsOneWidget);
    expect(find.textContaining('60 g de sucres'), findsWidgets);
  });

  testWidgets('le verdict suit les aliments gardés', (tester) async {
    final banc = Banc();
    banc.analyse.aliments = [
      const AlimentEstime(
        nom: 'Skyr',
        grammes: 150,
        macros: Macros(kcal: 100, proteines: 17, glucides: 6, lipides: 0.5),
      ),
      const AlimentEstime(
        nom: 'Bonbons',
        grammes: 100,
        macros: Macros(kcal: 350, proteines: 2, glucides: 85, lipides: 0.5),
        sucres: 60,
      ),
    ];
    await banc.monter(tester);
    await analyserUnePhoto(tester);
    expect(find.text("C'est un carton rouge !"), findsOneWidget);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.text("C'est un carton vert !"), findsOneWidget);
  });

  testWidgets('total de la journée : petit-déjeuner, midi, soir additionnés', (
    tester,
  ) async {
    final banc = Banc();
    Future<void> ajouter(Moment moment, double kcal, double p) =>
        banc.journal.ajouterRepas(
          'u1',
          Repas(
            date: DateTime(2026, 10, 9, 12),
            moment: moment,
            nom: 'x',
            macros: Macros(kcal: kcal, proteines: p),
            source: SourceRepas.photo,
          ),
        );
    await ajouter(Moment.petitDejeuner, 400, 20);
    await ajouter(Moment.dejeuner, 600, 40);
    await ajouter(Moment.diner, 500, 30);
    await ajouter(Moment.diner, 100, 5);
    await banc.monter(tester);

    await defilerJusqua(tester, find.text('Total de la journée'));
    expect(find.text('400 kcal · 20 g de protéines'), findsOneWidget);
    expect(find.text('600 kcal · 40 g de protéines'), findsOneWidget);
    expect(find.text('600 kcal · 35 g de protéines'), findsWidgets);
    expect(find.byKey(const Key('recap-total')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('recap-total'))).data,
      '1600 kcal · 95 g de protéines',
    );
  });

  testWidgets('sans repas, pas de total de la journée', (tester) async {
    final banc = Banc();
    await banc.monter(tester);
    expect(find.text('Total de la journée'), findsNothing);
  });
}
