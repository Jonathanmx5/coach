import 'package:coach/recuperation/recuperation.dart';
import 'package:coach/sante/modele.dart';
import 'package:flutter_test/flutter_test.dart';

JourSante nuit(
  int jour, {
  double? heures,
  double profond = 0,
  double? vfc,
  double? fcRepos,
}) => JourSante(
  jour: DateTime(2026, 10, jour),
  variabiliteMs: vfc,
  fcRepos: fcRepos,
  sommeil: heures == null
      ? null
      : ResumeSommeil(
          endormi: Duration(minutes: (heures * 60).round()),
          profond: Duration(minutes: (profond * 60).round()),
          leger: Duration.zero,
          paradoxal: Duration.zero,
          eveil: Duration.zero,
        ),
);

void main() {
  test('aucune donnée : pas de score', () {
    expect(calculerRecuperation(), isNull);
    expect(calculerRecuperation(nuit: nuit(9)), isNull);
  });

  test('sommeil seul : 7 à 9 h = 100, 5,5 h = 50, 4 h = 0', () {
    int score(double h) =>
        calculerRecuperation(nuit: nuit(9, heures: h))!.score;
    expect(score(8), 100);
    expect(score(7), 100);
    expect(score(5.5), 50);
    expect(score(4), 0);
    expect(score(11), 60);
  });

  test('phases : le sommeil profond améliore le score', () {
    final sans = calculerRecuperation(nuit: nuit(9, heures: 7, profond: 0));
    final avec = calculerRecuperation(nuit: nuit(9, heures: 7, profond: 2.5));
    // Les phases à zéro ne comptent pas comme des phases.
    expect(sans!.score, 100);
    expect(avec!.score, 100);
    final mediocre = JourSante(
      jour: DateTime(2026, 10, 9),
      sommeil: const ResumeSommeil(
        endormi: Duration(hours: 7),
        profond: Duration(minutes: 20),
        leger: Duration(hours: 6, minutes: 40),
        paradoxal: Duration.zero,
        eveil: Duration.zero,
      ),
    );
    expect(calculerRecuperation(nuit: mediocre)!.score, lessThan(100));
  });

  test('VFC et FC au repos comparées aux jours précédents', () {
    final precedents = [
      for (var i = 1; i <= 4; i++) nuit(i, vfc: 60, fcRepos: 55),
    ];
    final bonne = calculerRecuperation(
      nuit: nuit(9, heures: 8, vfc: 65, fcRepos: 54),
      precedents: precedents,
    )!;
    final mauvaise = calculerRecuperation(
      nuit: nuit(9, heures: 8, vfc: 36, fcRepos: 62),
      precedents: precedents,
    )!;
    expect(bonne.score, 100);
    expect(mauvaise.score, lessThan(bonne.score));
    expect(mauvaise.niveau, isNot(NiveauRecuperation.bon));
  });

  test('moins de 3 jours de référence : VFC ignorée', () {
    final r = calculerRecuperation(
      nuit: nuit(9, heures: 8, vfc: 10),
      precedents: [nuit(1, vfc: 60), nuit(2, vfc: 60)],
    )!;
    expect(r.score, 100);
  });

  test('ressenti seul et mélangé', () {
    expect(calculerRecuperation(ressenti: ressentiForme)!.score, 90);
    expect(calculerRecuperation(ressenti: ressentiMoyen)!.score, 60);
    final fatigue = calculerRecuperation(ressenti: ressentiFatigue)!;
    expect(fatigue.score, 25);
    expect(fatigue.niveau, NiveauRecuperation.faible);
    // Bonne nuit (100, poids 50) + fatigué (25, poids 30) = 71,9.
    final mixte = calculerRecuperation(
      nuit: nuit(9, heures: 8),
      ressenti: ressentiFatigue,
    )!;
    expect(mixte.score, 72);
  });

  test('niveaux', () {
    expect(niveauDuScore(70), NiveauRecuperation.bon);
    expect(niveauDuScore(69), NiveauRecuperation.moyen);
    expect(niveauDuScore(45), NiveauRecuperation.moyen);
    expect(niveauDuScore(44), NiveauRecuperation.faible);
  });
}
