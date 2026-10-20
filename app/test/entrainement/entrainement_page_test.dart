import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/entrainement/entrainement_page.dart';
import 'package:coach/entrainement/modele.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/sante/suivi.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:coach/entrainement/entrainement_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../donnees_sante.dart';
import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);
const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

Profil profilDe(Set<TypeEntrainement> types) => Profil(
  objectif: Objectif.forme,
  sexe: Sexe.femme,
  anneeNaissance: 1996,
  tailleCm: 170,
  poidsKg: 60,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: types,
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 30,
);

final refus = FirebaseException(
  plugin: 'cloud_firestore',
  code: 'permission-denied',
);

class Banc {
  Banc(Set<TypeEntrainement> types, {bool montre = false, DateTime? horloge})
    : profil = profilDe(types),
      sante = FauxSante(points: montre ? semaineType() : []),
      horloge = horloge ?? maintenant;
  final Profil profil;
  final FauxSante sante;
  final DateTime horloge;
  late final suivi = Suivi(sante: sante, horloge: () => horloge);
  final entrainement = FauxEntrainement();
  final journal = FauxJournal();
  final voix = FausseVoix();

  Future<void> monter(WidgetTester tester) async {
    if (sante.points.isNotEmpty) await suivi.charger(montre: true);
    await tester.pumpWidget(
      CoachApp(
        accueil: EntrainementPage(
          utilisateur: lea,
          enregistre: ProfilEnregistre(
            profil: profil,
            reperes: calculerReperes(profil, maintenant: maintenant),
          ),
          entrainement: entrainement,
          journal: journal,
          voix: voix,
          suivi: suivi,
          horloge: () => horloge,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  test('lieux du profil et séances du programme', () {
    expect(
      lieuxDuProfil(
        profilDe({TypeEntrainement.salle, TypeEntrainement.course}),
      ),
      [Lieu.salle, Lieu.course],
    );
    expect(lieuxDuProfil(profilDe({})), [Lieu.maison]);
    // Sans impact (douleurs, grossesse…), la course devient de la marche,
    // sans doublon si la marche est déjà choisie.
    final douleurs = profilDe({TypeEntrainement.salle, TypeEntrainement.course})
        .copyWith(precautions: {Precaution.douleursArticulaires});
    expect(lieuxDuProfil(douleurs), [Lieu.salle, Lieu.marche]);
    expect(
      lieuxDuProfil(
        douleurs.copyWith(
          typesEntrainement: {TypeEntrainement.course, TypeEntrainement.marche},
        ),
      ),
      [Lieu.marche],
    );
    expect(lieuxDuProgramme(Lieu.maison), {Lieu.maison, Lieu.salle});
    expect(lieuxDuProgramme(Lieu.salle), {Lieu.maison, Lieu.salle});
    expect(lieuxDuProgramme(Lieu.course), {Lieu.course});
    expect(lieuxDuProgramme(Lieu.marche), {Lieu.marche});
  });

  test('dépôt : seances(depuis:) ne lit que la fenêtre', () async {
    final depot = FirestoreEntrainementRepository(FakeFirebaseFirestore());
    for (final jours in [90, 8, 3, 0]) {
      await depot.ajouterSeance(
        'u1',
        SeanceFaite(
          date: maintenant.subtract(Duration(days: jours)),
          lieu: Lieu.maison,
          minutes: 30,
        ),
      );
    }
    final lundi = DateTime(2026, 10, 5);
    final semaine = await depot.seances('u1', depuis: lundi).first;
    expect(semaine.map((s) => s.date.day), [6, 9]);
    expect((await depot.seances('u1').first), hasLength(4));
  });

  test('dépôt : nombre de séances du programme, sans les lire', () async {
    final depot = FirestoreEntrainementRepository(FakeFirebaseFirestore());
    for (final lieu in [Lieu.maison, Lieu.salle, Lieu.course, Lieu.maison]) {
      await depot.ajouterSeance(
        'u1',
        SeanceFaite(date: maintenant, lieu: lieu, minutes: 30),
      );
    }
    expect(await depot.nombreSeances('u1', {Lieu.maison, Lieu.salle}), 3);
    expect(await depot.nombreSeances('u1', {Lieu.course}), 1);
    expect(await depot.nombreSeances('u1', {Lieu.marche}), 0);
    expect(await depot.nombreSeances('u1', {}), 0);
  });

  test('dépôt : réglages et séances', () async {
    final depot = FirestoreEntrainementRepository(FakeFirebaseFirestore());
    expect((await depot.reglages('u1').first).materiel, isEmpty);
    await depot.enregistrerReglages(
      'u1',
      const Reglages(materiel: {Materiel.halteres, Materiel.banc}),
    );
    expect((await depot.reglages('u1').first).materiel, {
      Materiel.halteres,
      Materiel.banc,
    });
    await depot.ajouterSeance(
      'u1',
      SeanceFaite(date: maintenant, lieu: Lieu.course, minutes: 25),
    );
    final l = await depot.seances('u1').first;
    expect(l.single.lieu, Lieu.course);
    expect(l.single.minutes, 25);
  });

  testWidgets('lectures bornées : la semaine en cours et un compte', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.marche});
    // Trois marches il y a des mois : elles comptent dans la progression,
    // sans être lues.
    banc.entrainement.seancesParUid['u1'] = [
      for (final j in [100, 90, 80])
        SeanceFaite(
          date: maintenant.subtract(Duration(days: j)),
          lieu: Lieu.marche,
          minutes: 20,
        ),
    ];
    await banc.monter(tester);

    expect(banc.entrainement.depuisDemandes, [DateTime(2026, 10, 5)]);
    expect(banc.entrainement.comptes, [
      {Lieu.marche},
    ]);
    expect(find.text('Marche active · 25 min'), findsOneWidget);
    expect(find.text('Cette semaine : 0 séance(s) sur 3'), findsOneWidget);
  });

  testWidgets('maison : matériel enregistré, séance proposée', (tester) async {
    final banc = Banc({TypeEntrainement.maison});
    await banc.monter(tester);
    expect(
      find.text('Jours prévus : lundi, mercredi, vendredi'),
      findsOneWidget,
    );

    expect(find.text('Séance à la maison'), findsOneWidget);
    expect(find.text('Commencer la séance'), findsOneWidget);
    expect(find.text('Cette semaine : 0 séance(s) sur 3'), findsOneWidget);

    await taper(tester, 'Haltères');
    expect(banc.entrainement.reglagesDe('u1').materiel, {Materiel.halteres});
  });

  testWidgets('plusieurs lieux : on bascule de la maison à la marche', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.maison, TypeEntrainement.marche});
    await banc.monter(tester);
    expect(find.text('Mon matériel'), findsOneWidget);

    await taper(tester, 'Marche');
    expect(find.text('Marche active · 20 min'), findsOneWidget);
    expect(find.text('Mon matériel'), findsNothing);
  });

  testWidgets('séance guidée de marche : minuteur, voix, enregistrement', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.marche});
    await banc.monter(tester);

    await taper(tester, 'Commencer la séance');
    expect(find.text('Étape 1 sur 3'), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);
    expect(banc.voix.dits.first, contains('Mise en route'));

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('02:50'), findsOneWidget);

    await taper(tester, 'Pause');
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('02:50'), findsOneWidget);
    await taper(tester, 'Reprendre');

    await taper(tester, 'Passer');
    expect(find.text('Étape 2 sur 3'), findsOneWidget);
    await taper(tester, 'Passer');
    await tester.pump(const Duration(seconds: 181));
    await tester.pumpAndSettle();

    expect(find.text('Séance terminée, bravo !'), findsOneWidget);
    await taper(tester, 'Terminer');

    final faites = banc.entrainement.seancesDe('u1');
    expect(faites.single.lieu, Lieu.marche);
    expect(faites.single.minutes, 20);
    final activite = banc.journal.activitesDe('u1').single;
    expect(activite.type, TypeActivite.marche);
    expect(activite.kcal, greaterThan(0));
    expect(find.text('Marche active · 25 min'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('Cette semaine : 1 séance(s) sur 3'), findsOneWidget);
    // Une seule séance par jour : la carte annonce la suivante.
    expect(find.text('Séance du jour faite, bravo !'), findsOneWidget);
    expect(
      find.text('Prochaine séance : lundi. D\'ici là, repos ou mobilité.'),
      findsOneWidget,
    );
    expect(find.text('Commencer la séance'), findsNothing);
  });

  testWidgets('séance déjà faite aujourd\'hui : pas de seconde séance', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.maison});
    banc.entrainement.seancesParUid['u1'] = [
      SeanceFaite(
        date: DateTime(2026, 10, 9, 7),
        lieu: Lieu.maison,
        minutes: 30,
      ),
    ];
    await banc.monter(tester);

    expect(find.text('Séance du jour faite, bravo !'), findsOneWidget);
    expect(find.text('Commencer la séance'), findsNothing);
    expect(find.text('Commencer quand même'), findsNothing);
  });

  testWidgets('séance enregistrée pendant la séance guidée : refusée', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.marche});
    await banc.monter(tester);

    await taper(tester, 'Commencer la séance');
    // Une autre séance du jour arrive pendant ce temps (autre appareil).
    await banc.entrainement.ajouterSeance(
      'u1',
      SeanceFaite(date: maintenant, lieu: Lieu.maison, minutes: 30),
    );
    await taper(tester, 'Passer');
    await taper(tester, 'Passer');
    await taper(tester, 'Passer');
    await taper(tester, 'Terminer');

    expect(
      find.text(
        "Une séance par jour : celle d'aujourd'hui est déjà faite. "
        'Place à la récupération.',
      ),
      findsOneWidget,
    );
    expect(banc.entrainement.seancesDe('u1'), hasLength(1));
    expect(banc.journal.activitesDe('u1'), isEmpty);
  });

  testWidgets('jour de repos : message, séance possible quand même', (
    tester,
  ) async {
    // Jeudi : lundi et mercredi faits, prochaine séance vendredi.
    final banc = Banc({
      TypeEntrainement.marche,
    }, horloge: DateTime(2026, 10, 8, 18));
    // Écran haut : la liste tient sans défiler (le faux flux d'activités,
    // contrairement à celui de Firestore, ne se relit pas).
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    banc.entrainement.seancesParUid['u1'] = [
      for (final j in [5, 7])
        SeanceFaite(
          date: DateTime(2026, 10, j, 18),
          lieu: Lieu.marche,
          minutes: 20,
        ),
    ];
    await banc.monter(tester);

    expect(
      find.text('Aujourd\'hui : repos. Prochaine séance : vendredi.'),
      findsOneWidget,
    );
    expect(find.text('Commencer la séance'), findsNothing);
    await taper(tester, 'Commencer quand même');
    expect(find.text('Étape 1 sur 3'), findsOneWidget);
  });

  testWidgets('séance manquée : rattrapée le lendemain', (tester) async {
    // Jeudi : seul lundi est fait, la séance de mercredi est à rattraper.
    final banc = Banc({
      TypeEntrainement.marche,
    }, horloge: DateTime(2026, 10, 8, 18));
    banc.entrainement.seancesParUid['u1'] = [
      SeanceFaite(
        date: DateTime(2026, 10, 5, 18),
        lieu: Lieu.marche,
        minutes: 20,
      ),
    ];
    await banc.monter(tester);

    expect(find.text('Commencer la séance'), findsOneWidget);
    expect(find.textContaining('repos'), findsNothing);
  });

  testWidgets('séance refusée par les règles : message affiché', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.marche});
    banc.entrainement.refusSeance = refus;
    await banc.monter(tester);

    await taper(tester, 'Commencer la séance');
    await taper(tester, 'Passer');
    await taper(tester, 'Passer');
    await taper(tester, 'Passer');
    await taper(tester, 'Terminer');

    expect(find.text('Séance non enregistrée.'), findsOneWidget);
    expect(banc.entrainement.seancesDe('u1'), isEmpty);
  });

  testWidgets('séance en répétitions : « Fait » passe à la suite', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.maison});
    await banc.monter(tester);

    await taper(tester, 'Commencer la séance');
    await taper(tester, 'Passer'); // échauffement
    expect(find.text('Fait'), findsOneWidget);
    await taper(tester, 'Fait');
    expect(find.text('Repos'), findsWidgets);
  });

  testWidgets('voix coupée : plus d\'annonce', (tester) async {
    final banc = Banc({TypeEntrainement.marche});
    await banc.monter(tester);
    await taper(tester, 'Commencer la séance');
    final avant = banc.voix.dits.length;

    await tester.tap(find.byTooltip('Couper la voix'));
    await tester.pump();
    await taper(tester, 'Passer');
    expect(banc.voix.dits.length, avant);
  });

  testWidgets('récupération : sans donnée, le ressenti donne un conseil', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.maison});
    await banc.monter(tester);
    expect(
      find.textContaining('Pas encore de donnée de sommeil'),
      findsOneWidget,
    );

    await taper(tester, 'Fatigué');
    expect(find.textContaining('Corps fatigué'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(banc.entrainement.ressentis.values, [1]);
    // Récupération faible : la routine douce passe en tête.
    await defilerJusqua(tester, find.text('Conseillé maintenant'));
    expect(find.text('Conseillé maintenant'), findsOneWidget);
  });

  testWidgets('récupération : nuit de 7 h de la montre = feu vert', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.maison}, montre: true);
    await banc.monter(tester);
    expect(find.text('100'), findsOneWidget);
    expect(find.textContaining('Feu vert'), findsOneWidget);
  });

  testWidgets('mobilité : une routine se lance sans enregistrer de séance', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.maison});
    await banc.monter(tester);

    await taper(tester, 'Réveil articulaire (5 min)');
    expect(find.text('Cercles de nuque'), findsOneWidget);
    expect(banc.entrainement.seancesDe('u1'), isEmpty);
    expect(banc.journal.activitesDe('u1'), isEmpty);
  });

  testWidgets(
    'ajouter une activité sportive : calories estimées, enregistrée',
    (tester) async {
      final banc = Banc({TypeEntrainement.maison});
      await banc.monter(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await taper(tester, 'Course à pied');
      await saisir(tester, 'Durée (min)', '30');
      // (9,8 MET × 1,0 (modérée) − 1) × 60 kg × 0,5 h = 264 kcal nettes.
      expect(find.text('≈ 264 kcal brûlées'), findsOneWidget);
      await taper(tester, 'Intense');
      expect(find.text('≈ 323 kcal brûlées'), findsOneWidget);
      await taper(tester, 'Enregistrer');

      final a = banc.journal.activitesDe('u1').single;
      expect(a.type, TypeActivite.course);
      expect(a.minutes, 30);
      expect(a.intensite, Intensite.intense);
      expect(a.kcal, closeTo(322.8, 0.01));
      // Datée du début de l'effort : maintenant moins sa durée.
      expect(a.date, maintenant.subtract(const Duration(minutes: 30)));
    },
  );

  testWidgets('activité refusée par les règles : message affiché', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.maison});
    banc.journal.refusActivite = refus;
    await banc.monter(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await taper(tester, 'Course à pied');
    await saisir(tester, 'Durée (min)', '30');
    await taper(tester, 'Enregistrer');

    expect(find.text('Activité non enregistrée.'), findsOneWidget);
    expect(banc.journal.activitesDe('u1'), isEmpty);
  });

  testWidgets('activité sans durée valide : refusée', (tester) async {
    final banc = Banc({TypeEntrainement.maison});
    await banc.monter(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await taper(tester, 'Enregistrer');

    expect(find.text('Entre une durée en minutes.'), findsOneWidget);
    expect(banc.journal.activitesDe('u1'), isEmpty);
  });

  testWidgets('les activités du jour sont listées et supprimables', (
    tester,
  ) async {
    final banc = Banc({TypeEntrainement.maison});
    banc.journal.activitesParUid['u1'] = [
      Activite(
        id: 'a1',
        date: maintenant,
        type: TypeActivite.velo,
        minutes: 45,
        intensite: Intensite.moderee,
        kcal: 337,
      ),
      Activite(
        id: 'a0',
        date: maintenant.subtract(const Duration(days: 1)),
        type: TypeActivite.natation,
        minutes: 20,
        intensite: Intensite.legere,
        kcal: 100,
      ),
    ];
    await banc.monter(tester);

    await defilerJusqua(tester, find.text("Activités d'aujourd'hui"));
    expect(find.text('45 min · 337 kcal'), findsOneWidget);
    expect(find.text('20 min · 100 kcal'), findsNothing); // hier

    await tester.tap(find.byTooltip("Supprimer l'activité"));
    await tester.pumpAndSettle();
    expect(banc.journal.activitesDe('u1').map((a) => a.id), ['a0']);
    expect(find.text('Aucune activité enregistrée.'), findsOneWidget);
  });
}
