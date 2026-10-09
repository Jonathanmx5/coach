import 'package:coach/profil/garde_fous.dart';
import 'package:coach/profil/modele.dart';
import 'package:flutter_test/flutter_test.dart';

const base = Profil(
  objectif: Objectif.perte,
  sexe: Sexe.femme,
  anneeNaissance: 1996,
  tailleCm: 170,
  poidsKg: 70,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: {TypeEntrainement.marche},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 30,
  problemeSante: false,
);

void main() {
  test('17 ans est mineur, 18 ans ne l\'est pas', () {
    expect(estMineur(17), isTrue);
    expect(estMineur(18), isFalse);
  });

  test('IMC 18,48 : perte refusée', () {
    expect(
      pertePermise(poidsKg: 53.4, tailleCm: 170, problemeSante: false),
      isFalse,
    );
  });

  test('IMC 18,51 : perte permise', () {
    expect(
      pertePermise(poidsKg: 53.5, tailleCm: 170, problemeSante: false),
      isTrue,
    );
  });

  test('problème de santé : perte refusée', () {
    expect(
      pertePermise(poidsKg: 80, tailleCm: 180, problemeSante: true),
      isFalse,
    );
  });

  test('perte + problème de santé devient forme', () {
    expect(
      appliquerGardeFous(base.copyWith(problemeSante: true)).objectif,
      Objectif.forme,
    );
  });

  test('perte + IMC bas devient forme', () {
    expect(
      appliquerGardeFous(base.copyWith(poidsKg: 50)).objectif,
      Objectif.forme,
    );
  });

  test('muscle + problème de santé reste muscle', () {
    final p = base.copyWith(objectif: Objectif.muscle, problemeSante: true);
    expect(appliquerGardeFous(p), p);
  });

  test('perte avec un profil normal reste perte', () {
    expect(appliquerGardeFous(base), base);
  });
}
