import 'modele.dart';

/// Garde-fous santé de la spec §3.
const ageMinimum = 18;
const imcMinimumPerte = 18.5;

double imc(double poidsKg, int tailleCm) {
  final metres = tailleCm / 100;
  return poidsKg / (metres * metres);
}

bool estMineur(int age) => age < ageMinimum;

bool pertePermise({
  required double poidsKg,
  required int tailleCm,
  required bool problemeSante,
}) =>
    !problemeSante && imc(poidsKg, tailleCm) >= imcMinimumPerte;

/// Remplace « perdre du poids » par « garder la forme » quand ce n'est pas sûr.
Profil appliquerGardeFous(Profil p) {
  if (p.objectif == Objectif.perte &&
      !pertePermise(
          poidsKg: p.poidsKg,
          tailleCm: p.tailleCm,
          problemeSante: p.problemeSante)) {
    return p.copyWith(objectif: Objectif.forme);
  }
  return p;
}
