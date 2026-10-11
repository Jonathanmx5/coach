import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/questionnaire/controleur.dart';
import 'package:coach/profil/questionnaire/questionnaire_page.dart';
import 'package:coach/sante/sante_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import '../../parcours.dart';

final maintenant = DateTime(2026, 10, 9);

final profilAttendu = Profil(
  objectif: Objectif.perte,
  sexe: Sexe.homme,
  anneeNaissance: 1996,
  tailleCm: 180,
  poidsKg: 80.5,
  typeDeVie: TypeDeVie.peuActif,
  typesEntrainement: {TypeEntrainement.salle},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 45,
  problemeSante: false,
  poidsDate: maintenant,
);

class Banc {
  Banc({Future<Utilisateur?> Function()? reponse, FauxSante? sante})
    : auth = FauxAuth(reponse: reponse),
      sante = sante ?? FauxSante();

  final FauxAuth auth;
  final FauxSante sante;
  final depot = FauxDepot();
  final controleur = QuestionnaireControleur(
    maintenant: maintenant,
    avecConnexion: true,
  );
  var termine = false;

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      CoachApp(
        accueil: QuestionnairePage(
          controleur: controleur,
          auth: auth,
          depot: depot,
          sante: sante,
          horloge: () => maintenant,
          quandTermine: () => termine = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

bool suivantActif(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Suivant'))
        .onPressed !=
    null;

void main() {
  testWidgets('parcours complet puis connexion : profil enregistré', (
    tester,
  ) async {
    final banc = Banc(
      reponse: () async => const Utilisateur(uid: 'u1', prenom: 'Léa'),
    );
    await banc.monter(tester);

    await remplirJusquaSante(tester);
    await sansMontre(tester);
    await taper(tester, 'Continuer avec Google');

    expect(banc.depot.donnees['u1']?.profil, profilAttendu);
    expect(banc.depot.donnees['u1']?.reperes.kcalCible, isPositive);
    expect(banc.termine, isTrue);
  });

  testWidgets('connexion annulée : reste sur place, sans erreur', (
    tester,
  ) async {
    final banc = Banc(reponse: () async => null);
    await banc.monter(tester);

    await remplirJusquaSante(tester);
    await sansMontre(tester);
    await taper(tester, 'Continuer avec Google');

    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.textContaining('La connexion a échoué'), findsNothing);
    expect(banc.termine, isFalse);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(banc.controleur.construireProfil(), profilAttendu);
  });

  testWidgets('connexion en erreur : message affiché', (tester) async {
    final banc = Banc(
      reponse: () async => throw const ConnexionEchouee('réseau'),
    );
    await banc.monter(tester);

    await remplirJusquaSante(tester);
    await sansMontre(tester);
    await taper(tester, 'Continuer avec Google');

    expect(find.textContaining('La connexion a échoué'), findsOneWidget);
    expect(banc.termine, isFalse);
  });

  testWidgets('17 ans : message mineur et Suivant désactivé', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Garder la forme');
    await taper(tester, 'Suivant');
    await taper(tester, 'Femme');
    await saisir(tester, 'Âge', '17');

    expect(
      find.textContaining('réservé aux personnes de 18 ans'),
      findsOneWidget,
    );
    expect(suivantActif(tester), isFalse);
  });

  testWidgets('santé oui : conseil du médecin affiché', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await remplirJusquaSante(tester, sante: true);

    expect(find.textContaining('Parles-en à ton médecin'), findsOneWidget);
    expect(find.text('Crunch & Go ne remplace pas un avis médical.'), findsOneWidget);
  });

  testWidgets("indique l'étape en cours sur le total", (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    expect(find.text('Étape 1 sur 10'), findsOneWidget);
    expect(find.byTooltip('Retour'), findsNothing);
    await taper(tester, 'Garder la forme');
    await taper(tester, 'Suivant');
    expect(find.text('Étape 2 sur 10'), findsOneWidget);
    expect(find.byTooltip('Retour'), findsOneWidget);
  });

  Future<void> jusquaAppMontre(WidgetTester tester) async {
    await remplirJusquaSante(tester);
    await taper(tester, 'Suivant');
    await taper(tester, 'Oui');
    await taper(tester, 'Suivant');
    await taper(tester, 'Mi Fitness');
  }

  testWidgets('montre : autorisation accordée', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await jusquaAppMontre(tester);
    await defilerJusqua(
      tester,
      find.textContaining('Dans Mi Fitness, active le partage'),
    );
    expect(
      find.textContaining('Dans Mi Fitness, active le partage'),
      findsOneWidget,
    );
    await taper(tester, "Autoriser l'accès");

    expect(banc.sante.autorisationsDemandees, 1);
    await defilerJusqua(tester, find.textContaining('Accès autorisé'));
    expect(find.textContaining('Accès autorisé'), findsOneWidget);
  });

  testWidgets('montre : refus bienveillant, Suivant reste possible', (
    tester,
  ) async {
    final banc = Banc(sante: FauxSante(accorde: false));
    await banc.monter(tester);

    await jusquaAppMontre(tester);
    await taper(tester, "Autoriser l'accès");

    await defilerJusqua(tester, find.textContaining('Pas de souci'));
    expect(find.textContaining('Pas de souci'), findsOneWidget);
    expect(suivantActif(tester), isTrue);
    await taper(tester, 'Suivant');
    expect(find.text('Continuer avec Google'), findsOneWidget);
  });

  testWidgets('montre : Health Connect à installer', (tester) async {
    final banc = Banc(sante: FauxSante(dispo: DispoSante.aInstaller));
    await banc.monter(tester);

    await jusquaAppMontre(tester);
    await taper(tester, 'Installer Health Connect');

    expect(banc.sante.installations, 1);
  });
}
