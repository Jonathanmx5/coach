import 'package:coach/accueil/bilan_semaine.dart';
import 'package:coach/journal/calculs.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/poids/pesees.dart';
import 'package:coach/profil/besoins.dart';
import 'package:flutter_test/flutter_test.dart';

import 'semaine_commun.dart';

BilanSemaine calculer({
  List<Repas> repas = const [],
  List<Activite> activites = const [],
  List<Pesee> pesees = const [],
}) => bilanSemaine(
  profil: profil,
  repas: repas,
  activites: activites,
  pesees: pesees,
  maintenant: maintenant,
);

void main() {
  test('dans la cible : ±10 % de la cible du jour, bornes comprises', () {
    expect(dansLaCible(1100, 1000), isTrue);
    expect(dansLaCible(900, 1000), isTrue);
    expect(dansLaCible(1101, 1000), isFalse);
    expect(dansLaCible(899, 1000), isFalse);
    expect(dansLaCible(0, 0), isFalse);
  });

  test("moyennes sur les jours notés des 7 journées terminées, pas "
      "aujourd'hui ni avant", () {
    final b = calculer(
      repas: [
        repas(19, 1200, proteines: 60),
        repas(19, 800, proteines: 40, heure: 20),
        repas(17, 1000, proteines: 60),
        // Aujourd'hui (journée en cours) et il y a 8 jours : ignorés.
        repas(20, 500, proteines: 30),
        repas(12, 3000, proteines: 200),
      ],
    );

    expect(b.joursNotes, 2);
    expect(b.kcalMoyenne, 1500);
    expect(b.proteinesMoyenne, 80);
    expect(b.cibleMoyenne, closeTo(cible, 1e-6));
    expect(
      b.cibleProteines,
      calculerReperes(profil, maintenant: maintenant).proteinesG,
    );
  });

  test('jours dans la cible : seulement parmi les jours notés', () {
    final b = calculer(
      repas: [
        repas(13, cible * 1.10),
        repas(14, cible * 0.90),
        repas(15, cible * 1.12),
        repas(16, cible * 0.5),
      ],
    );

    expect(b.joursNotes, 4);
    expect(b.joursDansCible, 2);
  });

  test("la cible d'un jour de sport compte la part d'exercice, comme le "
      'Journal', () {
    final b = calculer(
      repas: [repas(18, cible + partExerciceMangee * 300)],
      activites: [activite(18, kcal: 300)],
    );

    expect(b.cibleMoyenne, closeTo(cible + partExerciceMangee * 300, 1e-6));
    expect(b.joursDansCible, 1);
  });

  test('semaine sans repas : pas de moyenne, la cible reste affichée', () {
    final b = calculer();

    expect(b.joursNotes, 0);
    expect(b.kcalMoyenne, isNull);
    expect(b.proteinesMoyenne, isNull);
    expect(b.joursDansCible, 0);
    expect(b.cibleMoyenne, closeTo(cible, 1e-6));
  });

  test("séances des 7 derniers jours, aujourd'hui compris", () {
    final b = calculer(
      activites: [activite(20), activite(14), activite(13), activite(21)],
    );

    expect(b.seances, 2);
    expect(b.seancesPrevues, 3);
  });

  test('poids : moyenne mobile comparée à celle de la semaine d avant', () {
    final b = calculer(
      pesees: [
        pesee(5, 90), // Hors des deux semaines.
        pesee(8, 81),
        pesee(12, 80.6),
        pesee(15, 80.2),
        pesee(19, 79.8),
      ],
    );

    // 19 : moyenne des pesées du 13 au 19 ; 12 : celles du 6 au 12.
    expect(b.poidsTendance, closeTo(80.0, 1e-9));
    expect(b.evolutionPoids, closeTo(80.0 - 80.8, 1e-9));
  });

  test('poids : sans pesée la semaine d avant, la tendance seule', () {
    final b = calculer(pesees: [pesee(16, 80), pesee(18, 79)]);

    expect(b.poidsTendance, closeTo(79.5, 1e-9));
    expect(b.evolutionPoids, isNull);
  });

  test('poids : sans pesée récente, rien', () {
    final b = calculer(pesees: [pesee(10, 80)]);

    expect(b.poidsTendance, isNull);
    expect(b.evolutionPoids, isNull);
  });

  test('écart de poids avec le signe, au dixième', () {
    expect(ecartPoidsTexte(-0.44), '−0,4 kg');
    expect(ecartPoidsTexte(0.26), '+0,3 kg');
    expect(ecartPoidsTexte(0.04), '0,0 kg');
    expect(ecartPoidsTexte(-1.25), '−1,3 kg');
  });
}
