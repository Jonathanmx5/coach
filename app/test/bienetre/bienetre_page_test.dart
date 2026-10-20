import 'package:coach/entrainement/modele.dart';
import 'package:coach/bienetre/complements.dart';
import 'package:coach/bienetre/series.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:coach/app.dart';
import 'package:coach/bienetre/bienetre_page.dart';
import 'package:coach/bienetre/suivi_meteo.dart';
import 'package:coach/compte/donnees_compte.dart';
import 'package:coach/bienetre/hydratation.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);
const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

final profil = Profil(
  objectif: Objectif.forme,
  sexe: Sexe.femme,
  anneeNaissance: 1996,
  tailleCm: 170,
  poidsKg: 60,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: const {TypeEntrainement.maison},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 30,
);

class Banc {
  final bienetre = FauxBienEtre();
  final journal = FauxJournal();
  final meteo = FausseMeteo(31);
  late final meteoSuivi = SuiviMeteo(
    meteo: meteo,
    bienetre: bienetre,
    uid: 'u1',
  );
  final rappels = FauxRappels();
  final entrainement = FauxEntrainement();
  final consentements = FauxConsentements({Consentement.meteo});

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      CoachApp(
        accueil: BienEtrePage(
          utilisateur: lea,
          enregistre: ProfilEnregistre(
            profil: profil,
            reperes: calculerReperes(profil, maintenant: maintenant),
          ),
          bienetre: bienetre,
          journal: journal,
          meteoSuivi: meteoSuivi,
          rappels: rappels,
          entrainement: entrainement,
          consentements: consentements,
          horloge: () => maintenant,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  group('objectifEauMl', () {
    test('selon le poids, arrondi à 50 ml', () {
      expect(objectifEauMl(poidsKg: 60), 2000);
      expect(objectifEauMl(poidsKg: 71), 2350);
    });
    test('effort et chaleur', () {
      expect(objectifEauMl(poidsKg: 60, minutesEffort: 30), 2300);
      expect(objectifEauMl(poidsKg: 60, tempMaxC: 26), 2400);
      expect(objectifEauMl(poidsKg: 60, tempMaxC: 31), 2750);
      expect(objectifEauMl(poidsKg: 60, tempMaxC: 20), 2000);
    });
    test('bornes 1,5 L et 4,5 L', () {
      expect(objectifEauMl(poidsKg: 35), 1500);
      expect(
        objectifEauMl(poidsKg: 120, minutesEffort: 120, tempMaxC: 35),
        4500,
      );
    });
    test('total', () {
      expect(
        totalEauMl([
          EntreeEau(date: maintenant, ml: 250),
          EntreeEau(date: maintenant, ml: 500),
        ]),
        750,
      );
    });
  });

  testWidgets('hydratation : objectif du profil, ajout et annulation', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    expect(find.text('0,00 L sur 2,00 L'), findsOneWidget);

    await taper(tester, '+ 250 ml');
    await taper(tester, '+ 500 ml');
    expect(find.text('0,75 L sur 2,00 L'), findsOneWidget);
    expect(banc.bienetre.eauDe('u1'), hasLength(2));

    await taper(tester, 'Annuler le dernier');
    expect(find.text('0,25 L sur 2,00 L'), findsOneWidget);
  });

  testWidgets('eau refusée par les règles : message affiché', (tester) async {
    final banc = Banc();
    banc.bienetre.refusEau = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await banc.monter(tester);

    await taper(tester, '+ 250 ml');
    expect(find.text('Eau non enregistrée.'), findsOneWidget);
    expect(banc.bienetre.eauDe('u1'), isEmpty);
  });

  testWidgets('compléments et météo : une seule écoute chacun', (tester) async {
    final banc = Banc();
    banc.bienetre.complementsParUid['u1'] = const [
      Complement(id: 'x', nom: 'Magnésium', minutes: 1290),
    ];
    await banc.monter(tester);

    expect(banc.bienetre.fluxComplements, 1);
    // Celle de SuiviMeteo, partagée avec l'Accueil.
    expect(banc.bienetre.fluxMeteo, 1);
    expect(banc.rappels.planifications.last.single.nom, 'Magnésium');
    await defilerJusqua(tester, find.text('Rappel à 21h30'));
    expect(find.text('Rappel à 21h30'), findsOneWidget);
  });

  testWidgets('hydratation : l\'effort du jour augmente l\'objectif', (
    tester,
  ) async {
    final banc = Banc();
    banc.journal.activitesParUid['u1'] = [
      Activite(
        date: maintenant,
        type: TypeActivite.course,
        minutes: 30,
        intensite: Intensite.moderee,
        kcal: 300,
      ),
    ];
    await banc.monter(tester);
    expect(find.text('0,00 L sur 2,30 L'), findsOneWidget);
    expect(find.textContaining('30 min d\'effort'), findsOneWidget);
  });

  testWidgets('météo : activée à la demande, objectif relevé', (tester) async {
    final banc = Banc();
    await banc.monter(tester);
    expect(banc.meteo.appels, 0);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(banc.bienetre.meteo['u1'], isTrue);
    expect(banc.meteo.appels, 1);
    expect(find.text('0,00 L sur 2,75 L'), findsOneWidget);
    expect(find.textContaining('31 °C'), findsOneWidget);
  });

  testWidgets('météo refusée : objectif inchangé', (tester) async {
    final banc = Banc();
    banc.meteo.temp = null;
    banc.bienetre.meteo['u1'] = true;
    await banc.monter(tester);
    expect(find.text('0,00 L sur 2,00 L'), findsOneWidget);
  });

  testWidgets('compléments : ajout, rappel planifié, pris, désactivation', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Ajouter un complément');
    await tester.enterText(find.byType(TextField), 'Vitamine D');
    await tester.pump();
    await taper(tester, 'Enregistrer');

    final c = banc.bienetre.complementsDe('u1').single;
    expect(c.nom, 'Vitamine D');
    expect(c.minutes, 480);
    expect(banc.rappels.autorisations, 1);
    expect(banc.rappels.planifications.last.single.nom, 'Vitamine D');
    await defilerJusqua(tester, find.text('Rappel à 08h00'));
    expect(find.text('Rappel à 08h00'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(banc.bienetre.prisesDe('u1', maintenant), {c.id});

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Désactiver le rappel'));
    await tester.pumpAndSettle();
    expect(banc.bienetre.complementsDe('u1').single.actif, isFalse);
    expect(banc.rappels.planifications.last.single.actif, isFalse);
    expect(find.text('Rappel désactivé'), findsOneWidget);
  });

  testWidgets('compléments : supprimer retire le rappel', (tester) async {
    final banc = Banc();
    banc.bienetre.complementsParUid['u1'] = const [
      Complement(id: 'x', nom: 'Magnésium', minutes: 1290),
    ];
    await banc.monter(tester);
    await defilerJusqua(tester, find.text('Rappel à 21h30'));
    expect(find.text('Rappel à 21h30'), findsOneWidget);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(banc.bienetre.complementsDe('u1'), isEmpty);
    expect(banc.rappels.planifications.last, isEmpty);
  });

  testWidgets('séries : journal, séance et eau comptés', (tester) async {
    final banc = Banc();
    Repas repas(int jour) => Repas(
      date: DateTime(2026, 10, jour, 12),
      moment: Moment.dejeuner,
      nom: 'x',
      macros: const Macros(kcal: 500),
      source: SourceRepas.manuel,
    );
    banc.journal.repasParUid['u1'] = [repas(7), repas(8), repas(9)];
    banc.entrainement.seancesParUid['u1'] = [
      SeanceFaite(
        date: DateTime(2026, 10, 8, 18),
        lieu: Lieu.maison,
        minutes: 30,
      ),
    ];
    banc.bienetre.eauParUid['u1'] = [
      EntreeEau(date: DateTime(2026, 10, 8, 10), ml: 2000),
      EntreeEau(date: DateTime(2026, 10, 9, 10), ml: 2000),
    ];
    await banc.monter(tester);

    await defilerJusqua(tester, find.text('Tes séries'));
    expect(find.text('3 jours'), findsOneWidget); // journal
    expect(find.text('1 jour'), findsOneWidget); // séance d'hier
    expect(find.text('2 jours'), findsOneWidget); // eau
    // Séries courtes : une seule lecture d'une semaine chacune.
    final semaine = DateTime(2026, 10, 2);
    expect(banc.journal.debutsRepas, [semaine]);
    expect(banc.entrainement.depuisDemandes, [semaine]);
    expect(banc.bienetre.debutsEau, contains(semaine));
    expect(banc.bienetre.debutsEau, isNot(contains(DateTime(2026, 9, 9))));
  });

  testWidgets(
    'séries sur 60 jours : même résultat qu\'avant, lues par paliers',
    (tester) async {
      final banc = Banc();
      DateTime jour(int avant, int heure) =>
          DateTime(2026, 10, 9 - avant, heure);
      // Journal tenu 45 jours d'affilée (deux repas par jour), puis un trou
      // et encore des repas plus anciens ; eau atteinte 20 jours d'affilée.
      final repas = [
        for (var j = 0; j < 60; j++)
          if (j != 45)
            for (final h in [8, 19])
              Repas(
                date: jour(j, h),
                moment: Moment.dejeuner,
                nom: 'x',
                macros: const Macros(kcal: 500),
                source: SourceRepas.manuel,
              ),
      ];
      final eau = [
        for (var j = 0; j < 60; j++)
          if (j != 20) EntreeEau(date: jour(j, 10), ml: 2000),
      ];
      banc.journal.repasParUid['u1'] = repas;
      banc.bienetre.eauParUid['u1'] = eau;
      await banc.monter(tester);

      // Le calcul d'avant : toute la fenêtre de 60 jours d'un coup.
      final journalAvant = serieEnCours(
        joursDe(repas.map((r) => r.date)),
        maintenant,
      );
      final eauAvant = serieEnCours(joursEauAtteinte(eau, 2000), maintenant);
      expect(journalAvant, 45);
      expect(eauAvant, 20);
      await defilerJusqua(tester, find.text('Tes séries'));
      expect(find.text('45 jours'), findsOneWidget);
      expect(find.text('20 jours'), findsOneWidget);

      // Paliers : 7 jours, puis 30, puis 90 tant que la série touche le
      // début de la fenêtre.
      expect(banc.journal.debutsRepas, [
        DateTime(2026, 10, 2),
        DateTime(2026, 9, 9),
        DateTime(2026, 7, 11),
      ]);
      expect(banc.bienetre.debutsEau, isNot(contains(DateTime(2026, 7, 11))));
      expect(banc.bienetre.debutsEau, contains(DateTime(2026, 9, 9)));
    },
  );

  testWidgets('séries : les jours de repos ne coupent pas les séances', (
    tester,
  ) async {
    final banc = Banc();
    // Programme de 3 jours (lundi, mercredi, vendredi) : 2 semaines tenues.
    banc.entrainement.seancesParUid['u1'] = [
      for (final j in [28, 30, 2, 5, 7, 9])
        SeanceFaite(
          date: DateTime(2026, j > 20 ? 9 : 10, j, 18),
          lieu: Lieu.maison,
          minutes: 30,
        ),
    ];
    await banc.monter(tester);
    await defilerJusqua(tester, find.text('Tes séries'));
    expect(find.text('6 jours'), findsOneWidget);
  });

  testWidgets('météo : accord demandé la première fois', (tester) async {
    final banc = Banc();
    await banc.consentements.definir('u1', Consentement.meteo, false);
    await banc.monter(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Utiliser ta position ?'), findsOneWidget);
    await taper(tester, 'Refuser');
    expect(banc.bienetre.meteo['u1'], isNot(true));
    expect(banc.meteo.appels, 0);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await taper(tester, 'Accepter');
    expect(banc.bienetre.meteo['u1'], isTrue);
    expect(banc.consentements.accordesMaintenant, {Consentement.meteo});
  });
}
