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
  problemeSante: false,
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
      attendu(2190, 3778, 3280, 194),
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

  test('aller-retour toMap / fromMap des repères', () {
    final r = attendu(1780, 2448, 2080, 128);
    expect(Reperes.fromMap(r.toMap()), r);
  });
}
