import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/racine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'parcours.dart';

final maintenant = DateTime(2026, 10, 9);

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

Future<void> monter(WidgetTester tester, AuthService auth, ProfilRepository depot) async {
  await tester.pumpWidget(CoachApp(
    accueil: Racine(auth: auth, depot: depot, horloge: () => maintenant),
  ));
  await tester.pumpAndSettle();
}

FauxDepot depotAvecProfil() => FauxDepot()
  ..donnees['u1'] = ProfilEnregistre(
    profil: perteSimple,
    reperes: calculerReperes(perteSimple, maintenant: maintenant),
  );

void main() {
  testWidgets('non connecté : page de bienvenue', (tester) async {
    await monter(tester, FauxAuth(), FauxDepot());

    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text("J'ai déjà un compte"), findsOneWidget);
    expect(find.text('Repas en photo, sans compter'), findsOneWidget);
  });

  testWidgets('compte existant sur un nouveau téléphone : accueil direct',
      (tester) async {
    await monter(tester, FauxAuth(reponse: () async => lea), depotAvecProfil());

    await taper(tester, "J'ai déjà un compte");

    expect(find.text('Bonjour Léa !'), findsOneWidget);
    expect(find.text('Quel est ton objectif ?'), findsNothing);
  });

  testWidgets('enregistrement hors-ligne : l\'accueil s\'affiche quand même',
      (tester) async {
    await monter(tester, FauxAuth(reponse: () async => lea),
        FauxDepot(bloquerEnregistrement: true));

    await taper(tester, 'Commencer');
    await remplirJusquaSante(tester);
    await taper(tester, 'Suivant');
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

  testWidgets('modifier mon profil : questionnaire prérempli puis accueil',
      (tester) async {
    final depot = depotAvecProfil();
    await monter(tester, FauxAuth(connecte: lea), depot);

    await taper(tester, 'Modifier mon profil');
    expect(find.text('Quel est ton objectif ?'), findsOneWidget);
    await taper(tester, 'Prendre du muscle');
    for (var i = 0; i < 7; i++) {
      await taper(tester, 'Suivant');
    }
    await taper(tester, 'Suivant');

    expect(depot.donnees['u1']?.profil.objectif, Objectif.muscle);
    expect(find.text('Bonjour Léa !'), findsOneWidget);
  });
}
