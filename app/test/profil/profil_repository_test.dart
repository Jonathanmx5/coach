import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const profil = Profil(
  objectif: Objectif.muscle,
  sexe: Sexe.femme,
  anneeNaissance: 2000,
  tailleCm: 165,
  poidsKg: 60.5,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: {TypeEntrainement.maison},
  niveau: Niveau.reprise,
  joursParSemaine: 4,
  dureeSeanceMin: 30,
  problemeSante: false,
);

const reperes =
    Reperes(depenseBase: 1345, maintien: 2085, kcalCible: 2290, proteinesG: 97);

void main() {
  test('enregistrer puis observer renvoie le profil et les repères', () async {
    final db = FakeFirebaseFirestore();
    final depot = FirestoreProfilRepository(db);

    await depot.enregistrer('u1', profil, reperes);
    final lu = await depot.observer('u1').first;

    expect(lu?.profil, profil);
    expect(lu?.reperes, reperes);
    final brut = (await db.doc('users/u1').get()).data()!;
    expect(brut['schema'], 1);
  });

  test('document absent : null', () async {
    final depot = FirestoreProfilRepository(FakeFirebaseFirestore());
    expect(await depot.observer('inconnu').first, isNull);
  });
}
