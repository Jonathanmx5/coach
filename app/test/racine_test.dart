import 'package:coach/accueil/accueil_page.dart';
import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/profil/questionnaire/questionnaire_page.dart';
import 'package:coach/racine.dart';
import 'package:coach/sante/sante_service.dart';
import 'package:coach/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'donnees_sante.dart';
import 'fakes.dart';
import 'parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);

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
  problemeSante: false,
);

Future<void> monter(
  WidgetTester tester,
  AuthService auth,
  ProfilRepository depot, {
  SanteService? sante,
  FauxPesees? pesees,
}) async {
  await tester.pumpWidget(
    CoachApp(
      accueil: Racine(
        services: Services(
          auth: auth,
          depot: depot,
          sante: sante ?? FauxSante(dispo: DispoSante.indisponible),
          pesees: pesees ?? FauxPesees(),
          journal: FauxJournal(),
          catalogue: FauxCatalogue(),
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

    expect(find.text('2080'), findsOneWidget);
    expect(find.text('kcal par jour'), findsOneWidget);
    expect(find.text('128 g'), findsOneWidget);
    expect(find.text('Objectif : perdre du poids'), findsOneWidget);
  });

  testWidgets('se déconnecter : retour à la bienvenue', (tester) async {
    await monter(tester, FauxAuth(connecte: lea), depotAvecProfil());

    await tester.tap(find.byTooltip('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(find.text('Commencer'), findsOneWidget);
  });

  testWidgets('modifier mon profil : questionnaire prérempli puis accueil', (
    tester,
  ) async {
    final depot = depotAvecProfil();
    await monter(tester, FauxAuth(connecte: lea), depot);

    await taper(tester, 'Modifier mon profil');
    expect(find.text('Quel est ton objectif ?'), findsOneWidget);
    await taper(tester, 'Prendre du muscle');
    for (var i = 0; i < 8; i++) {
      await taper(tester, 'Suivant');
    }
    await taper(tester, 'Suivant');

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

    expect(find.text('Mesuré par ta montre'), findsOneWidget);
    expect(find.text('2210'), findsOneWidget);
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

    expect(find.text('Estimé'), findsOneWidget);
    expect(find.text('2080'), findsOneWidget);
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
        matching: find.text('Journal'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bilan énergétique'), findsOneWidget);
    expect(find.text('Objectif du jour : 2080 kcal'), findsOneWidget);
  });
}
