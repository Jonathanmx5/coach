import 'dart:async';

import 'package:coach/accueil/accueil_page.dart';
import 'package:coach/app.dart';
import 'package:coach/bienetre/bienetre_page.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/coque.dart';
import 'package:coach/entrainement/entrainement_page.dart';
import 'package:coach/journal/journal_page.dart';
import 'package:coach/poids/poids_page.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/recettes/idees_page.dart';
import 'package:coach/reglages/reglage_rapports.dart';
import 'package:coach/reglages/reglage_theme.dart';
import 'package:coach/reglages/reglages_page.dart';
import 'package:coach/route_verre.dart';
import 'package:coach/sante/suivi.dart';
import 'package:coach/services.dart';
import 'package:coach/theme.dart';
import 'package:coach/verre.dart';
import 'package:coach/widget/donnees_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'donnees_sante.dart';
import 'fakes.dart';

const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

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
);

/// Le vrai widget d'accueil (action de lancement rendue une seule fois),
/// sans le canal des boutons, absent des tests.
class WidgetSansCanal extends WidgetAccueil {
  WidgetSansCanal(Uri lancement)
    : super(
        stockage: FauxStockageWidget(),
        dessiner: (_) async {},
        lancement: () async => lancement,
      );

  @override
  Stream<String> get actions => const Stream.empty();
}

/// Banc d'essai de la coque seule, avec une horloge réglable.
class Banc {
  Banc({FauxSante? sante, MiseAJourWidget? widgetAccueil, this.montre = false})
    : sante = sante ?? FauxSante(),
      widgetAccueil = widgetAccueil ?? FauxWidget();

  final FauxSante sante;
  final MiseAJourWidget widgetAccueil;
  final bool montre;
  // Les faux comptent les flux ouverts (chaque appel crée une écoute).
  final journal = FauxJournal();
  final mensurations = FauxMensurations();
  final reseau = FauxReseau();
  DateTime heure = DateTime(2026, 10, 9, 20);

  late final ProfilEnregistre enregistre = ProfilEnregistre(
    profil: profil.copyWith(montre: montre),
    reperes: calculerReperes(profil, maintenant: heure),
  );

  late final Services services = Services(
    auth: FauxAuth(connecte: lea),
    depot: FauxDepot()..donnees['u1'] = enregistre,
    sante: sante,
    pesees: FauxPesees(),
    journal: journal,
    mensurations: mensurations,
    photos: FausPhotos(),
    photosRepas: FausPhotosRepas(),
    theme: ReglageThemeFixe(),
    rapports: ReglageRapportsFixe(),
    sauvegarde: FausseSauvegarde(),
    fichiers: FauxFichiers(),
    catalogue: FauxCatalogue(),
    entrainement: FauxEntrainement(),
    voix: FausseVoix(),
    bienetre: FauxBienEtre(),
    meteo: FausseMeteo(),
    rappels: FauxRappels(),
    reseau: reseau,
    analyse: FausseAnalyse(),
    planning: FauxPlanning(),
    avis: FauxAvis(),
    donnees: FauxDonnees(),
    consentements: FauxConsentements(),
    widgetAccueil: widgetAccueil,
    miseAJour: FausseMiseAJour(),
    versionAppli: FausseVersion(),
    ouvrirLien: (_) async => true,
  );

  /// Monte (ou recrée, avec une autre [cle]) la coque.
  Future<void> monter(
    WidgetTester tester, {
    Key? cle,
    ThemeMode theme = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      CoachApp(
        theme: ReglageThemeFixe(theme).mode,
        accueil: Coque(
          key: cle,
          utilisateur: lea,
          enregistre: enregistre,
          services: services,
          horloge: () => heure,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> onglet(WidgetTester tester, String nom) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(nom)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('onglets', () {
    testWidgets('au démarrage, seul l\'onglet Accueil est construit', (
      tester,
    ) async {
      final banc = Banc();
      await banc.monter(tester);

      expect(find.byType(AccueilPage), findsOneWidget);
      expect(find.byType(JournalPage), findsNothing);
      expect(find.byType(EntrainementPage), findsNothing);
      expect(find.byType(PoidsPage), findsNothing);
      expect(find.byType(BienEtrePage), findsNothing);
      // Aucun abonnement de l'onglet Poids tant qu'il n'est pas ouvert.
      expect(banc.mensurations.flux, 0);

      await onglet(tester, 'Poids');
      expect(find.byType(PoidsPage), findsOneWidget);
      expect(banc.mensurations.flux, greaterThan(0));
      // L'Accueil déjà visité est gardé ; les autres attendent leur visite.
      expect(find.byType(AccueilPage, skipOffstage: false), findsOneWidget);
      expect(find.byType(JournalPage, skipOffstage: false), findsNothing);
    });

    testWidgets('changer d\'onglet ne recrée pas les flux de la page Poids', (
      tester,
    ) async {
      final banc = Banc();
      await banc.monter(tester);
      await onglet(tester, 'Poids');
      final repas = banc.journal.fluxRepas;
      final activites = banc.journal.fluxActivites;
      final mensurations = banc.mensurations.flux;

      await onglet(tester, 'Accueil');
      await onglet(tester, 'Sport');
      await onglet(tester, 'Bien-être');
      await onglet(tester, 'Poids');

      expect(banc.mensurations.flux, mensurations);
      // Les autres onglets ouvrent leurs propres flux à leur première
      // visite ; un deuxième passage n'en ouvre plus aucun.
      final repasApres = banc.journal.fluxRepas;
      final activitesApres = banc.journal.fluxActivites;
      expect(repasApres, greaterThanOrEqualTo(repas));
      expect(activitesApres, greaterThanOrEqualTo(activites));
      await onglet(tester, 'Accueil');
      await onglet(tester, 'Sport');
      await onglet(tester, 'Bien-être');
      await onglet(tester, 'Poids');
      expect(banc.journal.fluxRepas, repasApres);
      expect(banc.journal.fluxActivites, activitesApres);
      expect(banc.mensurations.flux, mensurations);
    });

    testWidgets('« Photographier » pendant que le Repas n\'est pas encore '
        'construit : la demande arrive quand même', (tester) async {
      final widget = FauxWidget();
      final banc = Banc(widgetAccueil: widget);
      await banc.monter(tester);
      expect(find.byType(JournalPage), findsNothing);

      widget.demandes.add('photo');
      await tester.pumpAndSettle();

      expect(find.byType(JournalPage, skipOffstage: false), findsOneWidget);
      // L'écran photo est ouvert ; l'accord ne sera demandé qu'au choix
      // d'une photo.
      expect(find.text('Prendre une photo'), findsOneWidget);
    });
  });

  testWidgets(
    'action de lancement rejouée après recréation de la coque : aucune '
    'deuxième ouverture de la photo',
    (tester) async {
      final banc = Banc(
        widgetAccueil: WidgetSansCanal(
          Uri.parse('coach://photo?source=appareil'),
        ),
      );
      await banc.monter(tester, cle: const ValueKey(1));
      expect(find.text("Envoyer la photo pour l'analyse ?"), findsOneWidget);
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      // Sans accord, l'écran photo reste ouvert : on le referme.
      Navigator.of(tester.element(find.byType(Coque, skipOffstage: false)))
          .popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();

      // Autre compte, ou retour du questionnaire : la coque est recréée.
      await banc.monter(tester, cle: const ValueKey(2));

      expect(find.text("Envoyer la photo pour l'analyse ?"), findsNothing);
      expect(find.byType(AccueilPage), findsOneWidget);
      // Le Repas n'a même pas été ouvert.
      expect(find.byType(JournalPage, skipOffstage: false), findsNothing);
    },
  );

  group('suivi santé à la reprise', () {
    Banc avecMontre() => Banc(montre: true, sante: FauxSante());

    testWidgets('resumed après minuit : le suivi est relu', (tester) async {
      final banc = avecMontre();
      await banc.monter(tester);
      final lectures = banc.sante.lectures;
      expect(lectures, greaterThan(0));

      banc.heure = DateTime(2026, 10, 10, 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(banc.sante.lectures, lectures + 1);
    });

    testWidgets('resumed peu après le chargement : pas de relecture', (
      tester,
    ) async {
      final banc = avecMontre();
      await banc.monter(tester);
      final lectures = banc.sante.lectures;

      banc.heure = banc.heure.add(const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(banc.sante.lectures, lectures);
    });

    testWidgets('appli ouverte au passage de minuit : le suivi est relu', (
      tester,
    ) async {
      final banc = avecMontre();
      await banc.monter(tester);
      final lectures = banc.sante.lectures;

      // 20:00 → minuit passé : le minuteur de la coque se déclenche.
      banc.heure = DateTime(2026, 10, 10, 0, 0, 2);
      await tester.pump(const Duration(hours: 4, seconds: 2));
      await tester.pumpAndSettle();

      expect(banc.sante.lectures, lectures + 1);
    });
  });

  testWidgets('Idées : la cible du jour, avec le maintien mesuré', (
    tester,
  ) async {
    final banc = Banc(montre: true, sante: FauxSante(points: semaineType()));
    await banc.monter(tester);
    final suivi = Suivi(sante: banc.sante, horloge: () => banc.heure);
    await tester.runAsync(() => suivi.charger(montre: true));
    final mesuree = suivi.reperesDuJour(banc.enregistre.profil).kcalCible;
    expect(mesuree, isNot(banc.enregistre.reperes.kcalCible));

    await tester.ensureVisible(find.text('Idées de repas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Idées de repas'));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<IdeesPage>(find.byType(IdeesPage)).kcalCible, mesuree);
  });

  group('fond de verre des écrans poussés', () {
    testWidgets('Réglages : sur le fond de verre, Scaffold transparent', (
      tester,
    ) async {
      final banc = Banc();
      await banc.monter(tester);

      await tester.tap(find.byTooltip('Réglages'));
      await tester.pumpAndSettle();

      final reglages = find.byType(ReglagesPage);
      expect(reglages, findsOneWidget);
      expect(
        find.ancestor(of: reglages, matching: find.byType(FondVerre)),
        findsOneWidget,
      );
      expect(
        Theme.of(tester.element(reglages)).scaffoldBackgroundColor,
        Colors.transparent,
      );
    });

    for (final (nom, mode) in [
      ('clair', ThemeMode.light),
      ('sombre', ThemeMode.dark),
    ]) {
      testWidgets('thème $nom : la page poussée cache celle du dessous '
          'pendant la transition', (tester) async {
        late BuildContext racine;
        await tester.pumpWidget(
          CoachApp(
            theme: ReglageThemeFixe(mode).mode,
            accueil: Builder(
              builder: (c) {
                racine = c;
                return const Scaffold(body: Text('dessous'));
              },
            ),
          ),
        );
        final route = routeVerre<void>(
          (_) => const Scaffold(body: Text('dessus')),
        );
        expect((route as ModalRoute<void>).opaque, isTrue);
        unawaited(Navigator.of(racine).push(route));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Le fond de la route est plein : ni aplat ni dégradé transparent.
        final fond = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(FondVerre),
                matching: find.byType(DecoratedBox),
              ),
            )
            .first;
        final deco = fond.decoration as BoxDecoration;
        final couleurs = [
          if (deco.gradient != null) ...deco.gradient!.colors,
          if (deco.gradient == null) deco.color!,
        ];
        for (final c in couleurs) {
          expect(c.a, 1.0);
        }
        // Le Scaffold de la page est transparent, sur ce fond.
        expect(
          Theme.of(tester.element(find.text('dessus'))).scaffoldBackgroundColor,
          Colors.transparent,
        );
        await tester.pumpAndSettle();
        expect(find.text('dessus'), findsOneWidget);
      });
    }
  });

  testWidgets('thème sombre : bandeau hors-ligne écrit en foncé sur orange', (
    tester,
  ) async {
    final banc = Banc();
    banc.reseau.changer(false);
    await banc.monter(tester, theme: ThemeMode.dark);
    banc.reseau.changer(false);
    await tester.pumpAndSettle();

    final texte = tester.widget<Text>(find.textContaining('Hors-ligne'));
    expect(texte.style?.color, CouleursCoach.texte);
  });
}
