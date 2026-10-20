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

  testWidgets('santé : trois cases, « enceinte » pour les femmes', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await remplirJusquaSante(tester, precaution: 'Douleurs articulaires');

    // Homme : pas de case grossesse.
    expect(find.text('Enceinte ou allaitante'), findsNothing);
    expect(find.text('Perte de poids suivie par un médecin'), findsOneWidget);
    expect(find.textContaining('sans saut ni impact'), findsOneWidget);
    await defilerJusqua(
      tester,
      find.text('Crunch & Go ne remplace pas un avis médical.'),
    );
    expect(
      find.text('Crunch & Go ne remplace pas un avis médical.'),
      findsOneWidget,
    );
    expect(suivantActif(tester), isTrue);
    expect(banc.controleur.precautions, {Precaution.douleursArticulaires});
  });

  testWidgets('enceinte : la perte devient « garder la forme »', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Perdre du poids');
    await taper(tester, 'Suivant');
    await taper(tester, 'Femme');
    await saisir(tester, 'Âge', '30');
    await taper(tester, 'Suivant');
    await saisir(tester, 'Taille (cm)', '165');
    await saisir(tester, 'Poids (kg)', '70');
    await taper(tester, 'Suivant');
    await taper(tester, 'Un peu actif');
    await taper(tester, 'Suivant');
    await taper(tester, 'À la maison');
    await taper(tester, 'Suivant');
    await taper(tester, 'Débutant');
    await taper(tester, 'Suivant');
    await taper(tester, '3');
    await taper(tester, '30 min');
    await taper(tester, 'Suivant');
    expect(suivantActif(tester), isFalse);
    await taper(tester, 'Enceinte ou allaitante');

    await defilerJusqua(tester, find.textContaining('pas de régime : on part'));
    expect(find.textContaining('pas de régime : on part'), findsOneWidget);
    expect(banc.controleur.objectif, Objectif.forme);
  });

  testWidgets('écran de résultat : cible, protéines, rythme et date', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Perdre du poids');
    await taper(tester, 'Suivant');
    await taper(tester, 'Homme');
    await saisir(tester, 'Âge', '30');
    await taper(tester, 'Suivant');
    await saisir(tester, 'Taille (cm)', '180');
    await saisir(tester, 'Poids (kg)', '80');
    await saisir(tester, 'Poids visé (kg, facultatif)', '72');
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
    await taper(tester, 'Aucun de ces cas');
    await taper(tester, 'Suivant');
    await taper(tester, 'Non');
    await taper(tester, 'Suivant');

    expect(find.text('Ton plan'), findsOneWidget);
    expect(find.text('Objectif : perdre du poids'), findsOneWidget);
    expect(find.text('2080'), findsOneWidget);
    expect(find.text('128 g'), findsOneWidget);
    expect(
      find.text('Maintien estimé : 2448 kcal par jour, hors sport.'),
      findsOneWidget,
    );
    expect(
      find.text('Rythme attendu : environ 0,3 kg de moins par semaine.'),
      findsOneWidget,
    );
    expect(
      find.text('Poids visé de 72,0 kg vers le 26 mars 2027.'),
      findsOneWidget,
    );
    // Rien n'est enregistré avant la connexion.
    expect(banc.depot.donnees, isEmpty);
  });

  testWidgets('écran de résultat sans poids visé : pas de date', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await remplirJusquaSante(tester);
    await taper(tester, 'Suivant');
    await taper(tester, 'Non');
    await taper(tester, 'Suivant');

    expect(find.text('Ton plan'), findsOneWidget);
    expect(find.textContaining('vers le'), findsNothing);
    expect(find.textContaining('Pas de date estimée'), findsNothing);
    expect(find.textContaining('kg de moins par semaine'), findsOneWidget);
  });

  testWidgets('muscle avec un IMC élevé : recomposition expliquée', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Prendre du muscle');
    await taper(tester, 'Suivant');
    await taper(tester, 'Homme');
    await saisir(tester, 'Âge', '30');
    await taper(tester, 'Suivant');
    await saisir(tester, 'Taille (cm)', '175');
    await saisir(tester, 'Poids (kg)', '120');
    await taper(tester, 'Suivant');

    await defilerJusqua(tester, find.textContaining('une recomposition'));
    expect(find.textContaining('une recomposition'), findsOneWidget);

    await taper(tester, 'Un peu actif');
    await taper(tester, 'Suivant');
    await taper(tester, 'Salle de sport');
    await taper(tester, 'Suivant');
    await taper(tester, 'Débutant');
    await taper(tester, 'Suivant');
    await taper(tester, '3');
    await taper(tester, '45 min');
    await taper(tester, 'Suivant');
    await taper(tester, 'Aucun de ces cas');
    await taper(tester, 'Suivant');
    await taper(tester, 'Non');
    await taper(tester, 'Suivant');

    expect(find.text('Objectif : recomposition'), findsOneWidget);
    expect(find.text('2660'), findsOneWidget);
    expect(find.text('153 g'), findsOneWidget);
  });

  testWidgets('type de vie : libellés hors sport', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Garder la forme');
    await taper(tester, 'Suivant');
    await taper(tester, 'Homme');
    await saisir(tester, 'Âge', '30');
    await taper(tester, 'Suivant');
    await saisir(tester, 'Taille (cm)', '180');
    await saisir(tester, 'Poids (kg)', '80');
    // Pas de poids visé pour « garder la forme ».
    expect(find.text('Poids visé (kg, facultatif)'), findsNothing);
    await taper(tester, 'Suivant');

    expect(
      find.text('Hors sport, ton quotidien ressemble plutôt à…'),
      findsOneWidget,
    );
    expect(find.textContaining('Ne compte pas tes séances'), findsOneWidget);
    expect(find.textContaining('sport tous les jours'), findsNothing);
    await defilerJusqua(tester, find.text('Très actif, hors sport'));
    expect(find.text('Très actif, hors sport'), findsOneWidget);
  });

  testWidgets("indique l'étape en cours sur le total", (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    expect(find.text('Étape 1 sur 11'), findsOneWidget);
    expect(find.byTooltip('Retour'), findsNothing);
    await taper(tester, 'Garder la forme');
    await taper(tester, 'Suivant');
    expect(find.text('Étape 2 sur 11'), findsOneWidget);
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
    expect(find.text('Ton plan'), findsOneWidget);
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
