import 'package:coach/profil/modele.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profil = Profil(
    objectif: Objectif.perte,
    sexe: Sexe.homme,
    anneeNaissance: 1996,
    tailleCm: 180,
    poidsKg: 80.5,
    typeDeVie: TypeDeVie.peuActif,
    typesEntrainement: {TypeEntrainement.course, TypeEntrainement.salle},
    niveau: Niveau.debutant,
    joursParSemaine: 3,
    dureeSeanceMin: 45,
  );

  test('aller-retour toMap / fromMap', () {
    expect(Profil.fromMap(profil.toMap()), profil);
  });

  test('types d\'entraînement en liste triée par ordre de l\'enum', () {
    expect(profil.toMap()['typesEntrainement'], ['salle', 'course']);
  });

  test('enums enregistrés par leur nom', () {
    expect(profil.toMap()['objectif'], 'perte');
  });

  test('poids entier venant de Firestore accepté', () {
    final m = profil.toMap()..['poidsKg'] = 80;
    expect(Profil.fromMap(m).poidsKg, 80.0);
  });

  test('âge calculé depuis l\'année de naissance', () {
    expect(profil.age(DateTime(2026, 10, 9)), 30);
  });

  test('aller-retour avec montre, application et date de pesée', () {
    final avecMontre = profil.copyWith(
      montre: true,
      appMontre: AppMontre.miFitness,
      poidsDate: DateTime(2026, 10, 1, 7, 30),
    );
    expect(Profil.fromMap(avecMontre.toMap()), avecMontre);
  });

  test('ancien profil sans champs montre : valeurs par défaut', () {
    final ancien = profil.toMap()
      ..remove('montre')
      ..remove('appMontre')
      ..remove('poidsDate');
    final lu = Profil.fromMap(ancien);
    expect(lu.montre, isFalse);
    expect(lu.appMontre, isNull);
    expect(lu.poidsDate, isNull);
  });

  test("copyWith peut effacer l'application de la montre", () {
    final avecMontre = profil.copyWith(
      montre: true,
      appMontre: AppMontre.fitbit,
    );
    final sans = avecMontre.copyWith(montre: false, effacerAppMontre: true);
    expect(sans.appMontre, isNull);
    expect(sans.montre, isFalse);
  });

  test('aller-retour avec précautions et poids visé', () {
    final p = profil.copyWith(
      precautions: {
        Precaution.douleursArticulaires,
        Precaution.perteSuivieMedecin,
      },
      poidsCibleKg: 74.5,
    );
    expect(Profil.fromMap(p.toMap()), p);
    expect(p.toMap()['precautions'], [
      'perteSuivieMedecin',
      'douleursArticulaires',
    ]);
    // Les anciennes versions lisent encore problemeSante (obligatoire).
    expect(p.toMap()['problemeSante'], isFalse);
    expect(
      profil
          .copyWith(precautions: {Precaution.enceinteOuAllaitante})
          .toMap()['problemeSante'],
      isTrue,
    );
  });

  test(
    'ancien profil « problème de santé : oui » : toutes les précautions',
    () {
      final ancien = profil.toMap()
        ..remove('precautions')
        ..remove('poidsCibleKg')
        ..['problemeSante'] = true;
      final lu = Profil.fromMap(ancien);
      expect(lu.santeAPreciser, isTrue);
      expect(lu.precautions, isEmpty);
      expect(lu.perteDeconseillee, isTrue);
      expect(lu.sansImpact, isTrue);
      expect(lu.sansPositionAllongee, isTrue);
      expect(lu.poidsCibleKg, isNull);
      // Réenregistré tel quel, il garde la même prudence.
      expect(Profil.fromMap(lu.toMap()), lu);
      expect(lu.toMap()['problemeSante'], isTrue);
    },
  );

  test('ancien profil « problème de santé : non » : aucune précaution', () {
    final ancien = profil.toMap()..remove('precautions');
    final lu = Profil.fromMap(ancien);
    expect(lu.santeAPreciser, isFalse);
    expect(lu.perteDeconseillee, isFalse);
    expect(lu.sansImpact, isFalse);
  });

  test('précautions : effets de chaque case', () {
    final douleurs = profil.copyWith(
      precautions: {Precaution.douleursArticulaires},
    );
    expect(douleurs.sansImpact, isTrue);
    expect(douleurs.perteDeconseillee, isFalse);
    expect(douleurs.sansPositionAllongee, isFalse);
    final medecin = profil.copyWith(
      precautions: {Precaution.perteSuivieMedecin},
    );
    expect(medecin.sansImpact, isTrue);
    expect(medecin.perteDeconseillee, isFalse);
    final enceinte = profil.copyWith(
      precautions: {Precaution.enceinteOuAllaitante},
    );
    expect(enceinte.perteDeconseillee, isTrue);
    expect(enceinte.sansPositionAllongee, isTrue);
    expect(profil.sansImpact, isFalse);
  });

  test('copyWith peut effacer le poids visé', () {
    final p = profil.copyWith(poidsCibleKg: 70);
    expect(p.copyWith(effacerPoidsCible: true).poidsCibleKg, isNull);
  });
}
