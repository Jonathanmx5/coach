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

void main() {
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

  test('FC moyenne : moyenne ; FC au repos : dernière valeur du jour', () {
    final jours = agregerParJour(
      [
        instant(TypeMesure.fc, lundi.add(const Duration(hours: 8)), 60),
        instant(TypeMesure.fc, lundi.add(const Duration(hours: 9)), 80),
        instant(TypeMesure.fcRepos, lundi.add(const Duration(hours: 6)), 58),
        instant(TypeMesure.fcRepos, lundi.add(const Duration(hours: 22)), 55),
      ],
      debut: lundi,
      fin: lundi,
    );

    expect(jour(jours, lundi).fcMoyenne, 70);
    expect(jour(jours, lundi).fcRepos, 55);
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
    final debut = lundi.add(const Duration(hours: 23, minutes: 30));
    final jours = agregerParJour(
      [
        pt(
          TypeMesure.seance,
          debut,
          debut.add(const Duration(hours: 1)),
          320,
          'Course',
        ),
      ],
      debut: lundi,
      fin: mardi,
    );

    final seance = jour(jours, lundi).seances.single;
    expect(seance.type, 'Course');
    expect(seance.duree, const Duration(hours: 1));
    expect(seance.kcal, 320);
    expect(jour(jours, mardi).seances, isEmpty);
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
