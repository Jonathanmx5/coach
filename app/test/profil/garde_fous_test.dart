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
);

final maintenant = DateTime(2026, 10, 9);

void main() {
  test('17 ans est mineur, 18 ans ne l\'est pas', () {
    expect(estMineur(17), isTrue);
    expect(estMineur(18), isFalse);
  });

  test('IMC 18,48 : perte refusée', () {
    expect(
      refusPerte(base.copyWith(poidsKg: 53.4), maintenant: maintenant),
      RefusPerte.imcBas,
    );
  });

  test('IMC 18,51 : perte permise', () {
    expect(
      refusPerte(base.copyWith(poidsKg: 53.5), maintenant: maintenant),
      isNull,
    );
  });

  test('enceinte ou allaitante : perte refusée', () {
    final p = base.copyWith(precautions: {Precaution.enceinteOuAllaitante});
    expect(refusPerte(p, maintenant: maintenant), RefusPerte.sante);
    expect(
      appliquerGardeFous(p, maintenant: maintenant).objectif,
      Objectif.forme,
    );
  });

  test('perte suivie par un médecin ou douleurs : perte permise', () {
    for (final c in [
      Precaution.perteSuivieMedecin,
      Precaution.douleursArticulaires,
    ]) {
      final p = base.copyWith(precautions: {c});
      expect(appliquerGardeFous(p, maintenant: maintenant), p, reason: '$c');
    }
  });

  test('ancienne réponse « problème de santé » : perte refusée', () {
    final p = base.copyWith(santeAPreciser: true);
    expect(refusPerte(p, maintenant: maintenant), RefusPerte.sante);
    expect(
      appliquerGardeFous(p, maintenant: maintenant).objectif,
      Objectif.forme,
    );
  });

  test('perte + IMC bas devient forme', () {
    expect(
      appliquerGardeFous(
        base.copyWith(poidsKg: 50),
        maintenant: maintenant,
      ).objectif,
      Objectif.forme,
    );
  });

  test('plancher au-dessus du maintien : perte refusée', () {
    // Femme de 60 ans, 150 cm, 45 kg, sédentaire : maintien 1112 kcal,
    // plancher 1200. Une « perte » serait un excédent.
    final p = base.copyWith(
      anneeNaissance: 1966,
      tailleCm: 150,
      poidsKg: 45,
      typeDeVie: TypeDeVie.sedentaire,
    );
    expect(maintienEstime(p, maintenant).round(), 1112);
    expect(refusPerte(p, maintenant: maintenant), RefusPerte.plancher);
    expect(
      appliquerGardeFous(p, maintenant: maintenant).objectif,
      Objectif.forme,
    );
    // Même gabarit mais un peu actif : maintien 1274, la perte reste permise.
    expect(
      refusPerte(
        p.copyWith(typeDeVie: TypeDeVie.peuActif),
        maintenant: maintenant,
      ),
      isNull,
    );
  });

  test('muscle + grossesse reste muscle', () {
    final p = base.copyWith(
      objectif: Objectif.muscle,
      precautions: {Precaution.enceinteOuAllaitante},
    );
    expect(appliquerGardeFous(p, maintenant: maintenant), p);
  });

  test('perte avec un profil normal reste perte', () {
    expect(appliquerGardeFous(base, maintenant: maintenant), base);
  });
}
