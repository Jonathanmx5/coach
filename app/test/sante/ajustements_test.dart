import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/sante/ajustements.dart';
import 'package:coach/sante/modele.dart';
import 'package:flutter_test/flutter_test.dart';

final aujourdhui = DateTime(2026, 10, 9);

JourSante j(int joursAvant, double? kcal) =>
    JourSante(jour: DateTime(2026, 10, 9 - joursAvant), kcalTotales: kcal);

const perteSimple = Profil(
  objectif: Objectif.perte,
  sexe: Sexe.homme,
  anneeNaissance: 1996,
  tailleCm: 180,
  poidsKg: 80,
  typeDeVie: TypeDeVie.peuActif,
  typesEntrainement: {TypeEntrainement.salle},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 45,
);

void main() {
  test('moyenne des jours mesurés quand il y en a au moins 4', () {
    final jours = [j(1, 2500), j(2, 2700), j(3, 2500), j(4, 2700), j(5, null)];
    expect(
      maintienMesure(jours, aujourdhui: aujourdhui, depenseBase: 1780),
      2600,
    );
  });

  test('moins de 4 jours mesurés : pas de maintien mesuré', () {
    final jours = [j(1, 2500), j(2, 2700), j(3, 2500), j(4, 0)];
    expect(
      maintienMesure(jours, aujourdhui: aujourdhui, depenseBase: 1780),
      isNull,
    );
  });

  test("aujourd'hui (journée partielle) est ignoré", () {
    final jours = [j(0, 500), j(1, 2600), j(2, 2600), j(3, 2600), j(4, 2600)];
    expect(
      maintienMesure(jours, aujourdhui: aujourdhui, depenseBase: 1780),
      2600,
    );
  });

  test('un jour de plus de 7 jours est ignoré', () {
    final jours = [j(1, 2600), j(2, 2600), j(3, 2600), j(8, 2600)];
    expect(
      maintienMesure(jours, aujourdhui: aujourdhui, depenseBase: 1780),
      isNull,
    );
  });

  test('repères calculés avec le maintien mesuré', () {
    final r = calculerReperes(
      perteSimple,
      maintenant: aujourdhui,
      maintienMesure: 3000,
    );
    expect(r.maintien, 3000);
    expect(r.kcalCible, 2550);
    expect(r.source, SourceMaintien.mesure);
  });

  test('sans maintien mesuré : source estimée', () {
    expect(
      calculerReperes(perteSimple, maintenant: aujourdhui).source,
      SourceMaintien.estime,
    );
  });

  test('pesée plus récente que le profil : importée', () {
    final pesees = [
      Mesure(date: DateTime(2026, 10, 1), valeur: 81),
      Mesure(date: DateTime(2026, 10, 8), valeur: 79.4),
    ];
    expect(poidsAImporter(pesees, DateTime(2026, 10, 5))?.valeur, 79.4);
    expect(poidsAImporter(pesees, null)?.valeur, 79.4);
  });

  test('pesée plus ancienne que le profil : ignorée', () {
    final pesees = [Mesure(date: DateTime(2026, 10, 1), valeur: 81)];
    expect(poidsAImporter(pesees, DateTime(2026, 10, 5)), isNull);
    expect(poidsAImporter(const [], null), isNull);
  });

  group('maintien mesuré : journées partielles ou aberrantes', () {
    JourSante mesure(int joursAvant, double kcal, {int heure = 23}) {
      final jour = DateTime(2026, 10, 9 - joursAvant);
      return JourSante(
        jour: jour,
        kcalTotales: kcal,
        derniereMesureKcal: DateTime(jour.year, jour.month, jour.day, heure),
      );
    }

    test('3 jours à 400 kcal (montre en charge) : exclus', () {
      final jours = [
        for (var i = 1; i <= 4; i++) mesure(i, 2600),
        for (var i = 5; i <= 7; i++) mesure(i, 400),
      ];
      expect(
        maintienMesure(jours, aujourdhui: aujourdhui, depenseBase: 1780),
        closeTo(2600, 1e-9),
      );
    });

    test('plus de 3 fois la base : exclu', () {
      final jours = [
        for (var i = 1; i <= 4; i++) mesure(i, 2600),
        mesure(5, 6000),
      ];
      expect(
        maintienMesure(jours, aujourdhui: aujourdhui, depenseBase: 1780),
        2600,
      );
    });

    test('dernière mesure avant 20 h : journée incomplète, exclue', () {
      final jours = [
        for (var i = 1; i <= 3; i++) mesure(i, 2600),
        mesure(4, 2600, heure: 15),
      ];
      expect(
        maintienMesure(jours, aujourdhui: aujourdhui, depenseBase: 1780),
        isNull,
      );
    });

    test('résultat borné entre 1,1 et 2,5 fois la base', () {
      final bas = [for (var i = 1; i <= 4; i++) mesure(i, 1800)];
      expect(
        maintienMesure(bas, aujourdhui: aujourdhui, depenseBase: 1780),
        closeTo(1.1 * 1780, 1e-9),
      );
      final haut = [for (var i = 1; i <= 4; i++) mesure(i, 5000)];
      expect(
        maintienMesure(haut, aujourdhui: aujourdhui, depenseBase: 1780),
        closeTo(2.5 * 1780, 1e-9),
      );
    });

    test('moyenne active des journées valides', () {
      final jours = [
        for (var i = 1; i <= 4; i++)
          JourSante(
            jour: DateTime(2026, 10, 9 - i),
            kcalTotales: 2600,
            kcalActives: 500.0 + 100 * i,
          ),
        JourSante(
          jour: DateTime(2026, 10, 4),
          kcalTotales: 400,
          kcalActives: 50,
        ),
      ];
      expect(
        moyenneActive(jours, aujourdhui: aujourdhui, depenseBase: 1780),
        750,
      );
    });
  });

  group('pesées importées', () {
    test('pesée invraisemblable (12 kg) : ignorée', () {
      final pesees = [Mesure(date: DateTime(2026, 10, 8), valeur: 12)];
      expect(poidsAImporter(pesees, null), isNull);
      expect(
        poidsAImporter([
          Mesure(date: DateTime(2026, 10, 7), valeur: 79),
          ...pesees,
        ], null)?.valeur,
        79,
      );
    });

    test('plus de 3 kg d\'écart en moins de 7 jours : à confirmer', () {
      final pesees = [Mesure(date: DateTime(2026, 10, 8), valeur: 74)];
      final p = poidsAImporter(
        pesees,
        DateTime(2026, 10, 5),
        poidsProfilKg: 80,
      )!;
      expect(p.valeur, 74);
      expect(p.aConfirmer, isTrue);
      expect(
        poidsAImporter(
          pesees,
          DateTime(2026, 9, 20),
          poidsProfilKg: 80,
        )!.aConfirmer,
        isFalse,
      );
      expect(
        poidsAImporter(
          [Mesure(date: DateTime(2026, 10, 8), valeur: 79)],
          DateTime(2026, 10, 5),
          poidsProfilKg: 80,
        )!.aConfirmer,
        isFalse,
      );
    });

    test('profil après import : garde-fous appliqués (IMC 18,3, perte → '
        'forme)', () {
      const femme = Profil(
        objectif: Objectif.perte,
        sexe: Sexe.femme,
        anneeNaissance: 1996,
        tailleCm: 170,
        poidsKg: 56,
        typeDeVie: TypeDeVie.peuActif,
        typesEntrainement: {TypeEntrainement.salle},
        niveau: Niveau.debutant,
        joursParSemaine: 3,
        dureeSeanceMin: 45,
      );
      final p = profilApresImport(
        femme,
        Mesure(date: DateTime(2026, 10, 8, 7), valeur: 52.94),
      );
      expect(p.poidsKg, 52.9);
      expect(p.poidsDate, DateTime(2026, 10, 8, 7));
      expect(p.objectif, Objectif.forme);

      expect(
        profilApresImport(
          femme,
          Mesure(date: DateTime(2026, 10, 8), valeur: 55),
        ).objectif,
        Objectif.perte,
      );
    });
  });
}
