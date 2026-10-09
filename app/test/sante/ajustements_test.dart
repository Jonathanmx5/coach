import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/sante/ajustements.dart';
import 'package:coach/sante/modele.dart';
import 'package:flutter_test/flutter_test.dart';

final aujourdhui = DateTime(2026, 10, 9);

JourSante j(int joursAvant, double? kcal) => JourSante(
  jour: DateTime(2026, 10, 9 - joursAvant),
  kcalTotales: kcal,
);

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
  problemeSante: false,
);

void main() {
  test('moyenne des jours mesurés quand il y en a au moins 4', () {
    final jours = [j(1, 2500), j(2, 2700), j(3, 2500), j(4, 2700), j(5, null)];
    expect(maintienMesure(jours, aujourdhui: aujourdhui), 2600);
  });

  test('moins de 4 jours mesurés : pas de maintien mesuré', () {
    final jours = [j(1, 2500), j(2, 2700), j(3, 2500), j(4, 0)];
    expect(maintienMesure(jours, aujourdhui: aujourdhui), isNull);
  });

  test("aujourd'hui (journée partielle) est ignoré", () {
    final jours = [j(0, 500), j(1, 2600), j(2, 2600), j(3, 2600), j(4, 2600)];
    expect(maintienMesure(jours, aujourdhui: aujourdhui), 2600);
  });

  test('un jour de plus de 7 jours est ignoré', () {
    final jours = [j(1, 2600), j(2, 2600), j(3, 2600), j(8, 2600)];
    expect(maintienMesure(jours, aujourdhui: aujourdhui), isNull);
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
}
