import 'package:coach/entrainement/modele.dart';
import 'package:coach/entrainement/semaine.dart';
import 'package:flutter_test/flutter_test.dart';

SeanceFaite seance(int jour) => SeanceFaite(
  date: DateTime(2026, 10, jour, 18),
  lieu: Lieu.maison,
  minutes: 30,
);

void main() {
  // Semaine du lundi 5 au dimanche 11 octobre 2026.
  test('joursPrevus : autant de jours que demandé, répartis', () {
    for (var n = 1; n <= 7; n++) {
      expect(joursPrevus(n), hasLength(n));
    }
    expect(joursPrevus(3), {1, 3, 5});
    expect(joursPrevus(2), {2, 5});
    // Hors bornes : ramené entre 1 et 7.
    expect(joursPrevus(0), hasLength(1));
    expect(joursPrevus(9), hasLength(7));
  });

  test('lundiDe', () {
    expect(lundiDe(DateTime(2026, 10, 11, 23)), DateTime(2026, 10, 5));
    expect(lundiDe(DateTime(2026, 10, 5, 0, 1)), DateTime(2026, 10, 5));
  });

  EtatDuJour etat(int jour, List<int> faites, {int n = 3}) => etatDuJour(
    maintenant: DateTime(2026, 10, jour, 12),
    joursParSemaine: n,
    semaine: [for (final j in faites) seance(j)],
  );

  test('etatDuJour : séance, faite, repos, rattrapage, semaine faite', () {
    expect(etat(5, []), EtatDuJour.seance); // lundi prévu
    expect(etat(5, [5]), EtatDuJour.faite);
    expect(etat(6, [5]), EtatDuJour.repos); // mardi
    expect(etat(7, [5]), EtatDuJour.seance); // mercredi prévu
    expect(etat(8, [5]), EtatDuJour.seance); // mercredi manqué : rattrapage
    expect(etat(8, [5, 7]), EtatDuJour.repos);
    expect(etat(10, [5, 7, 9]), EtatDuJour.semaineFaite);
    expect(etat(9, [5, 6, 7]), EtatDuJour.semaineFaite);
    // Les séances de la semaine précédente ne comptent pas.
    expect(etat(5, [4]), EtatDuJour.seance);
  });

  test(
    'prochaineSeance : jour prévu suivant, semaine suivante si complète',
    () {
      DateTime prochaine(int jour, int faites, {int n = 3}) => prochaineSeance(
        maintenant: DateTime(2026, 10, jour, 12),
        joursParSemaine: n,
        faitesSemaine: faites,
      );
      expect(prochaine(5, 1), DateTime(2026, 10, 7));
      expect(prochaine(8, 2), DateTime(2026, 10, 9));
      expect(prochaine(9, 3), DateTime(2026, 10, 12));
      expect(prochaine(9, 3, n: 7), DateTime(2026, 10, 10));
      expect(prochaine(11, 0, n: 1), DateTime(2026, 10, 14));
    },
  );
}
