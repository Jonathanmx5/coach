import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/poids/photos.dart';
import 'package:flutter/material.dart';
import 'package:coach/poids/mensurations.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/poids/poids_page.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/sante/modele.dart';
import 'package:coach/sante/suivi.dart';
import 'package:coach/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import '../donnees_sante.dart';
import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);
const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

Profil profilDe({
  double kg = 60,
  int taille = 170,
  bool montre = false,
  Objectif objectif = Objectif.forme,
}) => Profil(
  objectif: objectif,
  sexe: Sexe.femme,
  anneeNaissance: 1996,
  tailleCm: taille,
  poidsKg: kg,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: const {TypeEntrainement.marche},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 30,
  montre: montre,
  appMontre: montre ? AppMontre.miFitness : null,
  poidsDate: DateTime(2026, 10, 1),
);

class Banc {
  Banc({Profil? profil, FauxSante? sante}) {
    final p = profil ?? profilDe();
    depot.donnees['u1'] = ProfilEnregistre(
      profil: p,
      reperes: calculerReperes(p, maintenant: maintenant),
    );
    this.sante = sante ?? FauxSante();
  }

  final depot = FauxDepot();
  final pesees = FauxPesees();
  final journal = FauxJournal();
  final mensurations = FauxMensurations();
  final photos = FausPhotos();
  late final FauxSante sante;
  late final suivi = Suivi(sante: sante, horloge: () => maintenant);

  Profil get profil => depot.donnees['u1']!.profil;

  /// Remplace le profil enregistré, comme une modification depuis le profil.
  void changerProfil(Profil p) => depot.donnees['u1'] = ProfilEnregistre(
    profil: p,
    reperes: calculerReperes(p, maintenant: maintenant),
  );

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      CoachApp(
        accueil: PoidsPage(
          utilisateur: lea,
          enregistre: depot.donnees['u1']!,
          depot: depot,
          pesees: pesees,
          journal: journal,
          mensurations: mensurations,
          photos: photos,
          sante: sante,
          suivi: suivi,
          horloge: () => maintenant,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> ajouterEnBase(double kg, DateTime date) =>
      pesees.ajouter('u1', kg: kg, date: date);
}

PointSante peseeMontre(double kg, DateTime date) =>
    PointSante(type: TypeMesure.poids, debut: date, fin: date, valeur: kg);

int pointsDeLaCourbe(WidgetTester tester) => tester
    .widget<LineChart>(find.byType(LineChart))
    .data
    .lineBarsData
    .first
    .spots
    .length;

List<LineChartBarData> courbes(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData;

/// Le tracé en pointillés de la projection, s'il existe.
LineChartBarData? projection(WidgetTester tester) =>
    courbes(tester).where((c) => c.dashArray != null).firstOrNull;

/// [n] repas de [kcal] le [jour] octobre 2026.
List<Repas> repasDu(int jour, {int n = 2, double kcal = 1500}) => [
  for (var i = 0; i < n; i++)
    Repas(
      date: DateTime(2026, 10, jour, 8 + 4 * i),
      moment: i == 0 ? Moment.petitDejeuner : Moment.dejeuner,
      nom: 'x',
      macros: Macros(kcal: kcal),
      source: SourceRepas.manuel,
    ),
];

void main() {
  testWidgets('poids actuel, IMC et catégorie', (tester) async {
    final banc = Banc();
    await banc.ajouterEnBase(60, DateTime(2026, 10, 5));
    await banc.monter(tester);

    expect(find.text('60,0 kg'), findsOneWidget);
    expect(find.text('20,8'), findsOneWidget);
    expect(find.text('Poids normal'), findsOneWidget);
  });

  testWidgets('catégorie obésité à 100 kg pour 170 cm', (tester) async {
    final banc = Banc(profil: profilDe(kg: 100));
    await banc.ajouterEnBase(100, DateTime(2026, 10, 5));
    await banc.monter(tester);

    expect(find.text('34,6'), findsOneWidget);
    expect(find.text('Obésité'), findsOneWidget);
  });

  testWidgets('écart depuis la première pesée', (tester) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 9, 1));
    await banc.ajouterEnBase(59.7, DateTime(2026, 10, 5));
    await banc.monter(tester);

    expect(find.textContaining('−2,3 kg'), findsOneWidget);
  });

  testWidgets('aucune pesée : invitation et IMC du profil', (tester) async {
    final banc = Banc();
    await banc.monter(tester);
    expect(find.text('Poids normal'), findsOneWidget);

    await defilerJusqua(tester, find.textContaining('Aucune pesée pour l'));
    expect(find.textContaining('Aucune pesée pour l'), findsOneWidget);
  });

  testWidgets('ajouter une pesée avec une virgule : profil mis à jour', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Ajouter une pesée');
    await saisir(tester, 'Poids (kg)', '61,5');
    await taper(tester, 'Enregistrer');

    expect(banc.pesees.de('u1').single.kg, 61.5);
    expect(banc.profil.poidsKg, 61.5);
    expect(banc.profil.poidsDate, maintenant);
    expect(find.text('61,5 kg'), findsWidgets);
  });

  testWidgets('saisie invalide : message et rien d\'enregistré', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Ajouter une pesée');
    await saisir(tester, 'Poids (kg)', '10');
    await taper(tester, 'Enregistrer');

    expect(
      find.textContaining('Entre une valeur entre 30 et 300'),
      findsOneWidget,
    );
    expect(banc.pesees.de('u1'), isEmpty);
  });

  testWidgets('pesée qui passe sous 18,5 : objectif perte remplacé', (
    tester,
  ) async {
    final banc = Banc(profil: profilDe(objectif: Objectif.perte));
    await banc.monter(tester);

    await taper(tester, 'Ajouter une pesée');
    await saisir(tester, 'Poids (kg)', '52');
    await taper(tester, 'Enregistrer');

    expect(banc.profil.objectif, Objectif.forme);
  });

  testWidgets('supprimer la dernière saisie : profil ramené à la précédente', (
    tester,
  ) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 2));
    await banc.ajouterEnBase(59, DateTime(2026, 10, 8));
    await banc.monter(tester);

    // Les pesées les plus récentes sont en haut de l'historique.
    await defilerJusqua(tester, find.text('8 oct. 2026'));
    await tester.tap(find.byTooltip('Supprimer').first);
    await tester.pumpAndSettle();

    expect(banc.pesees.de('u1').single.kg, 62);
    expect(banc.profil.poidsKg, 62);
  });

  testWidgets('pesées de la montre : affichées, non supprimables', (
    tester,
  ) async {
    final banc = Banc(
      profil: profilDe(montre: true),
      sante: FauxSante(points: [peseeMontre(61.2, DateTime(2026, 10, 6, 7))]),
    );
    await banc.monter(tester);

    expect(find.text('61,2 kg'), findsWidgets);
    await defilerJusqua(tester, find.text('Montre'));
    expect(find.text('Montre'), findsOneWidget);
    expect(find.byTooltip('Supprimer'), findsNothing);
  });

  testWidgets('périodes 30 jours, 90 jours et 1 an', (tester) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 1));
    await banc.ajouterEnBase(61, DateTime(2026, 8, 1));
    await banc.ajouterEnBase(60, DateTime(2026, 3, 1));
    await banc.monter(tester);

    await taper(tester, '30 jours');
    expect(pointsDeLaCourbe(tester), 1);
    await taper(tester, '90 jours');
    expect(pointsDeLaCourbe(tester), 2);
    await taper(tester, '1 an');
    expect(pointsDeLaCourbe(tester), 3);
  });

  testWidgets('projection en pointillés selon le journal, sinon rien', (
    tester,
  ) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 5));
    await banc.monter(tester);
    expect(find.textContaining('projection sur 5 jours'), findsNothing);
    // Pesées brutes et tendance, sans projection.
    expect(courbes(tester), hasLength(2));
    expect(projection(tester), isNull);

    // Le journal se remplit pendant que l'onglet est ouvert.
    for (final jour in [4, 5, 6, 8]) {
      for (final r in repasDu(jour)) {
        await banc.journal.ajouterRepas('u1', r);
      }
    }
    await tester.pumpAndSettle();
    expect(courbes(tester), hasLength(3));
    expect(projection(tester)!.spots, hasLength(6));
    expect(projection(tester)!.spots.last.y, greaterThan(62));
    expect(find.textContaining('projection sur 5 jours'), findsOneWidget);
  });

  testWidgets('dernière pesée de plus de 7 jours : pas de projection', (
    tester,
  ) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 1));
    banc.journal.repasParUid['u1'] = [
      for (final jour in [4, 5, 6, 8]) ...repasDu(jour),
    ];
    await banc.monter(tester);

    expect(projection(tester), isNull);
    expect(find.textContaining('projection sur 5 jours'), findsNothing);
  });

  testWidgets('journées notées en partie : pas de projection', (tester) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 5));
    banc.journal.repasParUid['u1'] = [
      // Seul le petit-déjeuner noté : ce n'est pas un jeûne.
      for (final jour in [3, 7, 8]) ...repasDu(jour, n: 1, kcal: 400),
      // Trois journées complètes seulement : moins de 4.
      for (final jour in [4, 5, 6]) ...repasDu(jour),
    ];
    await banc.monter(tester);

    expect(projection(tester), isNull);
  });

  testWidgets('tendance sur 7 jours en trait épais, pesées en trait discret', (
    tester,
  ) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 2));
    await banc.ajouterEnBase(63, DateTime(2026, 10, 3));
    await banc.ajouterEnBase(61, DateTime(2026, 10, 4));
    await banc.monter(tester);

    final [brute, tendance] = courbes(tester);
    expect(brute.spots.map((s) => s.y), [62, 63, 61]);
    expect(tendance.spots.map((s) => s.y), [62, 62.5, 62]);
    expect(tendance.barWidth, greaterThan(brute.barWidth));
    expect(find.textContaining('moyenne sur 7 jours'), findsOneWidget);
  });

  testWidgets("la courbe est décrite aux lecteurs d'écran", (tester) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 2));
    await banc.ajouterEnBase(61, DateTime(2026, 10, 6));
    banc.journal.repasParUid['u1'] = [
      for (final jour in [4, 5, 6, 8]) ...repasDu(jour),
    ];
    await banc.monter(tester);

    // Le graphique entier est remplacé par une phrase (excludeSemantics).
    final description = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.excludeSemantics)
        .map((s) => s.properties.label)
        .whereType<String>()
        .toList();
    expect(
      description,
      anyElement(
        matches(
          r'^Évolution du poids : 62,0 kg le 2 oct\. 2026, 61,0 kg le 6 oct\. '
          r'2026\. Moyenne sur 7 jours : 61,5 kg\. Projection dans 5 jours : '
          r'\d+,\d kg\.$',
        ),
      ),
    );
  });

  testWidgets('activer la montre lit ses pesées ; la couper les retire', (
    tester,
  ) async {
    final banc = Banc(
      sante: FauxSante(points: [peseeMontre(61.2, DateTime(2026, 10, 6, 7))]),
    );
    await banc.monter(tester);
    expect(find.text('61,2 kg'), findsNothing);
    expect(banc.sante.lectures, 0);

    banc.changerProfil(profilDe(montre: true));
    await banc.monter(tester);
    expect(banc.sante.lectures, 1);
    expect(find.text('61,2 kg'), findsWidgets);

    banc.changerProfil(profilDe());
    await banc.monter(tester);
    expect(find.text('61,2 kg'), findsNothing);
    expect(find.text('60,0 kg'), findsWidgets);
  });

  testWidgets('pesée : repères enregistrés avec le maintien de la montre', (
    tester,
  ) async {
    final banc = Banc(
      profil: profilDe(montre: true),
      sante: FauxSante(points: semaineType()),
    );
    await banc.suivi.charger(montre: true);
    await banc.monter(tester);

    await taper(tester, 'Ajouter une pesée');
    await saisir(tester, 'Poids (kg)', '61');
    await taper(tester, 'Enregistrer');

    final reperes = banc.depot.donnees['u1']!.reperes;
    final attendus = banc.suivi.reperesDuJour(banc.profil);
    expect(reperes.source, SourceMaintien.mesure);
    expect(reperes.maintien, attendus.maintien);
    expect(reperes.kcalCible, attendus.kcalCible);
  });

  testWidgets(
    'changer de période ou noter un repas ne rouvre pas les écoutes',
    (tester) async {
      final banc = Banc();
      await banc.ajouterEnBase(62, DateTime(2026, 10, 5));
      await banc.monter(tester);
      final avant = (
        banc.journal.fluxRepas,
        banc.journal.fluxActivites,
        banc.mensurations.flux,
      );
      expect(avant, (1, 1, 1));

      await taper(tester, '90 jours');
      await banc.journal.ajouterRepas('u1', repasDu(8).first);
      await tester.pumpAndSettle();
      await taper(tester, '30 jours');

      expect((
        banc.journal.fluxRepas,
        banc.journal.fluxActivites,
        banc.mensurations.flux,
      ), avant);
    },
  );

  testWidgets('IMC : chiffre écrit dans une teinte lisible sur le verre', (
    tester,
  ) async {
    final banc = Banc(profil: profilDe(kg: 75));
    await banc.monter(tester);

    final imc = tester.widget<Text>(find.text('26,0'));
    expect(imc.style?.color, PaletteCoach.clair.texteOrange);
  });

  testWidgets('mensurations : saisie partielle, affichage, valeur absurde', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Ajouter des mesures');
    await taper(tester, 'Enregistrer');
    expect(find.text('Entre au moins une mesure.'), findsOneWidget);

    await saisir(tester, 'Tour de taille (cm)', '5');
    await taper(tester, 'Enregistrer');
    expect(
      find.textContaining('Entre une valeur entre 40 et 200'),
      findsOneWidget,
    );

    await saisir(tester, 'Tour de taille (cm)', '88,5');
    await saisir(tester, 'Masse grasse (%)', '22');
    await taper(tester, 'Enregistrer');

    final saisies = banc.mensurations.de('u1');
    expect(saisies, hasLength(1));
    expect(saisies.single.valeurs, {
      TypeMensuration.taille: 88.5,
      TypeMensuration.masseGrasse: 22,
    });
    await defilerJusqua(tester, find.text('88,5 cm'));
    expect(find.text('88,5 cm'), findsOneWidget);
    expect(find.text('22,0 %'), findsOneWidget);
  });

  testWidgets(
    'photos : appareil, bibliothèque, date, comparaison et suppression',
    (tester) async {
      final banc = Banc();
      banc.photos.liste.add(
        PhotoProgres(chemin: '/faux/1.jpg', date: DateTime(2026, 9, 9)),
      );
      await banc.monter(tester);

      await defilerJusqua(tester, find.text('Ajouter une photo'));
      expect(find.text('Comparer'), findsNothing);

      // Annulation depuis l'appareil : rien n'est ajouté.
      banc.photos.annule = true;
      await taper(tester, 'Ajouter une photo');
      await taper(tester, 'Appareil photo');
      expect(banc.photos.liste, hasLength(1));

      // Bibliothèque, à la date du jour par défaut.
      banc.photos.annule = false;
      await taper(tester, 'Ajouter une photo');
      await taper(tester, 'Bibliothèque de photos');
      expect(banc.photos.liste, hasLength(2));
      expect(banc.photos.ajouts.last.source, SourcePhoto.galerie);
      expect(banc.photos.ajouts.last.jour, DateTime(2026, 10, 9));

      // Une date choisie dans le calendrier, depuis l'appareil.
      await taper(tester, 'Ajouter une photo');
      // Vignettes décodées à leur taille d'affichage, pas en 1600 px.
      final vignette = tester.widget<Image>(find.byType(Image).first);
      expect(vignette.image, isA<ResizeImage>());
      expect(
        (vignette.image as ResizeImage).width,
        (90 * tester.view.devicePixelRatio).round(),
      );

      await taper(tester, 'Date de la photo : 9 oct. 2026');
      await tester.tap(find.text('3'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await taper(tester, 'Appareil photo');
      expect(banc.photos.ajouts.last.source, SourcePhoto.appareil);
      expect(banc.photos.ajouts.last.jour, DateTime(2026, 10, 3));

      await taper(tester, 'Comparer');
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Avant'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Supprimer la photo').first);
      await tester.pumpAndSettle();
      expect(banc.photos.liste, hasLength(2));
    },
  );

  test(
    'quadrillage : pas des traits selon la période et l\'écart de poids',
    () {
      final mois = grilleCourbe(
        jours: 30,
        poids: [79.2, 80.4, 81],
        avecProjection: false,
      );
      expect(mois.pasJours, 7);
      expect(mois.pasKg, 1);
      expect(mois.minY, 78);
      expect(mois.maxY, 82);
      expect(mois.maxX, 31);

      final trimestre = grilleCourbe(
        jours: 90,
        poids: [70, 78],
        avecProjection: true,
      );
      expect(trimestre.pasJours, 15);
      expect(trimestre.pasKg, 2);
      expect(trimestre.minY, 68);
      expect(trimestre.maxY, 80);
      expect(trimestre.maxX, 95);

      final an = grilleCourbe(
        jours: 365,
        poids: [60, 90],
        avecProjection: false,
      );
      expect(an.pasJours, 60);
      expect(an.pasKg, 5);
      expect(an.minY, 55);
      expect(an.maxY, 95);
    },
  );

  testWidgets('la courbe est tracée sur un quadrillage avec dates et kilos', (
    tester,
  ) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 9, 20));
    await banc.ajouterEnBase(61, DateTime(2026, 10, 5));
    await banc.monter(tester);

    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.gridData.show, isTrue);
    expect(data.gridData.drawHorizontalLine, isTrue);
    expect(data.gridData.drawVerticalLine, isTrue);
    expect(data.gridData.verticalInterval, 7);
    expect(data.gridData.horizontalInterval, 1);
    expect(data.borderData.show, isTrue);
    expect(data.titlesData.bottomTitles.sideTitles.showTitles, isTrue);
    expect(data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
    expect(data.minY, 60);
    expect(data.maxY, 63);
    expect(data.minX, 0);
  });
}
