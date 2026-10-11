import 'package:coach/journal/modele.dart';
import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/poids/poids_page.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/sante/modele.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);
const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

Profil profilDe({
  double kg = 60,
  int taille = 170,
  bool montre = false,
  Objectif objectif = Objectif.forme,
}) => Profil(
  objectif: objectif,
  sexe: Sexe.femme,
  anneeNaissance: 1996,
  tailleCm: taille,
  poidsKg: kg,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: const {TypeEntrainement.marche},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 30,
  problemeSante: false,
  montre: montre,
  appMontre: montre ? AppMontre.miFitness : null,
  poidsDate: DateTime(2026, 10, 1),
);

class Banc {
  Banc({Profil? profil, FauxSante? sante}) {
    final p = profil ?? profilDe();
    depot.donnees['u1'] = ProfilEnregistre(
      profil: p,
      reperes: calculerReperes(p, maintenant: maintenant),
    );
    this.sante = sante ?? FauxSante();
  }

  final depot = FauxDepot();
  final pesees = FauxPesees();
  final journal = FauxJournal();
  late final FauxSante sante;

  Profil get profil => depot.donnees['u1']!.profil;

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      CoachApp(
        accueil: PoidsPage(
          utilisateur: lea,
          enregistre: depot.donnees['u1']!,
          depot: depot,
          pesees: pesees,
          journal: journal,
          sante: sante,
          horloge: () => maintenant,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> ajouterEnBase(double kg, DateTime date) =>
      pesees.ajouter('u1', kg: kg, date: date);
}

PointSante peseeMontre(double kg, DateTime date) =>
    PointSante(type: TypeMesure.poids, debut: date, fin: date, valeur: kg);

int pointsDeLaCourbe(WidgetTester tester) => tester
    .widget<LineChart>(find.byType(LineChart))
    .data
    .lineBarsData
    .first
    .spots
    .length;

void main() {
  testWidgets('poids actuel, IMC et catégorie', (tester) async {
    final banc = Banc();
    await banc.ajouterEnBase(60, DateTime(2026, 10, 5));
    await banc.monter(tester);

    expect(find.text('60,0 kg'), findsOneWidget);
    expect(find.text('20,8'), findsOneWidget);
    expect(find.text('Poids normal'), findsOneWidget);
  });

  testWidgets('catégorie obésité à 100 kg pour 170 cm', (tester) async {
    final banc = Banc(profil: profilDe(kg: 100));
    await banc.ajouterEnBase(100, DateTime(2026, 10, 5));
    await banc.monter(tester);

    expect(find.text('34,6'), findsOneWidget);
    expect(find.text('Obésité'), findsOneWidget);
  });

  testWidgets('écart depuis la première pesée', (tester) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 9, 1));
    await banc.ajouterEnBase(59.7, DateTime(2026, 10, 5));
    await banc.monter(tester);

    expect(find.textContaining('−2,3 kg'), findsOneWidget);
  });

  testWidgets('aucune pesée : invitation et IMC du profil', (tester) async {
    final banc = Banc();
    await banc.monter(tester);

    await defilerJusqua(tester, find.textContaining('Aucune pesée pour l'));
    expect(find.textContaining('Aucune pesée pour l'), findsOneWidget);
    expect(find.text('Poids normal'), findsOneWidget);
  });

  testWidgets('ajouter une pesée avec une virgule : profil mis à jour', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Ajouter une pesée');
    await saisir(tester, 'Poids (kg)', '61,5');
    await taper(tester, 'Enregistrer');

    expect(banc.pesees.de('u1').single.kg, 61.5);
    expect(banc.profil.poidsKg, 61.5);
    expect(banc.profil.poidsDate, maintenant);
    expect(find.text('61,5 kg'), findsWidgets);
  });

  testWidgets('saisie invalide : message et rien d\'enregistré', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Ajouter une pesée');
    await saisir(tester, 'Poids (kg)', '10');
    await taper(tester, 'Enregistrer');

    expect(
      find.textContaining('Entre une valeur entre 30 et 300'),
      findsOneWidget,
    );
    expect(banc.pesees.de('u1'), isEmpty);
  });

  testWidgets('pesée qui passe sous 18,5 : objectif perte remplacé', (
    tester,
  ) async {
    final banc = Banc(profil: profilDe(objectif: Objectif.perte));
    await banc.monter(tester);

    await taper(tester, 'Ajouter une pesée');
    await saisir(tester, 'Poids (kg)', '52');
    await taper(tester, 'Enregistrer');

    expect(banc.profil.objectif, Objectif.forme);
  });

  testWidgets('supprimer la dernière saisie : profil ramené à la précédente', (
    tester,
  ) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 2));
    await banc.ajouterEnBase(59, DateTime(2026, 10, 8));
    await banc.monter(tester);

    // Les pesées les plus récentes sont en haut de l'historique.
    await defilerJusqua(tester, find.byTooltip('Supprimer'));
    await tester.tap(find.byTooltip('Supprimer').first);
    await tester.pumpAndSettle();

    expect(banc.pesees.de('u1').single.kg, 62);
    expect(banc.profil.poidsKg, 62);
  });

  testWidgets('pesées de la montre : affichées, non supprimables', (
    tester,
  ) async {
    final banc = Banc(
      profil: profilDe(montre: true),
      sante: FauxSante(points: [peseeMontre(61.2, DateTime(2026, 10, 6, 7))]),
    );
    await banc.monter(tester);

    expect(find.text('61,2 kg'), findsWidgets);
    await defilerJusqua(tester, find.text('Montre'));
    expect(find.text('Montre'), findsOneWidget);
    expect(find.byTooltip('Supprimer'), findsNothing);
  });

  testWidgets('périodes 30 jours, 90 jours et 1 an', (tester) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 1));
    await banc.ajouterEnBase(61, DateTime(2026, 8, 1));
    await banc.ajouterEnBase(60, DateTime(2026, 3, 1));
    await banc.monter(tester);

    await taper(tester, '30 jours');
    expect(pointsDeLaCourbe(tester), 1);
    await taper(tester, '90 jours');
    expect(pointsDeLaCourbe(tester), 2);
    await taper(tester, '1 an');
    expect(pointsDeLaCourbe(tester), 3);
  });

  testWidgets('projection en pointillés selon le journal, sinon rien', (
    tester,
  ) async {
    final banc = Banc();
    await banc.ajouterEnBase(62, DateTime(2026, 10, 1));
    await banc.monter(tester);
    expect(find.textContaining('projection sur 5 jours'), findsNothing);
    expect(
      tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData,
      hasLength(1),
    );

    banc.journal.repasParUid['u1'] = [
      Repas(
        date: DateTime(2026, 10, 8, 12),
        moment: Moment.dejeuner,
        nom: 'x',
        macros: const Macros(kcal: 3000),
        source: SourceRepas.manuel,
      ),
    ];
    await banc.monter(tester);
    final courbes = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData;
    expect(courbes, hasLength(2));
    expect(courbes.last.dashArray, isNotNull);
    expect(courbes.last.spots, hasLength(6));
    expect(courbes.last.spots.last.y, greaterThan(62));
    expect(find.textContaining('projection sur 5 jours'), findsOneWidget);
  });
}
