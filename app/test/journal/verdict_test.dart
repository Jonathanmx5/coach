import 'package:coach/journal/calculs.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/journal/verdict.dart';
import 'package:coach/profil/modele.dart';
import 'package:flutter_test/flutter_test.dart';

const cibles = CiblesJour(
  kcal: 2000,
  proteines: 140,
  glucides: 220,
  lipides: 60,
);

Verdict juger(
  Macros repas, {
  double? sucres,
  double? satures,
  Macros dejaMange = Macros.zero,
  Objectif objectif = Objectif.muscle,
}) => verdictRepas(
  repas: repas,
  sucres: sucres,
  satures: satures,
  dejaMange: dejaMange,
  cibles: cibles,
  objectif: objectif,
);

void main() {
  test('le gâteau de semoule protéiné : carton vert', () {
    // La moitié d'un pot de 500 g : 202 kcal, 20 g de protéines.
    final v = juger(
      const Macros(kcal: 202, proteines: 20, glucides: 22, lipides: 3.75),
      sucres: 11.5,
      satures: 2.5,
    );
    expect(v.feu, Feu.vert);
    expect(v.points.first, contains('20 g de protéines pour 202 kcal'));
    expect(v.points.any((p) => p.contains('dont 12 g de sucres')), isTrue);
    expect(v.conclusion, contains('prise de muscle'));
  });

  test('sucres totaux : vert sous 25 g, orange au-delà, rouge dès 45 g', () {
    const bol = Macros(kcal: 300, proteines: 12, glucides: 60, lipides: 2);
    // Un fruit et un yaourt : des sucres, mais pas de quoi s'inquiéter.
    expect(juger(bol, sucres: 20).feu, Feu.vert);
    expect(juger(bol, sucres: seuilSucres).feu, Feu.orange);
    expect(juger(bol, sucres: 40).feu, Feu.orange);
    expect(juger(bol, sucres: seuilSucresCritique).feu, Feu.rouge);
  });

  test('peu de protéines pour beaucoup de calories : orange', () {
    final v = juger(
      const Macros(kcal: 400, proteines: 4, glucides: 50, lipides: 10),
    );
    expect(v.feu, Feu.orange);
    expect(
      v.points.any((p) => p.contains('Seulement 4 g de protéines')),
      isTrue,
    );
  });

  group('budget du jour, à part de la couleur', () {
    const repas = Macros(kcal: 600, proteines: 40, glucides: 50, lipides: 15);

    test('ce qu\'il reste : une phrase à part, la couleur ne change pas', () {
      final v = juger(
        repas,
        dejaMange: const Macros(kcal: 500),
        objectif: Objectif.perte,
      );
      expect(v.feu, Feu.vert);
      expect(v.budget, 'Il te reste 900 kcal pour la journée avec ce repas.');
      expect(v.points.any((p) => p.contains('kcal pour la journée')), isFalse);
    });

    test(
      'dépassement : un repas équilibré reste vert, jamais « à éviter »',
      () {
        for (final objectif in Objectif.values) {
          final v = juger(
            repas,
            dejaMange: const Macros(kcal: 1700),
            objectif: objectif,
          );
          expect(v.feu, Feu.vert, reason: '$objectif');
          expect(v.budget, startsWith('Tu dépasses de 300 kcal'));
          expect(v.conclusion, isNot(contains('éviter')));
        }
      },
    );

    test('prise de muscle : le dépassement n\'est pas un reproche', () {
      final muscle = juger(repas, dejaMange: const Macros(kcal: 1700));
      expect(muscle.budget, contains('ce n\'est pas un problème'));
      expect(muscle.budget, isNot(contains('Allège')));
      final perte = juger(
        repas,
        dejaMange: const Macros(kcal: 1700),
        objectif: Objectif.perte,
      );
      expect(perte.budget, contains('Allège un peu les prochains repas'));
    });

    test('objectif atteint pile : il reste 0 kcal', () {
      final v = juger(repas, dejaMange: const Macros(kcal: 1400));
      expect(v.budget, startsWith('Il te reste 0 kcal'));
    });

    test('sans objectif calorique : pas de phrase de budget', () {
      final v = verdictRepas(
        repas: repas,
        dejaMange: Macros.zero,
        cibles: const CiblesJour(
          kcal: 0,
          proteines: 0,
          glucides: 0,
          lipides: 0,
        ),
        objectif: Objectif.forme,
      );
      expect(v.budget, isNull);
    });

    test('gardé avec le repas, absent des anciens repas', () {
      final v = juger(repas, dejaMange: const Macros(kcal: 1700));
      expect(Verdict.fromMap(v.toMap()).budget, v.budget);
      final ancien = Verdict.fromMap({
        'feu': 'vert',
        'points': ['ok'],
        'conclusion': 'bien',
      });
      expect(ancien.budget, isNull);
      expect(ancien.toMap().containsKey('budget'), isFalse);
    });
  });

  test('perte de poids : un repas qui pèse la moitié de la journée', () {
    const gros = Macros(kcal: 950, proteines: 60, glucides: 90, lipides: 30);
    final perte = juger(gros, objectif: Objectif.perte);
    // La couleur ne juge que la composition ; la remarque va au budget.
    expect(perte.feu, Feu.vert);
    expect(perte.budget, contains('près de la moitié de ta journée'));
    expect(juger(gros).budget, isNot(contains('moitié')));
  });

  test('graisses saturées et repas très gras : avertissements', () {
    final v = juger(
      const Macros(kcal: 500, proteines: 25, glucides: 10, lipides: 40),
      satures: 15,
    );
    expect(v.feu, isNot(Feu.vert));
    expect(v.points.any((p) => p.contains('saturées')), isTrue);
    expect(v.points.any((p) => p.contains('très gras')), isTrue);
  });

  test('trois avertissements : rouge', () {
    final v = juger(
      const Macros(kcal: 520, proteines: 3, glucides: 70, lipides: 25),
      sucres: 30,
      satures: 12,
    );
    expect(v.feu, Feu.rouge);
  });

  test('un repas sans calories ne plante pas', () {
    final v = juger(Macros.zero);
    expect(v.feu, Feu.vert);
    expect(v.budget, 'Il te reste 2000 kcal pour la journée avec ce repas.');
  });
}
