import 'package:coach/bienetre/hydratation.dart';
import 'package:coach/bienetre/series.dart';
import 'package:flutter_test/flutter_test.dart';

Set<DateTime> jours(List<int> l) => {for (final j in l) DateTime(2026, 10, j)};

void main() {
  final aujourdhui = DateTime(2026, 10, 9, 20);

  test('série en cours : jours consécutifs jusqu\'à aujourd\'hui', () {
    expect(serieEnCours(jours([7, 8, 9]), aujourdhui), 3);
    expect(serieEnCours(jours([5, 6, 8, 9]), aujourdhui), 2);
  });

  test('aujourd\'hui pas encore fait : la série d\'hier reste vivante', () {
    expect(serieEnCours(jours([6, 7, 8]), aujourdhui), 3);
  });

  test('hier manquant : retombe à 0', () {
    expect(serieEnCours(jours([5, 6, 7]), aujourdhui), 0);
    expect(serieEnCours({}, aujourdhui), 0);
  });

  test('traverse un changement de mois', () {
    final jours = {
      DateTime(2026, 9, 29),
      DateTime(2026, 9, 30),
      DateTime(2026, 10, 1),
    };
    expect(serieEnCours(jours, DateTime(2026, 10, 1, 8)), 3);
  });

  test('joursDe ignore l\'heure', () {
    expect(joursDe([DateTime(2026, 10, 9, 8), DateTime(2026, 10, 9, 22)]), {
      DateTime(2026, 10, 9),
    });
  });

  test('eau atteinte : somme par jour', () {
    final jours = joursEauAtteinte([
      EntreeEau(date: DateTime(2026, 10, 8, 9), ml: 1000),
      EntreeEau(date: DateTime(2026, 10, 8, 18), ml: 1000),
      EntreeEau(date: DateTime(2026, 10, 9, 9), ml: 1500),
    ], 2000);
    expect(jours, {DateTime(2026, 10, 8)});
  });
}
