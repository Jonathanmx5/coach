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

  group('serieSurFenetre', () {
    final debut = DateTime(2026, 10, 2);

    test('identique à serieEnCours dans la fenêtre', () {
      for (final l in [
        [7, 8, 9],
        [5, 6, 8, 9],
        [6, 7, 8],
        [5, 6, 7],
        <int>[],
      ]) {
        expect(
          serieSurFenetre(jours(l), aujourdhui, debut: debut).jours,
          serieEnCours(jours(l), aujourdhui),
        );
      }
    });

    test('tronquée si la série remonte au début de la fenêtre', () {
      final r = serieSurFenetre(
        jours([2, 3, 4, 5, 6, 7, 8, 9]),
        aujourdhui,
        debut: debut,
      );
      expect(r.jours, 8);
      expect(r.tronquee, isTrue);
      expect(
        serieSurFenetre(jours([7, 8, 9]), aujourdhui, debut: debut).tronquee,
        isFalse,
      );
    });

    test('les jours de repos prévus ne coupent pas la série', () {
      // Lundi 5, mercredi 7 et vendredi 9 faits ; mardi et jeudi de repos.
      final r = serieSurFenetre(
        jours([5, 7, 9]),
        aujourdhui,
        debut: debut,
        joursPrevus: {1, 3, 5},
      );
      expect(r.jours, 3);
      // Vendredi 2 (prévu) manqué : la série s'arrête là.
      expect(r.tronquee, isFalse);
      // Un jour prévu manqué (mercredi 7) coupe la série.
      expect(
        serieSurFenetre(
          jours([5, 9]),
          aujourdhui,
          debut: debut,
          joursPrevus: {1, 3, 5},
        ).jours,
        1,
      );
    });
  });
}
