import 'package:coach/journal/calculs.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:flutter_test/flutter_test.dart';

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

// Repères « perte simple » : base 1780, maintien 2448, cible 2080, 128 g prot.
const reperes = Reperes(
  depenseBase: 1780,
  maintien: 2448,
  kcalCible: 2080,
  proteinesG: 128,
);

Repas repas(double kcal, {double p = 0, double g = 0, double l = 0}) => Repas(
  date: DateTime(2026, 10, 9, 12),
  moment: Moment.dejeuner,
  nom: 'x',
  macros: Macros(kcal: kcal, proteines: p, glucides: g, lipides: l),
  source: SourceRepas.manuel,
);

void main() {
  soldesTests();
  group('calories d\'une activité (MET × kg × heures)', () {
    test('1 h de vélo modéré à 80 kg : 7,5 × 80 = 600', () {
      expect(
        kcalActivite(TypeActivite.velo, 60, Intensite.moderee, 80),
        closeTo(600, 1e-9),
      );
    });
    test('1 h 30 de MMA intense à 80 kg : 10 × 1,2 × 80 × 1,5 = 1440', () {
      expect(
        kcalActivite(TypeActivite.mma, 90, Intensite.intense, 80),
        closeTo(1440, 1e-9),
      );
    });
    test('30 min de marche légère à 60 kg : 3,5 × 0,8 × 60 × 0,5 = 84', () {
      expect(
        kcalActivite(TypeActivite.marche, 30, Intensite.legere, 60),
        closeTo(84, 1e-9),
      );
    });
  });

  group('cibles du jour', () {
    test('jour de repos : repère inchangé', () {
      final c = ciblesDuJour(reperes, kcalExercice: 0);
      expect(c.kcal, 2080);
      expect(c.proteines, 128);
      expect(c.lipides, closeTo(2080 * 0.25 / 9, 1e-9));
      expect(c.glucides, closeTo((2080 - 128 * 4 - 2080 * 0.25) / 4, 1e-9));
    });

    test('jour d\'effort : +70 % des calories d\'exercice', () {
      final c = ciblesDuJour(reperes, kcalExercice: 1000);
      expect(c.kcal, 2780);
      expect(c.proteines, 128);
      expect(
        c.glucides,
        greaterThan(ciblesDuJour(reperes, kcalExercice: 0).glucides),
      );
    });

    test('intensité du jour selon les calories d\'exercice', () {
      expect(intensiteDuJour(50), IntensiteJour.repos);
      expect(intensiteDuJour(100), IntensiteJour.modere);
      expect(intensiteDuJour(399), IntensiteJour.modere);
      expect(intensiteDuJour(400), IntensiteJour.intense);
    });
  });

  group('bilan énergétique', () {
    test('sans montre : (base × 1,2) + activités manuelles', () {
      expect(
        depenseDuJour(depenseBase: 1780, kcalMontre: null, kcalActivites: 600),
        1780 * 1.2 + 600,
      );
    });

    test(
      'avec montre : calories totales de la montre + activités manuelles',
      () {
        expect(
          depenseDuJour(
            depenseBase: 1780,
            kcalMontre: 2500,
            kcalActivites: 600,
          ),
          3100,
        );
      },
    );

    test('une montre à 0 kcal est ignorée', () {
      expect(
        depenseDuJour(depenseBase: 1780, kcalMontre: 0, kcalActivites: 0),
        1780 * 1.2,
      );
    });

    test('solde = mangé − dépensé', () {
      final macros = totalMacros([repas(500, p: 30), repas(700, p: 40)]);
      expect(macros.kcal, 1200);
      expect(macros.proteines, 70);
      expect(solde(mange: macros.kcal, depense: 2000), -800);
    });
  });

  group('projection du poids à 5 jours', () {
    test('déficit moyen de 770 kcal/jour : −0,1 kg par jour', () {
      final p = projeterPoids(poidsKg: 80, soldes: [-770, -770, -770])!;
      expect(p.length, 5);
      expect(p.first, closeTo(79.9, 1e-9));
      expect(p.last, closeTo(79.5, 1e-9));
    });

    test('excédent : le poids monte', () {
      final p = projeterPoids(poidsKg: 80, soldes: [770])!;
      expect(p.last, closeTo(80.5, 1e-9));
    });

    test('aucun jour renseigné : pas de projection', () {
      expect(projeterPoids(poidsKg: 80, soldes: const []), isNull);
    });
  });
}

void soldesTests() {
  group('soldesRecents', () {
    Repas le(int jour, double kcal) => Repas(
      date: DateTime(2026, 10, jour, 12),
      moment: Moment.dejeuner,
      nom: 'x',
      macros: Macros(kcal: kcal),
      source: SourceRepas.manuel,
    );

    test('un solde par jour avec repas, jours vides ignorés', () {
      final soldes = soldesRecents(
        repas: [le(5, 1000), le(5, 1000), le(7, 2000)],
        activites: [
          Activite(
            date: DateTime(2026, 10, 7, 8),
            type: TypeActivite.course,
            minutes: 30,
            intensite: Intensite.moderee,
            kcal: 300,
          ),
        ],
        depenseBase: 1000,
        debut: DateTime(2026, 10, 3),
        fin: DateTime(2026, 10, 9),
      );
      // Jour 5 : 2000 − 1200 ; jour 7 : 2000 − 1500.
      expect(soldes..sort(), [500, 800]);
    });

    test('hors fenêtre ignoré', () {
      expect(
        soldesRecents(
          repas: [le(9, 1000)],
          activites: const [],
          depenseBase: 1000,
          debut: DateTime(2026, 10, 3),
          fin: DateTime(2026, 10, 9),
        ),
        isEmpty,
      );
    });
  });
}
