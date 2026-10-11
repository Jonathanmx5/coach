import 'package:coach/entrainement/catalogue.dart';
import 'package:coach/entrainement/generateur.dart';
import 'package:coach/entrainement/modele.dart';
import 'package:coach/profil/modele.dart';
import 'package:flutter_test/flutter_test.dart';

Profil profil({
  Niveau niveau = Niveau.debutant,
  Objectif objectif = Objectif.forme,
  int duree = 45,
}) => Profil(
  objectif: objectif,
  sexe: Sexe.femme,
  anneeNaissance: 1996,
  tailleCm: 170,
  poidsKg: 65,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: const {TypeEntrainement.maison},
  niveau: niveau,
  joursParSemaine: 3,
  dureeSeanceMin: duree,
  problemeSante: false,
);

void main() {
  test('chaque alternative existe et la chaîne finit au poids du corps', () {
    for (final e in catalogueExercices) {
      final r = resoudre(e, Lieu.maison, const {});
      expect(r, isNotNull, reason: e.id);
      expect(r!.requis, isEmpty, reason: e.id);
      expect(r.salleSeulement, isFalse, reason: e.id);
    }
  });

  test('à la maison sans matériel : aucun exercice à matériel', () {
    for (var n = 0; n < 12; n++) {
      final s = genererRenforcement(
        lieu: Lieu.maison,
        materiel: const {},
        profil: profil(),
        seancesFaites: n,
      );
      expect(s.exercices, isNotEmpty);
      expect(
        s.exercices.every(
          (e) => e.exercice.requis.isEmpty && !e.exercice.salleSeulement,
        ),
        isTrue,
      );
    }
  });

  test('avec des haltères : ils sont utilisés', () {
    final ids = <String>{};
    for (var n = 0; n < 6; n++) {
      ids.addAll(
        genererRenforcement(
          lieu: Lieu.maison,
          materiel: const {Materiel.halteres},
          profil: profil(),
          seancesFaites: n,
        ).exercices.map((e) => e.exercice.id),
      );
    }
    expect(ids, contains('squat_halteres'));
    expect(ids, contains('developpe_halteres'));
  });

  test('en salle : machines autorisées', () {
    final ids = <String>{};
    for (var n = 0; n < 6; n++) {
      ids.addAll(
        genererRenforcement(
          lieu: Lieu.salle,
          materiel: const {},
          profil: profil(),
          seancesFaites: n,
        ).exercices.map((e) => e.exercice.id),
      );
    }
    expect(ids, contains('presse_cuisses'));
  });

  test('les exercices tournent d\'une séance à l\'autre', () {
    List<String> ids(int n) => genererRenforcement(
      lieu: Lieu.maison,
      materiel: const {},
      profil: profil(),
      seancesFaites: n,
    ).exercices.map((e) => e.exercice.id).toList();
    expect(ids(0), isNot(ids(1)));
  });

  test('la durée du profil borne le nombre d\'exercices', () {
    int nb(int duree) => genererRenforcement(
      lieu: Lieu.maison,
      materiel: const {},
      profil: profil(duree: duree),
      seancesFaites: 0,
    ).exercices.length;
    expect(nb(10), 3);
    expect(nb(20), 5);
    expect(nb(60), greaterThan(nb(10)));
    expect(nb(120), lessThanOrEqualTo(6));
  });

  test('progression : répétitions puis séries', () {
    Seance s(int n) => genererRenforcement(
      lieu: Lieu.maison,
      materiel: const {},
      profil: profil(),
      seancesFaites: n,
    );
    int reps(Seance x) => x.exercices.firstWhere((e) => e.reps > 0).reps;
    expect(reps(s(0)), 12);
    expect(reps(s(3)), 13);
    expect(reps(s(30)), 16);
    expect(s(0).exercices.first.series, 2);
    expect(s(30).exercices.first.series, greaterThan(2));
    expect(s(100).exercices.first.series, lessThanOrEqualTo(4));
  });

  test(
    'étapes : échauffement, séries, repos entre les séries, pas à la fin',
    () {
      final s = genererRenforcement(
        lieu: Lieu.maison,
        materiel: const {},
        profil: profil(),
        seancesFaites: 0,
      );
      expect(s.etapes.first.titre, 'Échauffement');
      expect(s.etapes.last.repos, isFalse);
      final efforts = s.etapes.where((e) => !e.repos).length - 1;
      expect(efforts, s.exercices.fold<int>(0, (a, e) => a + e.series));
      expect(s.minutes, inInclusiveRange(15, 60));
    },
  );

  test('course : la semaine monte toutes les 3 séances', () {
    expect(semaineCourse(0, Niveau.debutant), 0);
    expect(semaineCourse(2, Niveau.debutant), 0);
    expect(semaineCourse(3, Niveau.debutant), 1);
    expect(semaineCourse(500, Niveau.debutant), 7);
    expect(semaineCourse(0, Niveau.regulier), 3);
    final s = genererCourse(profil: profil(), seancesFaites: 0);
    expect(s.titre, 'Course · semaine 1');
    expect(s.etapes.where((e) => e.titre.startsWith('Course')).length, 8);
  });

  test('marche : 20 min puis +5 toutes les 3 séances, plafonné à 60', () {
    expect(genererMarche(seancesFaites: 0).minutes, 20);
    expect(genererMarche(seancesFaites: 3).minutes, 25);
    expect(genererMarche(seancesFaites: 300).minutes, 60);
  });
}
