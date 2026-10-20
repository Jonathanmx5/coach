import 'package:coach/journal/calculs.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/sante/ajustements.dart';
import 'package:coach/sante/modele.dart' as sante;
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
  bilanTests();
  group('calories d\'une activité (MET × kg × heures)', () {
    test('1 h de vélo modéré à 80 kg : (7,5 − 1) × 80 = 520', () {
      expect(
        kcalActivite(TypeActivite.velo, 60, Intensite.moderee, 80),
        closeTo(520, 1e-9),
      );
    });
    test('1 h 30 de MMA intense à 80 kg : (10 × 1,2 − 1) × 80 × 1,5', () {
      expect(
        kcalActivite(TypeActivite.mma, 90, Intensite.intense, 80),
        closeTo(1320, 1e-9),
      );
    });
    test('30 min de marche légère à 60 kg : (3,5 × 0,8 − 1) × 60 × 0,5', () {
      expect(
        kcalActivite(TypeActivite.marche, 30, Intensite.legere, 60),
        closeTo(54, 1e-9),
      );
    });
    test('45 min de course à 80 kg : (9,8 − 1) × 80 × 0,75 (nettes)', () {
      expect(
        kcalActivite(TypeActivite.course, 45, Intensite.moderee, 80),
        closeTo((9.8 - 1) * 80 * 0.75, 1e-9),
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
    test('sans montre : maintien du profil + activités manuelles', () {
      expect(
        depenseDuJour(maintien: 2448, kcalMontre: null, kcalActivites: 600),
        2448 + 600,
      );
    });

    test('montre sans total : base + calories actives', () {
      expect(
        depenseDuJour(
          maintien: 2448,
          depenseBase: 1780,
          kcalMontre: null,
          kcalActives: 500,
          kcalActivites: 0,
        ),
        1780 + 500,
      );
    });

    test(
      'avec montre : calories totales de la montre + activités manuelles',
      () {
        expect(
          depenseDuJour(maintien: 2448, kcalMontre: 2500, kcalActivites: 600),
          3100,
        );
      },
    );

    test('une montre à 0 kcal est ignorée', () {
      expect(
        depenseDuJour(maintien: 2448, kcalMontre: 0, kcalActivites: 0),
        2448,
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
    final course = Activite(
      date: DateTime(2026, 10, 7, 8),
      type: TypeActivite.course,
      minutes: 30,
      intensite: Intensite.moderee,
      kcal: 300,
    );

    test('un solde par jour avec repas, jours vides ignorés', () {
      final soldes = soldesRecents(
        repas: [le(5, 1000), le(5, 1000), le(7, 2000)],
        activites: [course],
        maintien: 1200,
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
          maintien: 1200,
          debut: DateTime(2026, 10, 3),
          fin: DateTime(2026, 10, 9),
        ),
        isEmpty,
      );
    });

    test('journée complète mesurée par la montre : son total sert', () {
      final soldes = soldesRecents(
        repas: [le(5, 2000), le(7, 2000)],
        activites: [course],
        maintien: 1200,
        jours: [
          sante.JourSante(
            jour: DateTime(2026, 10, 7),
            kcalTotales: 2800,
            derniereMesureKcal: DateTime(2026, 10, 7, 23),
          ),
          // Montre retirée à midi : le maintien sert.
          sante.JourSante(
            jour: DateTime(2026, 10, 5),
            kcalTotales: 900,
            derniereMesureKcal: DateTime(2026, 10, 5, 12),
          ),
        ],
        debut: DateTime(2026, 10, 3),
        fin: DateTime(2026, 10, 9),
      );
      // Jour 5 : 2000 − 1200 ; jour 7 : 2000 − 2800 (la course est dedans).
      expect(soldes..sort(), [-800, 800]);
    });
  });
}

void bilanTests() {
  // Homme de 30 ans, 80 kg, 1,80 m : base 1780.
  final aujourdhui = DateTime(2026, 10, 9);
  final soir = DateTime(2026, 10, 9, 23, 59);

  sante.JourSante jourMontre(
    int joursAvant, {
    double? totales,
    double? actives,
    List<sante.Seance> seances = const [],
  }) {
    final jour = DateTime(2026, 10, 9 - joursAvant);
    return sante.JourSante(
      jour: jour,
      kcalTotales: totales,
      kcalActives: actives,
      seances: seances,
      derniereMesureKcal: totales == null && actives == null
          ? null
          : DateTime(jour.year, jour.month, jour.day, 23),
    );
  }

  /// 7 jours complets à 2600 kcal dont 600 actives, puis aujourd'hui.
  List<sante.JourSante> semaine(double activesAujourdhui) => [
    for (var i = 7; i >= 1; i--) jourMontre(i, totales: 2600, actives: 600),
    jourMontre(0, totales: 2400, actives: activesAujourdhui),
  ];

  BilanJour bilan(
    List<sante.JourSante> jours, {
    Profil p = profil,
    List<Repas> repas = const [],
    List<Activite> activites = const [],
    DateTime? maintenant,
  }) {
    final m = maintenant ?? soir;
    return bilanDuJour(
      profil: p,
      jours: jours,
      maintienMesure: maintienMesure(
        jours,
        aujourdhui: m,
        depenseBase: calculerReperes(p, maintenant: m).depenseBase,
      ),
      repas: repas,
      activites: activites,
      jour: aujourdhui,
      maintenant: m,
    );
  }

  group('bilan du jour', () {
    test('objectif perte, journée d\'activité habituelle : cible ≤ 90 % '
        'du maintien', () {
      final b = bilan(semaine(600));
      expect(b.reperes.maintien, 2600);
      expect(b.kcalExercice, 0);
      expect(b.cibles.kcal, lessThanOrEqualTo(0.9 * 2600));
      expect(b.cibles.kcal, b.reperes.kcalCible);
      expect(b.intensite, IntensiteJour.repos);
      expect(b.estime, isFalse);
    });

    test('400 kcal actives au-dessus de la moyenne : +70 % de l\'écart', () {
      final b = bilan(semaine(1000));
      expect(b.kcalExercice, closeTo(400, 1e-9));
      expect(b.cibles.kcal, closeTo(b.reperes.kcalCible + 0.7 * 400, 1e-9));
      expect(b.intensite, IntensiteJour.intense);
    });

    test('sans montre, profil Actif, cible mangée : déficit, pas excédent', () {
      const actif = Profil(
        objectif: Objectif.perte,
        sexe: Sexe.homme,
        anneeNaissance: 1996,
        tailleCm: 180,
        poidsKg: 80,
        typeDeVie: TypeDeVie.actif,
        typesEntrainement: {TypeEntrainement.salle},
        niveau: Niveau.debutant,
        joursParSemaine: 3,
        dureeSeanceMin: 45,
        problemeSante: false,
      );
      final b = bilan(const [], p: actif, repas: [repas(2350)]);
      expect(b.reperes.kcalCible, 2350);
      expect(b.depenseJour, b.reperes.maintien);
      expect(b.ecart, closeTo(-409, 1));
      expect(b.brulees, closeTo(b.reperes.maintien * 1439 / 1440, 1e-6));
      expect(b.estime, isTrue);
    });

    test('sans montre : calories nettes des activités saisies', () {
      final b = bilan(
        const [],
        activites: [
          Activite(
            date: DateTime(2026, 10, 9, 18),
            type: TypeActivite.course,
            minutes: 45,
            intensite: Intensite.moderee,
            kcal: 528,
          ),
        ],
        maintenant: DateTime(2026, 10, 9, 12),
      );
      expect(b.kcalExercice, 528);
      expect(b.cibles.kcal, closeTo(b.reperes.kcalCible + 0.7 * 528, 1e-9));
      expect(b.brulees, closeTo(b.reperes.maintien * 0.5 + 528, 1e-9));
      expect(b.depenseJour, b.reperes.maintien + 528);
    });

    test('montre avec calories actives sans total : la dépense les inclut', () {
      final b = bilan([
        jourMontre(0, actives: 500),
      ], maintenant: DateTime(2026, 10, 9, 12));
      expect(b.brulees, closeTo(1780 * 0.5 + 500, 1e-9));
      expect(b.depenseJour, 1780 + 500);
      expect(b.estime, isFalse);
    });

    test('séance de la montre sans calories du jour : elle compte dans la '
        'dépense, l\'activité saisie identique ne s\'ajoute pas', () {
      final b = bilan(
        [
          jourMontre(
            0,
            seances: [
              sante.Seance(
                type: 'RUNNING',
                debut: DateTime(2026, 10, 9, 7),
                duree: const Duration(minutes: 45),
                kcal: 450,
              ),
            ],
          ),
        ],
        activites: [
          Activite(
            date: DateTime(2026, 10, 9, 12, 30),
            type: TypeActivite.course,
            minutes: 45,
            intensite: Intensite.moderee,
            kcal: 528,
          ),
        ],
      );
      expect(b.depenseJour, b.reperes.maintien + 450);
      expect(b.kcalExercice, 450);
    });

    test('un jour passé : brûlées = dépense de la journée entière', () {
      final b = bilanDuJour(
        profil: profil,
        jours: const [],
        repas: const [],
        activites: const [],
        jour: DateTime(2026, 10, 8),
        maintenant: DateTime(2026, 10, 9, 8),
      );
      expect(b.brulees, b.depenseJour);
    });
  });

  group('activités déjà comptées par la montre', () {
    Activite courseSaisie(DateTime date) => Activite(
      date: date,
      type: TypeActivite.course,
      minutes: 45,
      intensite: Intensite.moderee,
      kcal: 528,
    );
    final saisieMidi = courseSaisie(DateTime(2026, 10, 9, 12, 30));
    sante.Seance seance(String type, int minutes) => sante.Seance(
      type: type,
      debut: DateTime(2026, 10, 9, 7),
      duree: Duration(minutes: minutes),
    );

    test('saisie à 12 h 30 d\'une course de 7 h enregistrée par la montre : '
        'non ajoutée', () {
      expect(
        kcalActivitesNonComptees([saisieMidi], [seance('RUNNING', 45)]),
        0,
      );
    });

    test('séance de type ou de durée différents : l\'activité compte', () {
      expect(
        kcalActivitesNonComptees([saisieMidi], [seance('BIKING', 45)]),
        528,
      );
      expect(
        kcalActivitesNonComptees([saisieMidi], [seance('RUNNING', 90)]),
        528,
      );
    });

    test('total de la montre mesuré après l\'activité, sans séance : non '
        'ajoutée', () {
      expect(
        kcalActivitesNonComptees(
          [saisieMidi],
          const [],
          kcalTotales: 1500,
          derniereMesureKcal: DateTime(2026, 10, 9, 13),
        ),
        0,
      );
    });

    test('total de la montre arrêté avant l\'activité : elle compte', () {
      expect(
        kcalActivitesNonComptees(
          [saisieMidi],
          const [],
          kcalTotales: 900,
          derniereMesureKcal: DateTime(2026, 10, 9, 10),
        ),
        528,
      );
    });
  });
}
