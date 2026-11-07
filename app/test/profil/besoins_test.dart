import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:flutter_test/flutter_test.dart';

final maintenant = DateTime(2026, 10, 9);

Profil profil({
  required Sexe sexe,
  required int age,
  required int tailleCm,
  required double poidsKg,
  required TypeDeVie vie,
  required Objectif objectif,
  Set<Precaution> precautions = const {},
}) => Profil(
  objectif: objectif,
  sexe: sexe,
  anneeNaissance: 2026 - age,
  tailleCm: tailleCm,
  poidsKg: poidsKg,
  typeDeVie: vie,
  typesEntrainement: const {TypeEntrainement.maison},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 30,
  precautions: precautions,
);

Reperes attendu(int base, int maintien, int kcal, int proteines) => Reperes(
  depenseBase: base,
  maintien: maintien,
  kcalCible: kcal,
  proteinesG: proteines,
);

void main() {
  test('perte simple', () {
    final p = profil(
      sexe: Sexe.homme,
      age: 30,
      tailleCm: 180,
      poidsKg: 80,
      vie: TypeDeVie.peuActif,
      objectif: Objectif.perte,
    );
    expect(
      calculerReperes(p, maintenant: maintenant),
      attendu(1780, 2448, 2080, 128),
    );
  });

  test('déficit plafonné à 500 kcal', () {
    final p = profil(
      sexe: Sexe.homme,
      age: 30,
      tailleCm: 180,
      poidsKg: 121,
      vie: TypeDeVie.tresActif,
      objectif: Objectif.perte,
    );
    expect(
      calculerReperes(p, maintenant: maintenant),
      // IMC 37 : protéines sur le poids d'un IMC de 25 (81 kg), pas 194 g.
      attendu(2190, 3778, 3280, 130),
    );
  });

  test('plancher femme à 1200 kcal', () {
    final p = profil(
      sexe: Sexe.femme,
      age: 60,
      tailleCm: 150,
      poidsKg: 45,
      vie: TypeDeVie.sedentaire,
      objectif: Objectif.perte,
    );
    expect(
      calculerReperes(p, maintenant: maintenant),
      attendu(927, 1112, 1200, 72),
    );
  });

  test('prise de muscle +10 %', () {
    final p = profil(
      sexe: Sexe.femme,
      age: 25,
      tailleCm: 165,
      poidsKg: 60,
      vie: TypeDeVie.actif,
      objectif: Objectif.muscle,
    );
    expect(
      calculerReperes(p, maintenant: maintenant),
      attendu(1345, 2085, 2290, 96),
    );
  });

  test('plancher homme à 1500 kcal, objectif forme', () {
    final p = profil(
      sexe: Sexe.homme,
      age: 80,
      tailleCm: 160,
      poidsKg: 50,
      vie: TypeDeVie.sedentaire,
      objectif: Objectif.forme,
    );
    expect(
      calculerReperes(p, maintenant: maintenant),
      attendu(1105, 1326, 1500, 60),
    );
  });

  test('perte suivie par un médecin : déficit limité à 10 %', () {
    final p = profil(
      sexe: Sexe.homme,
      age: 30,
      tailleCm: 180,
      poidsKg: 80,
      vie: TypeDeVie.peuActif,
      objectif: Objectif.perte,
      precautions: {Precaution.perteSuivieMedecin},
    );
    expect(
      calculerReperes(p, maintenant: maintenant),
      attendu(1780, 2448, 2200, 128),
    );
  });

  test('muscle avec un IMC de 39 : recomposition, protéines de référence', () {
    // 175 cm, 120 kg : léger déficit (−10 %) au lieu d'un surplus de 10 %,
    // 2 g de protéines par kg du poids d'un IMC de 25 (76,6 kg).
    final p = profil(
      sexe: Sexe.homme,
      age: 30,
      tailleCm: 175,
      poidsKg: 120,
      vie: TypeDeVie.peuActif,
      objectif: Objectif.muscle,
    );
    expect(estRecomposition(p), isTrue);
    expect(
      calculerReperes(p, maintenant: maintenant),
      attendu(2149, 2955, 2660, 153),
    );
  });

  test('recomposition dès un IMC de 27, pas en dessous', () {
    Profil muscle(double kg) => profil(
      sexe: Sexe.homme,
      age: 30,
      tailleCm: 180,
      poidsKg: kg,
      vie: TypeDeVie.peuActif,
      objectif: Objectif.muscle,
    );
    // IMC 27,0 : déficit léger, protéines à 2 g/kg du poids total (IMC ≤ 30).
    final recompo = calculerReperes(muscle(87.5), maintenant: maintenant);
    expect(estRecomposition(muscle(87.5)), isTrue);
    expect(recompo.kcalCible, lessThan(recompo.maintien));
    expect(recompo.proteinesG, 175);
    // IMC 26,9 : surplus de 10 %, 1,6 g/kg.
    final prise = calculerReperes(muscle(87.1), maintenant: maintenant);
    expect(estRecomposition(muscle(87.1)), isFalse);
    expect(prise.kcalCible, greaterThan(prise.maintien));
    expect(prise.proteinesG, 139);
  });

  test('muscle, IMC 29 et grossesse : ni surplus ni déficit', () {
    final p = profil(
      sexe: Sexe.femme,
      age: 30,
      tailleCm: 165,
      poidsKg: 80,
      vie: TypeDeVie.actif,
      objectif: Objectif.muscle,
      precautions: {Precaution.enceinteOuAllaitante},
    );
    expect(estRecomposition(p), isFalse);
    expect(
      calculerReperes(p, maintenant: maintenant),
      attendu(1520, 2356, 2360, 128),
    );
  });

  test("protéines sur le poids total jusqu'à un IMC de 30", () {
    final p = profil(
      sexe: Sexe.femme,
      age: 30,
      tailleCm: 160,
      poidsKg: 76.8, // IMC 30,0
      vie: TypeDeVie.peuActif,
      objectif: Objectif.perte,
    );
    expect(poidsReferenceProteines(p), 76.8);
    expect(poidsReferenceProteines(p.copyWith(poidsKg: 90)), closeTo(64, 1e-9));
  });

  group('rythme et date estimée', () {
    test('perte simple : environ 0,33 kg par semaine', () {
      final r = attendu(1780, 2448, 2080, 128);
      expect(rythmeKgParSemaine(r), closeTo(-0.3345, 1e-3));
    });

    test('80 kg vers 72 kg : 24 semaines environ', () {
      expect(
        dateEstimee(
          poidsKg: 80,
          poidsCibleKg: 72,
          rythme: -0.3345,
          maintenant: maintenant,
        ),
        DateTime(2027, 3, 26),
      );
    });

    test('sans poids cible, poids stable ou sens contraire : pas de date', () {
      DateTime? date(double? cible, double rythme) => dateEstimee(
        poidsKg: 80,
        poidsCibleKg: cible,
        rythme: rythme,
        maintenant: maintenant,
      );
      expect(date(null, -0.5), isNull);
      expect(date(72, 0), isNull);
      expect(date(85, -0.5), isNull);
      expect(date(80, -0.5), isNull);
      // Plus de trois ans : pas de date.
      expect(date(40, -0.2), isNull);
    });

    test('prise de muscle : date vers un poids plus haut', () {
      expect(
        dateEstimee(
          poidsKg: 60,
          poidsCibleKg: 62,
          rythme: 0.25,
          maintenant: maintenant,
        ),
        DateTime(2026, 10, 9 + 56),
      );
    });
  });

  test('aller-retour toMap / fromMap des repères', () {
    final r = attendu(1780, 2448, 2080, 128);
    expect(Reperes.fromMap(r.toMap()), r);
  });
}
