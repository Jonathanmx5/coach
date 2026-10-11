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

  test('beaucoup de sucres : orange puis rouge', () {
    const bonbons = Macros(kcal: 300, proteines: 12, glucides: 60, lipides: 2);
    expect(juger(bonbons, sucres: 18).feu, Feu.orange);
    expect(juger(bonbons, sucres: 40).feu, Feu.rouge);
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

  test('dépasser l\'objectif du jour : rouge ; l\'atteindre : orange', () {
    const repas = Macros(kcal: 600, proteines: 40, glucides: 50, lipides: 15);
    final depasse = juger(repas, dejaMange: const Macros(kcal: 1700));
    expect(depasse.feu, Feu.rouge);
    expect(depasse.points.any((p) => p.contains('dépasserais')), isTrue);
    final atteint = juger(repas, dejaMange: const Macros(kcal: 1450));
    expect(atteint.feu, Feu.orange);
    expect(juger(repas, dejaMange: const Macros(kcal: 500)).feu, Feu.vert);
  });

  test('perte de poids : un repas qui pèse la moitié de la journée', () {
    const gros = Macros(kcal: 950, proteines: 60, glucides: 90, lipides: 30);
    expect(juger(gros, objectif: Objectif.perte).feu, Feu.orange);
    expect(juger(gros).feu, Feu.vert);
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
      sucres: 20,
      satures: 12,
    );
    expect(v.feu, Feu.rouge);
  });

  test('un repas sans calories ne plante pas', () {
    final v = juger(Macros.zero);
    expect(v.points, isNotEmpty);
    expect(v.feu, Feu.vert);
  });
}
