import 'package:coach/accueil/accueil_page.dart';
import 'package:coach/accueil/anneaux.dart';
import 'package:coach/accueil/carte_semaine.dart';
import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/journal/journal_page.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/profil/questionnaire/questionnaire_page.dart';
import 'package:coach/racine.dart';
import 'package:coach/reglages/reglage_rapports.dart';
import 'package:coach/reglages/reglage_theme.dart';
import 'package:coach/sante/modele.dart';
import 'package:coach/sante/sante_service.dart';
import 'package:coach/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'donnees_sante.dart';
import 'fakes.dart';
import 'parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);
final liensOuverts = <Uri>[];

const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

// Profil « perte simple » de la tâche 3 : 2080 kcal, 128 g de protéines.
const perteSimple = Profil(
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

Future<void> monter(
  WidgetTester tester,
  AuthService auth,
  ProfilRepository depot, {
  SanteService? sante,
  FauxPesees? pesees,
  FauxReseau? reseau,
  FausseMiseAJour? miseAJour,
  FauxDonnees? donnees,
  FauxConsentements? consentements,
  FauxWidget? widgetAccueil,
  ReglageTheme? theme,
  FausseSauvegarde? sauvegarde,
  FauxFichiers? fichiers,
  ReglageRapports? rapports,
}) async {
  final reglageTheme = theme ?? ReglageThemeFixe();
  await tester.pumpWidget(
    CoachApp(
      theme: reglageTheme.mode,
      accueil: Racine(
        services: Services(
          auth: auth,
          depot: depot,
          sante: sante ?? FauxSante(dispo: DispoSante.indisponible),
          pesees: pesees ?? FauxPesees(),
          journal: FauxJournal(),
          mensurations: FauxMensurations(),
          photos: FausPhotos(),
          photosRepas: FausPhotosRepas(),
          theme: reglageTheme,
          rapports: rapports ?? ReglageRapportsFixe(),
          sauvegarde: sauvegarde ?? FausseSauvegarde(),
          fichiers: fichiers ?? FauxFichiers(),
          catalogue: FauxCatalogue(),
          entrainement: FauxEntrainement(),
          voix: FausseVoix(),
          bienetre: FauxBienEtre(),
          meteo: FausseMeteo(),
          rappels: FauxRappels(),
          reseau: reseau ?? FauxReseau(),
          analyse: FausseAnalyse(),
          planning: FauxPlanning(),
          avis: FauxAvis(),
          donnees: donnees ?? FauxDonnees(),
          consentements: consentements ?? FauxConsentements(),
          widgetAccueil: widgetAccueil ?? FauxWidget(),
          miseAJour: miseAJour ?? FausseMiseAJour(),
          versionAppli: FausseVersion(),
          ouvrirLien: (u) async {
            liensOuverts.add(u);
            return true;
          },
        ),
        horloge: () => maintenant,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FauxDepot depotAvecProfil([Profil profil = perteSimple]) =>
    FauxDepot()
      ..donnees['u1'] = ProfilEnregistre(
        profil: profil,
        reperes: calculerReperes(profil, maintenant: maintenant),
      );

/// Texte (chiffre et objectif) dans la carte « Aujourd'hui ».
Finder dansAujourdhui(String texte) => find.descendant(
  of: find.byType(CarteAujourdhui),
  matching: find.textContaining(texte, findRichText: true),
);

/// Texte (chiffre et objectif) dans la carte « Ma semaine ».
Finder dansSemaine(String texte) => find.descendant(
  of: find.byType(CarteSemaine),
  matching: find.textContaining(texte, findRichText: true),
);

void main() {
  testWidgets('non connecté : page de bienvenue', (tester) async {
    await monter(tester, FauxAuth(), FauxDepot());

    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text("J'ai déjà un compte"), findsOneWidget);
    expect(find.text('Repas en photo, sans compter'), findsOneWidget);
  });

  testWidgets('compte existant sur un nouveau téléphone : accueil direct', (
    tester,
  ) async {
    await monter(tester, FauxAuth(reponse: () async => lea), depotAvecProfil());

    await taper(tester, "J'ai déjà un compte");

    expect(find.text('Bonjour Léa !'), findsOneWidget);
    expect(find.text('Quel est ton objectif ?'), findsNothing);
  });

  testWidgets('enregistrement hors-ligne : l\'accueil s\'affiche quand même', (
    tester,
  ) async {
    await monter(
      tester,
      FauxAuth(reponse: () async => lea),
      FauxDepot(bloquerEnregistrement: true),
    );

    await taper(tester, 'Commencer');
    await remplirJusquaSante(tester);
    await sansMontre(tester);
    await taper(tester, 'Continuer avec Google');

    expect(find.text('Bonjour Léa !'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsNothing);
  });

  testWidgets("repères affichés directement sur l'accueil", (tester) async {
    await monter(tester, FauxAuth(connecte: lea), depotAvecProfil());

    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(dansAujourdhui('/ 2080 kcal'), findsOneWidget);
    expect(dansAujourdhui('/ 128 g'), findsOneWidget);
    expect(find.text('Objectif : perdre du poids'), findsOneWidget);
    // « Ma semaine », sous la carte du jour, compare à la même cible.
    expect(find.text('Ma semaine'), findsOneWidget);
    expect(dansSemaine('/ 2080 kcal'), findsOneWidget);
    expect(dansSemaine('/ 128 g'), findsOneWidget);
  });

  testWidgets('se déconnecter : retour à la bienvenue, widget vidé', (
    tester,
  ) async {
    final widget = FauxWidget();
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depotAvecProfil(),
      widgetAccueil: widget,
    );
    expect(widget.effacements, 0);

    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    await taper(tester, 'Se déconnecter');

    expect(find.text('Commencer'), findsOneWidget);
    // Le widget de l'écran d'accueil ne garde rien du compte, une seule fois.
    expect(widget.effacements, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(widget.effacements, 1);
  });

  testWidgets('non connecté au lancement : widget vidé une fois', (
    tester,
  ) async {
    final widget = FauxWidget();
    await monter(tester, FauxAuth(), FauxDepot(), widgetAccueil: widget);

    expect(widget.effacements, 1);
  });

  testWidgets('modifier mon profil : questionnaire prérempli puis accueil', (
    tester,
  ) async {
    final depot = depotAvecProfil();
    await monter(tester, FauxAuth(connecte: lea), depot);

    await taper(tester, 'Modifier mon profil');
    expect(find.text('Quel est ton objectif ?'), findsOneWidget);
    await taper(tester, 'Prendre du muscle');
    for (var i = 0; i < 9; i++) {
      await taper(tester, 'Suivant');
    }
    // Écran de résultat : rien n'est enregistré avant « C'est parti ».
    expect(find.text('Ton plan'), findsOneWidget);
    expect(depot.donnees['u1']?.profil.objectif, Objectif.perte);
    await taper(tester, "C'est parti");

    expect(depot.donnees['u1']?.profil.objectif, Objectif.muscle);
    expect(find.byType(AccueilPage), findsOneWidget);
    expect(find.byType(QuestionnairePage), findsNothing);
  });

  final avecMontre = perteSimple.copyWith(
    montre: true,
    appMontre: AppMontre.miFitness,
    poidsDate: DateTime(2026, 10, 1),
  );

  testWidgets('montre : repères mesurés et Ma journée', (tester) async {
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depotAvecProfil(avecMontre),
      sante: FauxSante(points: semaineType()),
    );

    expect(dansAujourdhui('/ 2210 kcal'), findsOneWidget);
    expect(dansSemaine('/ 2210 kcal'), findsOneWidget);
    await defilerJusqua(tester, find.text('6500'));
    expect(find.text('6500'), findsOneWidget);
    expect(find.text('7 h 00'), findsOneWidget);
  });

  testWidgets('montre sans Health Connect : repères estimés', (tester) async {
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depotAvecProfil(avecMontre),
      sante: FauxSante(dispo: DispoSante.indisponible),
    );

    expect(
      find.textContaining('Estimé jusqu', findRichText: true),
      findsOneWidget,
    );
    expect(dansAujourdhui('/ 2080 kcal'), findsOneWidget);
  });

  testWidgets('pesée plus récente : poids du profil mis à jour', (
    tester,
  ) async {
    final depot = depotAvecProfil(avecMontre);
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depot,
      sante: FauxSante(points: semaineType()),
    );

    final profil = depot.donnees['u1']!.profil;
    expect(profil.poidsKg, 79.5);
    expect(profil.poidsDate, DateTime(2026, 10, 9, 7));
  });

  testWidgets('pesée importée : repères enregistrés avec le maintien mesuré', (
    tester,
  ) async {
    final depot = depotAvecProfil(avecMontre);
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depot,
      sante: FauxSante(points: semaineType()),
    );

    // Le même objectif que l'accueil et le journal, pas l'estimation du type
    // de vie.
    final enregistre = depot.donnees['u1']!;
    expect(enregistre.profil.poidsKg, 79.5);
    expect(enregistre.reperes.source, SourceMaintien.mesure);
  });

  List<PointSante> pesee(double kg) => [
    PointSante(
      type: TypeMesure.poids,
      debut: DateTime(2026, 10, 9, 7),
      fin: DateTime(2026, 10, 9, 7),
      valeur: kg,
    ),
  ];

  testWidgets('pesée importée à IMC 18,3 : objectif « garder la forme »', (
    tester,
  ) async {
    // 59,3 kg pour 1,80 m : IMC 18,3, sous 18,5. La dernière pesée du profil
    // date d'un mois : pas de question.
    final depot = depotAvecProfil(
      avecMontre.copyWith(poidsDate: DateTime(2026, 9, 1)),
    );
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depot,
      sante: FauxSante(points: pesee(59.3)),
    );

    expect(find.byType(AlertDialog), findsNothing);
    final profil = depot.donnees['u1']!.profil;
    expect(profil.poidsKg, 59.3);
    expect(profil.objectif, Objectif.forme);
  });

  final peseeRecente = avecMontre.copyWith(poidsDate: DateTime(2026, 10, 5));

  testWidgets('pesée très différente : importée seulement si confirmée', (
    tester,
  ) async {
    final depot = depotAvecProfil(peseeRecente);
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depot,
      sante: FauxSante(points: pesee(72.4)),
    );

    expect(find.text('Importer 72,4 kg de ta balance ?'), findsOneWidget);
    // Rien n'est enregistré avant la réponse.
    expect(depot.donnees['u1']!.profil.poidsKg, 80);

    await taper(tester, 'Importer');

    expect(find.byType(AlertDialog), findsNothing);
    expect(depot.donnees['u1']!.profil.poidsKg, 72.4);
  });

  testWidgets('pesée très différente ignorée : profil inchangé', (
    tester,
  ) async {
    final depot = depotAvecProfil(peseeRecente);
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depot,
      sante: FauxSante(points: pesee(72.4)),
    );

    await taper(tester, 'Ignorer');

    expect(find.byType(AlertDialog), findsNothing);
    expect(depot.donnees['u1']!.profil.poidsKg, 80);
    expect(depot.donnees['u1']!.profil.poidsDate, DateTime(2026, 10, 5));
  });

  testWidgets('pesée invraisemblable (12 kg) : ignorée sans question', (
    tester,
  ) async {
    final depot = depotAvecProfil(peseeRecente);
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depot,
      sante: FauxSante(points: pesee(12)),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(depot.donnees['u1']!.profil.poidsKg, 80);
  });

  testWidgets('sans montre : invitation à en connecter une', (tester) async {
    await monter(tester, FauxAuth(connecte: lea), depotAvecProfil());

    await defilerJusqua(tester, find.text('Connecte ta montre'));
    expect(find.text('Connecte ta montre'), findsOneWidget);
  });

  testWidgets('Ma journée ouvre Mes données', (tester) async {
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depotAvecProfil(avecMontre),
      sante: FauxSante(points: semaineType()),
    );

    await taper(tester, 'Voir le détail');

    expect(find.text('Mes données'), findsOneWidget);
  });

  testWidgets("onglet Poids : poids du profil et retour à l'accueil", (
    tester,
  ) async {
    await monter(tester, FauxAuth(connecte: lea), depotAvecProfil());

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Poids'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Poids actuel'), findsOneWidget);
    expect(find.text('80,0 kg'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Accueil'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bonjour Léa !'), findsOneWidget);
  });

  testWidgets('onglet Journal : bilan énergétique du jour', (tester) async {
    await monter(tester, FauxAuth(connecte: lea), depotAvecProfil());

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Repas'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bilan énergétique'), findsOneWidget);
    expect(find.text('Objectif du jour : 2080 kcal'), findsOneWidget);
  });

  testWidgets('hors-ligne : bandeau, qui disparaît au retour du réseau', (
    tester,
  ) async {
    final reseau = FauxReseau(false);
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depotAvecProfil(),
      reseau: reseau,
    );
    expect(find.textContaining('Hors-ligne'), findsOneWidget);

    reseau.changer(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Hors-ligne'), findsNothing);

    reseau.changer(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Hors-ligne'), findsOneWidget);
  });

  testWidgets('les 5 onglets, dans l\'ordre : Poids avant Bien-être', (
    tester,
  ) async {
    await monter(tester, FauxAuth(connecte: lea), depotAvecProfil());
    final noms = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(noms, ['Accueil', 'Repas', 'Sport', 'Poids', 'Bien-être']);

    // Le 4e bouton ouvre bien le Poids, le 5e le Bien-être.
    await tester.tap(find.text('Poids'));
    await tester.pumpAndSettle();
    expect(find.text('Poids actuel'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Bien-être'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hydratation'), findsWidgets);
  });

  testWidgets('widget « Photographier » : ouvre le Repas puis la photo', (
    tester,
  ) async {
    final widget = FauxWidget();
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depotAvecProfil(),
      widgetAccueil: widget,
    );
    expect(find.text('Bilan énergétique'), findsNothing);

    widget.demandes.add('photo');
    await tester.pumpAndSettle();

    // L'onglet Repas est ouvert, puis l'écran de photo (l'accord n'est
    // demandé qu'au choix d'une photo).
    expect(find.byType(NavigationBar, skipOffstage: false), findsOneWidget);
    expect(find.text('Prendre une photo'), findsOneWidget);
  });

  testWidgets('application lancée par le widget « Photographier »', (
    tester,
  ) async {
    final widget = FauxWidget()..lancement = 'photo';
    await monter(
      tester,
      FauxAuth(connecte: lea),
      depotAvecProfil(),
      widgetAccueil: widget,
    );

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Bonjour Léa !'), findsNothing);
  });

  testWidgets('accueil : « Idées de repas » ouvre les cartes à balayer', (
    tester,
  ) async {
    await monter(tester, FauxAuth(connecte: lea), depotAvecProfil());

    await taper(tester, 'Idées de repas');

    expect(find.textContaining('kcal pour toi'), findsWidgets);
    expect(find.byTooltip('Mes envies'), findsOneWidget);
  });

  testWidgets('accueil : « Ton programme » ouvre l\'onglet Sport', (
    tester,
  ) async {
    await monter(tester, FauxAuth(connecte: lea), depotAvecProfil());

    await taper(tester, 'Ton programme');

    expect(find.text('Commencer la séance'), findsOneWidget);
  });

  testWidgets('accueil : « Ma semaine » ouvre le Journal', (tester) async {
    await monter(tester, FauxAuth(connecte: lea), depotAvecProfil());
    expect(find.byType(JournalPage), findsNothing);

    await taper(tester, 'Ma semaine');

    expect(find.byType(JournalPage), findsOneWidget);
  });
}
