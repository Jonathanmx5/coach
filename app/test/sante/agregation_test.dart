import 'package:coach/sante/agregation.dart';
import 'package:coach/sante/modele.dart';
import 'package:flutter_test/flutter_test.dart';

PointSante pt(
  TypeMesure type,
  DateTime debut,
  DateTime fin,
  double valeur, [
  String? libelle,
]) => PointSante(
  type: type,
  debut: debut,
  fin: fin,
  valeur: valeur,
  libelle: libelle,
);

PointSante instant(TypeMesure type, DateTime t, double valeur) =>
    pt(type, t, t, valeur);

final lundi = DateTime(2026, 10, 5);
final mardi = DateTime(2026, 10, 6);

JourSante jour(List<JourSante> jours, DateTime d) =>
    jours.firstWhere((j) => j.jour == d);

PointSante src(
  TypeMesure type,
  String source,
  DateTime debut,
  DateTime fin,
  double valeur,
) => PointSante(
  type: type,
  debut: debut,
  fin: fin,
  valeur: valeur,
  source: source,
);

void main() {
  test(
    'deux applications pour les mêmes pas : la plus complète, pas la somme',
    () {
      final h8 = lundi.add(const Duration(hours: 8));
      final h9 = lundi.add(const Duration(hours: 9));
      final h10 = lundi.add(const Duration(hours: 10));
      final jours = agregerParJour(
        [
          // Le téléphone et la montre ont compté les mêmes pas.
          src(TypeMesure.pas, 'tel', h8, h9, 1000),
          src(TypeMesure.pas, 'tel', h9, h10, 1500),
          src(TypeMesure.pas, 'montre', h8, h10, 3000),
        ],
        debut: lundi,
        fin: mardi,
      );
      final j = jour(jours, lundi);
      expect(j.pas, 3000);
    },
  );

  test('calories : source retenue et heure de la dernière mesure', () {
    final jours = agregerParJour(
      [
        src(
          TypeMesure.kcalTotales,
          'com.google.android.apps.fitness',
          lundi,
          lundi.add(const Duration(hours: 7)),
          480,
        ),
        src(
          TypeMesure.kcalTotales,
          'com.google.android.apps.fitness',
          lundi.add(const Duration(hours: 7)),
          lundi.add(const Duration(hours: 8, minutes: 12)),
          50,
        ),
        // Une autre application, avec moins de données : ignorée.
        src(
          TypeMesure.kcalTotales,
          'com.xiaomi.wearable',
          lundi,
          lundi.add(const Duration(hours: 6)),
          300,
        ),
      ],
      debut: lundi,
      fin: mardi,
    );
    final j = jour(jours, lundi);
    expect(j.kcalTotales, 530);
    expect(j.sourceKcal, 'com.google.android.apps.fitness');
    expect(
      j.derniereMesureKcal,
      lundi.add(const Duration(hours: 8, minutes: 12)),
    );
  });

  test(
    'points sans source (anciens tests, autres plateformes) : additionnés',
    () {
      final jours = agregerParJour(
        [
          pt(
            TypeMesure.pas,
            lundi.add(const Duration(hours: 8)),
            lundi.add(const Duration(hours: 9)),
            1000,
          ),
          pt(
            TypeMesure.pas,
            lundi.add(const Duration(hours: 12)),
            lundi.add(const Duration(hours: 13)),
            2500,
          ),
        ],
        debut: lundi,
        fin: mardi,
      );
      expect(jour(jours, lundi).pas, 3500);
    },
  );

  test('un total prévu jusqu\'à minuit ne compte que ce qui est écoulé', () {
    // Les enregistrements réels de Google Fit un matin à 7 h 59.
    final matin = DateTime(2026, 10, 12);
    final maintenant = DateTime(2026, 10, 12, 7, 59);
    final jours = agregerParJour(
      [
        pt(
          TypeMesure.kcalTotales,
          matin,
          DateTime(2026, 10, 12, 6, 58, 6),
          485.8,
        ),
        pt(
          TypeMesure.kcalTotales,
          DateTime(2026, 10, 12, 7, 13, 57),
          DateTime(2026, 10, 13),
          1169,
        ),
      ],
      debut: matin,
      fin: maintenant,
      maintenant: maintenant,
    );

    final kcal = jour(jours, matin).kcalTotales!;
    // 485,8 + la part écoulée des 1169 (45 min sur 16 h 46) ≈ 52 : environ 538.
    expect(
      kcal,
      closeTo(485.8 + 1169 * (45 * 60 + 3) / (16 * 3600 + 46 * 60 + 3), 0.5),
    );
    expect(kcal, lessThan(560));
  });

  test('un intervalle entièrement dans le futur est ignoré', () {
    final maintenant = DateTime(2026, 10, 12, 8);
    final jours = agregerParJour(
      [
        pt(
          TypeMesure.pas,
          DateTime(2026, 10, 12, 7),
          DateTime(2026, 10, 12, 7, 30),
          400,
        ),
        pt(
          TypeMesure.pas,
          DateTime(2026, 10, 12, 9),
          DateTime(2026, 10, 12, 10),
          5000,
        ),
      ],
      debut: DateTime(2026, 10, 12),
      fin: maintenant,
      maintenant: maintenant,
    );
    expect(jour(jours, DateTime(2026, 10, 12)).pas, 400);
  });

  test('sans « maintenant », rien n\'est coupé (historique)', () {
    final jours = agregerParJour(
      [pt(TypeMesure.kcalTotales, lundi, mardi, 2000)],
      debut: lundi,
      fin: mardi,
    );
    expect(jour(jours, lundi).kcalTotales, 2000);
  });

  test('pas du même jour additionnés', () {
    final jours = agregerParJour(
      [
        pt(
          TypeMesure.pas,
          lundi.add(const Duration(hours: 8)),
          lundi.add(const Duration(hours: 9)),
          1000,
        ),
        pt(
          TypeMesure.pas,
          lundi.add(const Duration(hours: 12)),
          lundi.add(const Duration(hours: 13)),
          2500,
        ),
        pt(
          TypeMesure.pas,
          lundi.add(const Duration(hours: 18)),
          lundi.add(const Duration(hours: 19)),
          500,
        ),
      ],
      debut: lundi,
      fin: mardi,
    );

    expect(jour(jours, lundi).pas, 4000);
    expect(jour(jours, mardi).pas, isNull);
  });

  test('FC au repos : dernière valeur du jour', () {
    final jours = agregerParJour(
      [
        instant(TypeMesure.fcRepos, lundi.add(const Duration(hours: 6)), 58),
        instant(TypeMesure.fcRepos, lundi.add(const Duration(hours: 22)), 55),
      ],
      debut: lundi,
      fin: lundi,
    );

    expect(jour(jours, lundi).fcRepos, 55);
  });

  test('un total coupé au présent garde sa source (pas de fausse source)', () {
    final maintenant = DateTime(2026, 10, 12, 8);
    final jours = agregerParJour(
      [
        src(
          TypeMesure.kcalTotales,
          'fit',
          DateTime(2026, 10, 12),
          DateTime(2026, 10, 12, 7),
          500,
        ),
        // Écrit d'avance jusqu'à 9 h : coupé à 8 h, toujours de « fit ».
        src(
          TypeMesure.kcalTotales,
          'fit',
          DateTime(2026, 10, 12, 7),
          DateTime(2026, 10, 12, 9),
          200,
        ),
      ],
      debut: DateTime(2026, 10, 12),
      fin: maintenant,
      maintenant: maintenant,
    );
    final j = jour(jours, DateTime(2026, 10, 12));
    expect(j.kcalTotales, closeTo(600, 0.01));
    expect(j.sourceKcal, 'fit');
  });

  group('sommeil', () {
    DateTime h(int heures, [int minutes = 0]) =>
        lundi.add(Duration(hours: heures, minutes: minutes));

    test('nuit de 22 h à 6 h en phases de 30 min : 8 h le jour du lever', () {
      const types = [
        TypeMesure.sommeilLeger,
        TypeMesure.sommeilProfond,
        TypeMesure.sommeilParadoxal,
      ];
      final jours = agregerParJour(
        [
          // Trois phases finissent avant minuit, une à minuit pile.
          for (var i = 0; i < 16; i++)
            src(types[i % 3], 'mi', h(22, 30 * i), h(22, 30 * (i + 1)), 30),
        ],
        debut: lundi,
        fin: mardi,
      );

      expect(jour(jours, lundi).sommeil, isNull);
      expect(jour(jours, mardi).sommeil!.endormi, const Duration(hours: 8));
    });

    test('phases séparées par un réveil de moins de 2 h : une seule nuit', () {
      final jours = agregerParJour(
        [
          src(TypeMesure.sommeilLeger, 'mi', h(22), h(23, 30), 90),
          src(TypeMesure.sommeilLeger, 'mi', h(24, 30), h(30), 330),
        ],
        debut: lundi,
        fin: mardi,
      );

      expect(jour(jours, lundi).sommeil, isNull);
      expect(jour(jours, mardi).sommeil!.endormi, const Duration(hours: 7));
    });

    test("phases d'une session rattachées au jour de fin de la session", () {
      final jours = agregerParJour(
        [
          src(TypeMesure.sommeilSession, 'mi', h(21), h(30), 540),
          // Un réveil de plus de 2 h dans la même session : même nuit.
          src(TypeMesure.sommeilProfond, 'mi', h(21), h(22), 60),
          src(TypeMesure.sommeilLeger, 'mi', h(25), h(30), 300),
        ],
        debut: lundi,
        fin: mardi,
      );

      expect(jour(jours, lundi).sommeil, isNull);
      final nuit = jour(jours, mardi).sommeil!;
      expect(nuit.endormi, const Duration(hours: 6));
      expect(nuit.profond, const Duration(hours: 1));
    });

    test('deux sources qui classent différemment la même heure : 1 h', () {
      final resume = resumerSommeil([
        src(TypeMesure.sommeilProfond, 'mi', h(25), h(26), 60),
        src(TypeMesure.sommeilLeger, 'autre', h(25), h(26), 60),
      ])!;

      expect(resume.endormi, const Duration(hours: 1));
      expect(resume.profond + resume.leger, const Duration(hours: 1));
    });

    test('deux sources : celle qui couvre le plus longtemps la nuit', () {
      final jours = agregerParJour(
        [
          src(TypeMesure.sommeilProfond, 'mi', h(23), h(25), 120),
          src(TypeMesure.sommeilLeger, 'mi', h(25), h(30), 300),
          src(TypeMesure.sommeilLeger, 'autre', h(24), h(26), 120),
        ],
        debut: lundi,
        fin: mardi,
      );

      final nuit = jour(jours, mardi).sommeil!;
      expect(nuit.endormi, const Duration(hours: 7));
      expect(nuit.profond, const Duration(hours: 2));
      expect(nuit.leger, const Duration(hours: 5));
    });

    test('session sans phases : sa durée, moins les éveils', () {
      final jours = agregerParJour(
        [
          src(TypeMesure.sommeilSession, 'sommeil', h(23), h(30), 420),
          src(TypeMesure.sommeilEveil, 'sommeil', h(27), h(27, 30), 30),
        ],
        debut: lundi,
        fin: mardi,
      );

      final nuit = jour(jours, mardi).sommeil!;
      expect(nuit.endormi, const Duration(hours: 6, minutes: 30));
      expect(nuit.aDesPhases, isFalse);
      expect(nuit.eveil, const Duration(minutes: 30));
    });

    test('session seule : durée lue', () {
      final resume = resumerSommeil([
        src(TypeMesure.sommeilSession, 'sommeil', h(23), h(30), 420),
      ])!;
      expect(resume.endormi, const Duration(hours: 7));
    });

    test('nuit puis sieste le même jour : additionnées', () {
      final jours = agregerParJour(
        [
          src(TypeMesure.sommeilLeger, 'mi', h(23), h(30), 420),
          src(TypeMesure.sommeilLeger, 'mi', h(38), h(39), 60),
        ],
        debut: lundi,
        fin: mardi,
      );
      expect(jour(jours, mardi).sommeil!.endormi, const Duration(hours: 8));
    });
  });

  test('nuit de 23 h à 7 h rattachée au jour du lever', () {
    DateTime h(int heures) => lundi.add(Duration(hours: heures));
    final jours = agregerParJour(
      [
        pt(TypeMesure.sommeilProfond, h(23), h(25), 120),
        pt(TypeMesure.sommeilLeger, h(25), h(29), 240),
        pt(TypeMesure.sommeilParadoxal, h(29), h(31), 120),
      ],
      debut: lundi,
      fin: mardi,
    );

    expect(jour(jours, lundi).sommeil, isNull);
    final nuit = jour(jours, mardi).sommeil!;
    expect(nuit.endormi, const Duration(hours: 8));
    expect(nuit.profond, const Duration(hours: 2));
    expect(nuit.leger, const Duration(hours: 4));
    expect(nuit.paradoxal, const Duration(hours: 2));
  });

  test('segments qui se chevauchent comptés une seule fois', () {
    DateTime h(int heures) => mardi.add(Duration(hours: heures));
    final resume = resumerSommeil([
      pt(TypeMesure.sommeilLeger, h(1), h(3), 120),
      pt(TypeMesure.sommeilLeger, h(2), h(4), 120),
    ])!;

    expect(resume.leger, const Duration(hours: 3));
    expect(resume.endormi, const Duration(hours: 3));
  });

  test('sommeil sans phases : durée endormie seule', () {
    DateTime h(int heures) => mardi.add(Duration(hours: heures));
    final resume = resumerSommeil([
      pt(TypeMesure.sommeilEndormi, h(0), h(7), 420),
      pt(
        TypeMesure.sommeilEveil,
        h(3),
        h(3).add(const Duration(minutes: 20)),
        20,
      ),
    ])!;

    expect(resume.endormi, const Duration(hours: 7));
    expect(resume.profond, Duration.zero);
    expect(resume.eveil, const Duration(minutes: 20));
  });

  test('aucun segment : pas de résumé', () {
    expect(resumerSommeil(const []), isNull);
  });

  test('jour sans données : champs nuls et aucune séance', () {
    final j = jour(agregerParJour(const [], debut: lundi, fin: lundi), lundi);
    expect(j.pas, isNull);
    expect(j.kcalTotales, isNull);
    expect(j.sommeil, isNull);
    expect(j.seances, isEmpty);
  });

  test('séance rattachée au jour de son début', () {
    final debut = lundi.add(const Duration(hours: 23));
    final jours = agregerParJour(
      [
        pt(
          TypeMesure.seance,
          debut,
          debut.add(const Duration(minutes: 45)),
          0,
          'Course',
        ),
      ],
      debut: lundi,
      fin: mardi,
    );

    final seance = jour(jours, lundi).seances.single;
    expect(seance.type, 'Course');
    expect(seance.duree, const Duration(minutes: 45));
    expect(seance.kcal, isNull);
    expect(jour(jours, mardi).seances, isEmpty);
  });

  test('course de 45 min écrite par deux applications : une seule séance, '
      'calories actives au prorata', () {
    DateTime h(int heures, [int minutes = 0]) =>
        lundi.add(Duration(hours: heures, minutes: minutes));
    PointSante seance(String source, DateTime debut, DateTime fin) =>
        PointSante(
          type: TypeMesure.seance,
          debut: debut,
          fin: fin,
          valeur: 0,
          libelle: 'RUNNING',
          source: source,
        );
    final jours = agregerParJour(
      [
        seance('autre', h(18, 2), h(18, 44)),
        seance('mi', h(18), h(18, 45)),
        // Calories actives de Mi Fitness, source retenue du jour : 600 sur
        // 17:30-18:30 (dont 30 min dans la séance) et 300 sur 18:30-19:00
        // (dont 15 min).
        src(TypeMesure.kcalActives, 'mi', h(17, 30), h(18, 30), 600),
        src(TypeMesure.kcalActives, 'mi', h(18, 30), h(19), 300),
        src(TypeMesure.kcalActives, 'mi', h(8), h(9), 200),
        // Une autre application, moins complète : ignorée.
        src(TypeMesure.kcalActives, 'autre', h(18), h(18, 45), 900),
        // Des calories totales sur le créneau : jamais dans la séance.
        src(TypeMesure.kcalTotales, 'mi', h(18), h(18, 45), 2000),
      ],
      debut: lundi,
      fin: mardi,
    );

    final seance0 = jour(jours, lundi).seances.single;
    expect(seance0.debut, h(18));
    expect(seance0.duree, const Duration(minutes: 45));
    expect(seance0.kcal, closeTo(300 + 150, 0.01));
  });

  test('deux séances distinctes de deux applications : gardées', () {
    DateTime h(int heures) => lundi.add(Duration(hours: heures));
    final jours = agregerParJour(
      [
        PointSante(
          type: TypeMesure.seance,
          debut: h(7),
          fin: h(8),
          valeur: 0,
          source: 'mi',
        ),
        PointSante(
          type: TypeMesure.seance,
          debut: h(18),
          fin: h(19),
          valeur: 0,
          source: 'autre',
        ),
      ],
      debut: lundi,
      fin: mardi,
    );
    expect(jour(jours, lundi).seances.map((s) => s.debut), [h(7), h(18)]);
  });

  test('mesures triées par date', () {
    final liste = mesures([
      instant(TypeMesure.poids, mardi, 79),
      instant(TypeMesure.poids, lundi, 80),
      instant(TypeMesure.masseGrasse, lundi, 20),
    ], TypeMesure.poids);

    expect(liste.map((m) => m.valeur), [80, 79]);
  });
}
