import 'package:coach/poids/pesees.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/sante/modele.dart';
import 'package:flutter_test/flutter_test.dart';

const profil = Profil(
  objectif: Objectif.perte,
  sexe: Sexe.femme,
  anneeNaissance: 1990,
  tailleCm: 170,
  poidsKg: 60,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: {TypeEntrainement.marche},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 30,
  problemeSante: false,
);

Pesee manuelle(int jour, double kg) => Pesee(
  id: 'm$jour',
  date: DateTime(2026, 10, jour),
  kg: kg,
  source: SourcePesee.manuel,
);

void main() {
  group('catégories d\'IMC aux seuils exacts', () {
    test('18,4 maigreur ; 18,5 normal', () {
      expect(categorieImc(18.4), CategorieImc.maigreur);
      expect(categorieImc(18.5), CategorieImc.normal);
    });
    test('24,9 normal ; 25 surpoids', () {
      expect(categorieImc(24.9), CategorieImc.normal);
      expect(categorieImc(25), CategorieImc.surpoids);
    });
    test('29,9 surpoids ; 30 obésité', () {
      expect(categorieImc(29.9), CategorieImc.surpoids);
      expect(categorieImc(30), CategorieImc.obesite);
    });
  });

  test('fusion des saisies et de la montre, triées par date', () {
    final toutes = fusionnerPesees(
      [manuelle(5, 61), manuelle(1, 62)],
      [Mesure(date: DateTime(2026, 10, 3), valeur: 61.5)],
    );
    expect(toutes.map((p) => p.kg), [62, 61.5, 61]);
    expect(toutes[1].source, SourcePesee.montre);
    expect(toutes[1].id, isNull);
  });

  test('écart depuis la première pesée', () {
    expect(
      ecartDepuisPremiere([manuelle(1, 62), manuelle(5, 59.7)]),
      closeTo(-2.3, 1e-9),
    );
    expect(ecartDepuisPremiere([manuelle(1, 62)]), isNull);
  });

  test('pesées de la période', () {
    final liste = [manuelle(1, 62), manuelle(5, 61), manuelle(9, 60)];
    expect(peseesDepuis(liste, DateTime(2026, 10, 5)).map((p) => p.kg), [
      61,
      60,
    ]);
  });

  test('pesée plus récente : profil mis à jour', () {
    final p = profilAvecPesee(
      profil.copyWith(poidsDate: DateTime(2026, 10, 1)),
      kg: 61.2,
      date: DateTime(2026, 10, 5),
    )!;
    expect(p.poidsKg, 61.2);
    expect(p.poidsDate, DateTime(2026, 10, 5));
  });

  test('pesée plus ancienne que le profil : rien à faire', () {
    expect(
      profilAvecPesee(
        profil.copyWith(poidsDate: DateTime(2026, 10, 5)),
        kg: 61,
        date: DateTime(2026, 10, 1),
      ),
      isNull,
    );
  });

  test('pesée qui fait passer sous 18,5 : objectif perte remplacé', () {
    final p = profilAvecPesee(profil, kg: 52, date: DateTime(2026, 10, 5))!;
    expect(p.objectif, Objectif.forme);
  });

  test('suppression de la dernière pesée : profil ramené à la précédente', () {
    final p = profilDepuisDerniere(
      profil.copyWith(poidsKg: 59, poidsDate: DateTime(2026, 10, 9)),
      manuelle(5, 61.04),
    );
    expect(p.poidsKg, 61.0);
    expect(p.poidsDate, DateTime(2026, 10, 5));
  });

  group('tendance : moyenne mobile sur 7 jours', () {
    test('chaque point moyenne les pesées des 7 derniers jours', () {
      final points = moyenneMobile([
        manuelle(1, 70),
        manuelle(3, 72),
        manuelle(7, 71),
        // Le 1er sort de la fenêtre du 8 (du 2 au 8).
        manuelle(8, 69),
      ]);
      expect([for (final p in points) p.date.day], [1, 3, 7, 8]);
      expect(points[0].kg, 70);
      expect(points[1].kg, closeTo(71, 1e-9));
      expect(points[2].kg, closeTo(71, 1e-9));
      expect(points[3].kg, closeTo((72 + 71 + 69) / 3, 1e-9));
    });

    test("un pic d'un jour est lissé", () {
      final points = moyenneMobile([
        for (var j = 1; j <= 6; j++) manuelle(j, 70),
        manuelle(7, 73.5),
      ]);
      expect(points.last.kg, closeTo(70.5, 1e-9));
    });

    test('aucune pesée : aucun point', () {
      expect(moyenneMobile(const []), isEmpty);
    });
  });

  group('projection : dernière pesée récente', () {
    final maintenant = DateTime(2026, 10, 9, 20);
    test('7 jours au plus : la projection peut partir', () {
      expect(peseeRecente([manuelle(3, 70)], maintenant), isTrue);
    });
    test('plus de 7 jours : pas de projection', () {
      expect(
        peseeRecente([manuelle(1, 70), manuelle(2, 70)], maintenant),
        isFalse,
      );
    });
    test('aucune pesée', () {
      expect(peseeRecente(const [], maintenant), isFalse);
    });
  });
}
