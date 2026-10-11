import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/journal/catalogue.dart';
import 'package:coach/journal/journal_page.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/sante/modele.dart';
import 'package:coach/sante/sante_service.dart';
import 'package:coach/sante/suivi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);
const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

// Perte simple : base 1780, cible 2080, 128 g de protéines, 80 kg.
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
  problemeSante: false,
);

class Banc {
  Banc({this.catalogue, this.code, Suivi? suivi})
    : suivi =
          suivi ??
          Suivi(
            sante: FauxSante(dispo: DispoSante.indisponible),
            horloge: () => maintenant,
          );

  final journal = FauxJournal();
  final FauxCatalogue? catalogue;
  final String? code;
  final Suivi suivi;

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      CoachApp(
        accueil: JournalPage(
          utilisateur: lea,
          enregistre: ProfilEnregistre(
            profil: profil,
            reperes: calculerReperes(profil, maintenant: maintenant),
          ),
          journal: journal,
          catalogue: catalogue ?? FauxCatalogue(),
          suivi: suivi,
          horloge: () => maintenant,
          lecteurCode: (_) async => code,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> repas(double kcal, {double p = 0}) => journal.ajouterRepas(
    'u1',
    Repas(
      date: DateTime(2026, 10, 9, 12),
      moment: Moment.dejeuner,
      nom: 'Déj',
      macros: Macros(kcal: kcal, proteines: p),
      source: SourceRepas.manuel,
    ),
  );

  Future<void> activite(double kcal) => journal.ajouterActivite(
    'u1',
    Activite(
      date: DateTime(2026, 10, 9, 18),
      type: TypeActivite.velo,
      minutes: 60,
      intensite: Intensite.moderee,
      kcal: kcal,
    ),
  );
}

String texteDe(WidgetTester tester, String cle) =>
    tester.widget<Text>(find.byKey(ValueKey(cle))).data!;

Future<void> menu(WidgetTester tester, String entree) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await taper(tester, entree);
}

const produit = ProduitOff(
  nom: 'Muesli',
  pour100g: Macros(kcal: 400, proteines: 10, glucides: 60, lipides: 12),
);

void main() {
  testWidgets('bilan : mangé, dépensé et solde', (tester) async {
    final banc = Banc();
    await banc.repas(600, p: 30);
    await banc.activite(600);
    await banc.monter(tester);

    expect(texteDe(tester, 'valeur-mange'), '600 kcal');
    expect(texteDe(tester, 'valeur-depense'), '2736 kcal');
    expect(texteDe(tester, 'valeur-solde'), '−2136 kcal');
    expect(find.text('Déficit'), findsOneWidget);
  });

  testWidgets("jour d'effort : objectif relevé et jour intense", (
    tester,
  ) async {
    final banc = Banc();
    await banc.activite(1000);
    await banc.monter(tester);

    expect(find.text('Jour intense'), findsOneWidget);
    expect(find.text("Objectif du jour : 2780 kcal"), findsOneWidget);
  });

  testWidgets('jour de repos : objectif du profil', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    expect(find.text('Jour de repos'), findsOneWidget);
    expect(find.text('Objectif du jour : 2080 kcal'), findsOneWidget);
  });

  testWidgets('avec la montre : calories totales de la montre', (tester) async {
    final suivi = Suivi(
      sante: FauxSante(
        points: [
          PointSante(
            type: TypeMesure.kcalTotales,
            debut: DateTime(2026, 10, 9, 8),
            fin: DateTime(2026, 10, 9, 19),
            valeur: 2500,
          ),
        ],
      ),
      horloge: () => maintenant,
    );
    await tester.runAsync(() => suivi.charger(montre: true));
    final banc = Banc(suivi: suivi);
    await banc.monter(tester);

    expect(texteDe(tester, 'valeur-depense'), '2500 kcal');
  });

  testWidgets('ajouter un repas à la main', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await menu(tester, 'Ajouter un repas');
    await saisir(tester, 'Nom du repas', 'Pâtes');
    await saisir(tester, 'Calories (kcal)', '650,5');
    await saisir(tester, 'Protéines (g)', '24');
    await taper(tester, 'Enregistrer');

    final r = banc.journal.repasDe('u1').single;
    expect(r.nom, 'Pâtes');
    expect(r.macros.kcal, 650.5);
    expect(r.macros.proteines, 24);
    expect(r.source, SourceRepas.manuel);
    expect(texteDe(tester, 'valeur-mange'), '651 kcal');
  });

  testWidgets('repas sans calories : refusé', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await menu(tester, 'Ajouter un repas');
    await taper(tester, 'Enregistrer');

    expect(find.text('Entre un nombre valide.'), findsOneWidget);
    expect(banc.journal.repasDe('u1'), isEmpty);
  });

  testWidgets('scanner un produit : macros selon la quantité', (tester) async {
    final catalogue = FauxCatalogue(produit: produit);
    final banc = Banc(catalogue: catalogue, code: '3017620422003');
    await banc.monter(tester);

    await menu(tester, 'Scanner un produit');
    expect(find.text('Muesli'), findsOneWidget);
    await saisir(tester, 'Quantité (g)', '200');
    await taper(tester, 'Enregistrer');

    expect(catalogue.recherches, ['3017620422003']);
    final r = banc.journal.repasDe('u1').single;
    expect(r.nom, 'Muesli');
    expect(r.macros.kcal, 800);
    expect(r.macros.glucides, 120);
    expect(r.source, SourceRepas.codeBarres);
  });

  testWidgets('produit introuvable : message', (tester) async {
    final banc = Banc(catalogue: FauxCatalogue(), code: '0000');
    await banc.monter(tester);

    await menu(tester, 'Scanner un produit');

    expect(find.textContaining('Produit introuvable'), findsOneWidget);
    expect(banc.journal.repasDe('u1'), isEmpty);
  });

  testWidgets('hors-ligne : message clair', (tester) async {
    final banc = Banc(catalogue: FauxCatalogue(erreur: true), code: '1');
    await banc.monter(tester);

    await menu(tester, 'Scanner un produit');

    expect(
      find.textContaining('Impossible de joindre Open Food Facts'),
      findsOneWidget,
    );
  });

  testWidgets('scan annulé : rien ne se passe', (tester) async {
    final catalogue = FauxCatalogue(produit: produit);
    final banc = Banc(catalogue: catalogue, code: null);
    await banc.monter(tester);

    await menu(tester, 'Scanner un produit');

    expect(catalogue.recherches, isEmpty);
  });

  testWidgets('ajouter une activité : calories estimées', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await menu(tester, 'Ajouter une activité');
    await taper(tester, 'MMA');
    await saisir(tester, 'Durée (min)', '90');
    await taper(tester, 'Intense');
    expect(find.text('≈ 1440 kcal brûlées'), findsOneWidget);
    await taper(tester, 'Enregistrer');

    final a = banc.journal.activitesDe('u1').single;
    expect(a.type, TypeActivite.mma);
    expect(a.minutes, 90);
    expect(a.intensite, Intensite.intense);
    expect(a.kcal, closeTo(1440, 1e-9));
  });

  testWidgets('activité sans durée : refusée', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await menu(tester, 'Ajouter une activité');
    await taper(tester, 'Enregistrer');

    expect(banc.journal.activitesDe('u1'), isEmpty);
  });

  testWidgets('supprimer un repas', (tester) async {
    final banc = Banc();
    await banc.repas(600);
    await banc.monter(tester);

    await defilerJusqua(tester, find.byTooltip('Supprimer'));
    await tester.tap(find.byTooltip('Supprimer').first);
    await tester.pumpAndSettle();

    expect(banc.journal.repasDe('u1'), isEmpty);
    expect(texteDe(tester, 'valeur-mange'), '0 kcal');
  });

  testWidgets('jour précédent : journal de la veille, suivant désactivé', (
    tester,
  ) async {
    final banc = Banc();
    await banc.repas(600);
    await banc.monter(tester);

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Jour précédent'));
    await tester.pumpAndSettle();

    expect(texteDe(tester, 'valeur-mange'), '0 kcal');
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('repas ajouté un jour passé : daté de ce jour', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await tester.tap(find.byTooltip('Jour précédent'));
    await tester.pumpAndSettle();
    await menu(tester, 'Ajouter un repas');
    await saisir(tester, 'Calories (kcal)', '400');
    await taper(tester, 'Enregistrer');

    expect(banc.journal.repasDe('u1').single.date, DateTime(2026, 10, 8, 12));
  });
}
