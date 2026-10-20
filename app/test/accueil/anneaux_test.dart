import 'package:coach/accueil/anneaux.dart';
import 'package:coach/app.dart';
import 'package:coach/bienetre/hydratation.dart';
import 'package:coach/bienetre/suivi_meteo.dart';
import 'package:coach/journal/calculs.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/sante/modele.dart';
import 'package:coach/sante/suivi.dart';
import 'package:coach/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

final maintenant = DateTime(2026, 10, 9, 15); // 15 h : 62,5 % de la journée

const profil = Profil(
  objectif: Objectif.forme,
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

class Banc {
  Banc({List<PointSante>? points, double? temperature}) {
    suivi = Suivi(
      sante: FauxSante(points: points),
      horloge: () => heure,
    );
    meteo = FausseMeteo(temperature);
    if (temperature != null) bienetre.meteo['u1'] = true;
    meteoSuivi = SuiviMeteo(meteo: meteo, bienetre: bienetre, uid: 'u1');
  }

  final journal = FauxJournal();
  final bienetre = FauxBienEtre();
  late final Suivi suivi;
  late final FausseMeteo meteo;
  late final SuiviMeteo meteoSuivi;
  final onglets = <int>[];
  final widget = FauxWidget();

  /// L'heure vue par la carte, modifiable pendant le test.
  DateTime heure = maintenant;

  Reperes get reperes => calculerReperes(profil, maintenant: maintenant);

  /// Calories brûlées estimées sans montre à 15 h : le maintien au prorata
  /// de la journée, plus les activités saisies.
  double bruleesEstimees({double activites = 0}) =>
      reperes.maintien * 15 / 24 + activites;

  /// Laisse passer le délai d'envoi au widget de l'écran d'accueil.
  Future<void> attendreWidget(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 3));

  Future<void> monter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    if (suivi.sansDonnees || suivi.etat == EtatSuivi.inactif) {
      await suivi.charger(montre: true);
    }
    await tester.pumpWidget(
      CoachApp(
        accueil: Scaffold(
          body: SingleChildScrollView(
            child: CarteAujourdhui(
              uid: 'u1',
              profil: profil,
              suivi: suivi,
              journal: journal,
              bienetre: bienetre,
              meteoSuivi: meteoSuivi,
              horloge: () => heure,
              onOnglet: onglets.add,
              majWidget: widget,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<double> get progres =>
      (find.byType(Anneaux).evaluate().single.widget as Anneaux).progres;
}

void main() {
  test('bilan : mangé moins brûlé, avec le signe', () {
    expect(bilanTexte(0), '0');
    expect(bilanTexte(0.4), '0');
    expect(bilanTexte(120.2), '+120');
    expect(bilanTexte(-58.4), '−58');
    expect(bilanTexte(-1794), '−1794');
  });

  testWidgets('journée vide : quatre anneaux, objectifs affichés', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    final r = banc.reperes;
    final cibles = ciblesDuJour(r, kcalExercice: 0);

    for (final texte in [
      "Aujourd'hui",
      'Calories brûlées',
      'Calories mangées',
      'Protéines',
      'Hydratation',
    ]) {
      expect(find.text(texte), findsOneWidget, reason: texte);
    }
    expect(
      find.textContaining('/ ${r.maintien} kcal', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('/ ${cibles.kcal.round()} kcal', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '/ ${cibles.proteines.round()} g',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Estimé jusqu', findRichText: true),
      findsOneWidget,
    );
    // Sans montre, les calories brûlées suivent le maintien (le même chiffre
    // que l'objectif), plus le métabolisme de base × 1,2.
    final brule = banc.bruleesEstimees();
    expect(brule, isNot(closeTo(r.depenseBase * 1.2 * 15 / 24, 1)));
    expect(
      find.textContaining('${brule.round()}', findRichText: true),
      findsWidgets,
    );
    // Rien mangé : le bilan est le déficit complet, au centre des anneaux.
    expect(find.text(bilanTexte(-brule)), findsOneWidget);
    expect(find.text('bilan kcal'), findsOneWidget);
    expect(banc.progres[1], 0);
    expect(banc.progres[2], 0);
    expect(banc.progres[3], 0);
    expect(banc.progres[0], greaterThan(0)); // l'estimation avance avec l'heure
  });

  testWidgets('repas, activité et eau : les progrès suivent', (tester) async {
    final banc = Banc();
    banc.journal.repasParUid['u1'] = [
      Repas(
        date: DateTime(2026, 10, 9, 12),
        moment: Moment.dejeuner,
        nom: 'x',
        macros: const Macros(kcal: 1000, proteines: 80),
        source: SourceRepas.manuel,
      ),
    ];
    banc.journal.activitesParUid['u1'] = [
      Activite(
        date: DateTime(2026, 10, 9, 10),
        type: TypeActivite.course,
        minutes: 30,
        intensite: Intensite.moderee,
        kcal: 300,
      ),
    ];
    banc.bienetre.eauParUid['u1'] = [
      EntreeEau(date: DateTime(2026, 10, 9, 9), ml: 1000),
      EntreeEau(date: DateTime(2026, 10, 9, 11), ml: 500),
    ];
    await banc.monter(tester);

    final r = banc.reperes;
    final cibles = ciblesDuJour(r, kcalExercice: 300);
    final objectifEau = objectifEauMl(poidsKg: 80, minutesEffort: 30);

    expect(find.textContaining('1000', findRichText: true), findsWidgets);
    expect(banc.progres[1], closeTo(1000 / cibles.kcal, 1e-9));
    expect(banc.progres[2], closeTo(80 / cibles.proteines, 1e-9));
    expect(banc.progres[3], closeTo(1500 / objectifEau, 1e-9));
    expect(
      find.textContaining(
        '/ ${(objectifEau / 1000).toStringAsFixed(2).replaceAll('.', ',')} L',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1,50', findRichText: true), findsOneWidget);
    // Les 300 kcal de l'activité s'ajoutent aux calories brûlées.
    final base = banc.bruleesEstimees(activites: 300);
    expect(banc.progres[0], closeTo(base / r.maintien, 1e-9));
    expect(find.text(bilanTexte(1000 - base)), findsOneWidget);
  });

  testWidgets('montre : calories mesurées, activité déjà comptée ignorée', (
    tester,
  ) async {
    final banc = Banc(
      points: [
        PointSante(
          type: TypeMesure.kcalTotales,
          debut: DateTime(2026, 10, 9, 8),
          fin: DateTime(2026, 10, 9, 9),
          valeur: 1500,
        ),
        PointSante(
          type: TypeMesure.seance,
          debut: DateTime(2026, 10, 9, 9, 30),
          fin: DateTime(2026, 10, 9, 10),
          valeur: 250,
          libelle: 'course',
        ),
      ],
    );
    banc.journal.activitesParUid['u1'] = [
      // Même séance, saisie dans l'appli : ne compte pas deux fois.
      Activite(
        date: DateTime(2026, 10, 9, 10),
        type: TypeActivite.course,
        minutes: 30,
        intensite: Intensite.moderee,
        kcal: 300,
      ),
    ];
    await banc.monter(tester);

    expect(find.text('Mesuré par ta montre'), findsOneWidget);
    expect(banc.progres[0], closeTo(1500 / banc.reperes.maintien, 1e-9));
  });

  testWidgets('calories mesurées : la source et l\'heure sont indiquées', (
    tester,
  ) async {
    final banc = Banc(
      points: [
        PointSante(
          type: TypeMesure.kcalTotales,
          debut: DateTime(2026, 10, 9, 0),
          fin: DateTime(2026, 10, 9, 8, 12),
          valeur: 560,
          source: 'com.google.android.apps.fitness',
        ),
      ],
    );
    await banc.monter(tester);

    expect(find.text('Google Fit · mis à jour à 08:12'), findsOneWidget);
    expect(find.text('Mesuré par ta montre'), findsNothing);
  });

  testWidgets('une journée dépassée reste à 100 %', (tester) async {
    final banc = Banc();
    banc.bienetre.eauParUid['u1'] = [
      EntreeEau(date: DateTime(2026, 10, 9, 9), ml: 9000),
    ];
    await banc.monter(tester);
    expect(banc.progres[3], greaterThan(1));
    final anneaux = tester.widget<Anneaux>(find.byType(Anneaux));
    expect(anneaux.progres[3], greaterThan(1)); // la peinture, elle, borne à 1
  });

  testWidgets('chaleur : l\'objectif d\'eau monte et la météo est indiquée', (
    tester,
  ) async {
    final banc = Banc(temperature: 31);
    await banc.monter(tester);

    final attendu = objectifEauMl(poidsKg: 80, tempMaxC: 31);
    expect(attendu, objectifEauMl(poidsKg: 80) + 750);
    expect(
      find.textContaining(
        '/ ${(attendu / 1000).toStringAsFixed(2).replaceAll('.', ',')} L',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text("31 °C aujourd'hui"), findsOneWidget);
  });

  testWidgets('chaque ligne ouvre le bon onglet', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await tester.tap(find.text('Calories brûlées'));
    await tester.tap(find.text('Calories mangées'));
    await tester.tap(find.text('Protéines'));
    await tester.tap(find.text('Hydratation'));

    expect(banc.onglets, [2, 1, 1, 4]);
  });

  testWidgets("le widget de l'écran d'accueil reçoit les chiffres du jour", (
    tester,
  ) async {
    final banc = Banc();
    banc.bienetre.eauParUid['u1'] = [
      EntreeEau(date: DateTime(2026, 10, 9, 9), ml: 750),
    ];
    await banc.monter(tester);
    // Rien d'envoyé pendant la construction : le délai court d'abord.
    expect(banc.widget.envois, isEmpty);
    await banc.attendreWidget(tester);

    expect(banc.widget.envois, hasLength(1));
    final d = banc.widget.envois.single;
    expect(d.eauMl, 750);
    expect(d.objectifEauMl, objectifEauMl(poidsKg: 80));
    expect(d.mangees, 0);
    expect(d.objectifBrule, banc.reperes.maintien);
    expect(d.eauTexte, startsWith('0,75 / '));
    // Datés du jour affiché, pour le compte affiché ; chiffres lus par
    // TalkBack sur le widget.
    expect(banc.widget.jours.single, DateTime(2026, 10, 9));
    expect(banc.widget.uids.single, 'u1');
    expect(d.description, startsWith('Anneaux du jour. Calories brûlées : '));
    expect(d.description, contains('Calories mangées : 0 sur '));
    expect(d.description, isNot(contains('Eau')));

    // Pas de nouvel envoi tant que rien ne change...
    await tester.pump(const Duration(seconds: 2));
    expect(banc.widget.envois, hasLength(1));

    // ... puis un seul quand on boit.
    await banc.bienetre.ajouterEau(
      'u1',
      EntreeEau(date: DateTime(2026, 10, 9, 15), ml: 250),
    );
    await tester.pumpAndSettle();
    await banc.attendreWidget(tester);
    expect(banc.widget.envois, hasLength(2));
    expect(banc.widget.envois.last.eauMl, 1000);
  });

  testWidgets('une reconstruction sans changement n\'envoie rien au widget', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    await banc.attendreWidget(tester);
    expect(banc.widget.envois, hasLength(1));

    // Le Suivi et la météo notifient, l'Accueil se reconstruit : mêmes
    // chiffres, aucun envoi.
    banc.suivi.notifyListeners();
    banc.meteoSuivi.notifyListeners();
    await tester.pump();
    await banc.attendreWidget(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(banc.widget.envois, hasLength(1));

    // Deux minutes plus tard : l'estimation des calories brûlées a monté de
    // moins de 10 kcal, rien n'est renvoyé.
    banc.heure = maintenant.add(const Duration(minutes: 2));
    banc.suivi.notifyListeners();
    await tester.pump();
    await banc.attendreWidget(tester);
    expect(banc.widget.envois, hasLength(1));
  });

  testWidgets('un anneau qui change : un seul envoi, après le délai', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    await banc.attendreWidget(tester);
    expect(banc.widget.envois, hasLength(1));

    // Deux repas notés coup sur coup : l'anneau « mangé » bouge de plus de 1 %.
    for (final (heure, kcal) in [(12, 400.0), (13, 300.0)]) {
      await banc.journal.ajouterRepas(
        'u1',
        Repas(
          date: DateTime(2026, 10, 9, heure),
          moment: Moment.dejeuner,
          nom: 'x',
          macros: Macros(kcal: kcal, proteines: 20),
          source: SourceRepas.manuel,
        ),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 2));
    expect(banc.widget.envois, hasLength(1));

    await tester.pump(const Duration(seconds: 1));
    expect(banc.widget.envois, hasLength(2));
    expect(banc.widget.envois.last.mangees, 700);
    await tester.pump(const Duration(seconds: 10));
    expect(banc.widget.envois, hasLength(2));
  });

  testWidgets('appli mise en arrière-plan : envoi immédiat au widget', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    expect(banc.widget.envois, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(banc.widget.envois, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(banc.widget.envois, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('les calories brûlées du widget sont arrondies à 10 kcal', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    await banc.attendreWidget(tester);
    final envoyees = banc.widget.envois.single.brulees;
    expect(envoyees % 10, 0);
    expect(envoyees, closeTo(banc.bruleesEstimees(), 5));
  });

  testWidgets('minuit passé : la carte passe au nouveau jour', (tester) async {
    final banc = Banc();
    banc.bienetre.eauParUid['u1'] = [
      EntreeEau(date: DateTime(2026, 10, 9, 9), ml: 1500),
    ];
    await banc.monter(tester);
    expect(find.textContaining('1,50', findRichText: true), findsOneWidget);

    banc.heure = DateTime(2026, 10, 10, 0, 5);
    banc.suivi.notifyListeners();
    await tester.pumpAndSettle();

    // L'eau de la veille n'est plus comptée, et le widget reçoit des chiffres
    // datés du nouveau jour.
    expect(find.textContaining('1,50', findRichText: true), findsNothing);
    expect(find.textContaining('0,00', findRichText: true), findsOneWidget);
    await banc.attendreWidget(tester);
    expect(banc.widget.jours.last, DateTime(2026, 10, 10));
    expect(banc.widget.envois.last.eauMl, 0);
  });

  testWidgets('thème clair : chiffres foncés, barres aux couleurs vives', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    Color? couleurDe(String libelle) {
      final ligne = find.ancestor(
        of: find.text(libelle),
        matching: find.byType(InkWell),
      );
      final riche = tester.widget<RichText>(
        find.descendant(of: ligne, matching: find.byType(RichText)).last,
      );
      // Premier morceau de texte : la valeur, avant « / objectif ».
      Color? couleur;
      riche.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) {
          couleur = span.style?.color;
          return false;
        }
        return true;
      });
      return couleur;
    }

    expect(couleurDe('Calories mangées'), PaletteCoach.clair.texteOrange);
    expect(couleurDe('Protéines'), PaletteCoach.clair.texteVert);
    expect(couleurDe('Hydratation'), PaletteCoach.clair.texteBleu);
    expect(couleurDe('Calories brûlées'), PaletteCoach.clair.texteVert);
  });
}
