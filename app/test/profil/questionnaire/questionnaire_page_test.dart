import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/questionnaire/controleur.dart';
import 'package:coach/profil/questionnaire/questionnaire_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

final maintenant = DateTime(2026, 10, 9);

const profilAttendu = Profil(
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
);

class Banc {
  Banc({Future<Utilisateur?> Function()? reponse})
      : auth = FauxAuth(reponse: reponse);

  final FauxAuth auth;
  final depot = FauxDepot();
  final controleur =
      QuestionnaireControleur(maintenant: maintenant, avecConnexion: true);
  var termine = false;

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(CoachApp(
      accueil: QuestionnairePage(
        controleur: controleur,
        auth: auth,
        depot: depot,
        horloge: () => maintenant,
        quandTermine: () => termine = true,
      ),
    ));
    await tester.pumpAndSettle();
  }
}

Future<void> taper(WidgetTester tester, String texte) async {
  await tester.ensureVisible(find.text(texte).last);
  await tester.tap(find.text(texte).last);
  await tester.pumpAndSettle();
}

Future<void> saisir(WidgetTester tester, String champ, String valeur) async {
  await tester.enterText(find.widgetWithText(TextField, champ), valeur);
  await tester.pumpAndSettle();
}

/// Répond à tout jusqu'à l'étape santé incluse.
Future<void> remplirJusquaSante(WidgetTester tester, {bool sante = false}) async {
  await taper(tester, 'Perdre du poids');
  await taper(tester, 'Suivant');
  await taper(tester, 'Homme');
  await saisir(tester, 'Âge', '30');
  await taper(tester, 'Suivant');
  await saisir(tester, 'Taille (cm)', '180');
  await saisir(tester, 'Poids (kg)', '80,5');
  await taper(tester, 'Suivant');
  await taper(tester, 'Un peu actif');
  await taper(tester, 'Suivant');
  await taper(tester, 'Salle de sport');
  await taper(tester, 'Suivant');
  await taper(tester, 'Débutant');
  await taper(tester, 'Suivant');
  await taper(tester, '3');
  await taper(tester, '45 min');
  await taper(tester, 'Suivant');
  await taper(tester, sante ? 'Oui' : 'Non');
}

bool suivantActif(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Suivant'))
        .onPressed !=
    null;

void main() {
  testWidgets('parcours complet puis connexion : profil enregistré',
      (tester) async {
    final banc =
        Banc(reponse: () async => const Utilisateur(uid: 'u1', prenom: 'Léa'));
    await banc.monter(tester);

    await remplirJusquaSante(tester);
    await taper(tester, 'Suivant');
    await taper(tester, 'Continuer avec Google');

    expect(banc.depot.donnees['u1']?.profil, profilAttendu);
    expect(banc.depot.donnees['u1']?.reperes.kcalCible, isPositive);
    expect(banc.termine, isTrue);
  });

  testWidgets('connexion annulée : reste sur place, sans erreur',
      (tester) async {
    final banc = Banc(reponse: () async => null);
    await banc.monter(tester);

    await remplirJusquaSante(tester);
    await taper(tester, 'Suivant');
    await taper(tester, 'Continuer avec Google');

    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.textContaining('La connexion a échoué'), findsNothing);
    expect(banc.termine, isFalse);
    await taper(tester, 'Retour');
    expect(banc.controleur.construireProfil(), profilAttendu);
  });

  testWidgets('connexion en erreur : message affiché', (tester) async {
    final banc = Banc(
        reponse: () async => throw const ConnexionEchouee('réseau'));
    await banc.monter(tester);

    await remplirJusquaSante(tester);
    await taper(tester, 'Suivant');
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

    expect(find.textContaining('réservé aux personnes de 18 ans'),
        findsOneWidget);
    expect(suivantActif(tester), isFalse);
  });

  testWidgets('santé oui : conseil du médecin affiché', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await remplirJusquaSante(tester, sante: true);

    expect(find.textContaining('Parles-en à ton médecin'), findsOneWidget);
    expect(find.text('Coach ne remplace pas un avis médical.'), findsOneWidget);
  });
}
