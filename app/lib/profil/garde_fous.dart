import 'modele.dart';

/// Garde-fous santé de la spec §3.
const ageMinimum = 18;
const imcMinimumPerte = 18.5;

double imc(double poidsKg, int tailleCm) {
  final metres = tailleCm / 100;
  return poidsKg / (metres * metres);
}

bool estMineur(int age) => age < ageMinimum;

/// Apport quotidien sous lequel la cible ne descend jamais.
double plancherKcal(Sexe sexe) => sexe == Sexe.femme ? 1200.0 : 1500.0;

/// Facteurs d'activité du quotidien HORS SPORT : les séances et activités
/// saisies s'ajoutent à part (calories nettes), une seule fois.
const facteursTypeDeVie = {
  TypeDeVie.sedentaire: 1.2,
  TypeDeVie.peuActif: 1.375,
  TypeDeVie.actif: 1.55,
  TypeDeVie.tresActif: 1.725,
};

/// Métabolisme de base (Mifflin-St Jeor), en kcal par jour.
double baseMifflin({
  required Sexe sexe,
  required int age,
  required int tailleCm,
  required double poidsKg,
}) =>
    10 * poidsKg + 6.25 * tailleCm - 5 * age + (sexe == Sexe.homme ? 5 : -161);

double metabolismeBase(Profil p, DateTime maintenant) => baseMifflin(
  sexe: p.sexe,
  age: p.age(maintenant),
  tailleCm: p.tailleCm,
  poidsKg: p.poidsKg,
);

/// Maintien estimé d'après le type de vie (hors sport).
double maintienEstime(Profil p, DateTime maintenant) =>
    metabolismeBase(p, maintenant) * facteursTypeDeVie[p.typeDeVie]!;

/// Vrai si le plancher calorique atteint ou dépasse le maintien estimé :
/// aucun déficit n'est alors possible.
bool plancherAuDessusDuMaintien({
  required Sexe sexe,
  required int age,
  required int tailleCm,
  required double poidsKg,
  required TypeDeVie typeDeVie,
}) =>
    plancherKcal(sexe) >=
    baseMifflin(sexe: sexe, age: age, tailleCm: tailleCm, poidsKg: poidsKg) *
        facteursTypeDeVie[typeDeVie]!;

/// Pourquoi l'objectif « perdre du poids » est refusé.
enum RefusPerte {
  /// Grossesse, allaitement ou ancienne réponse « problème de santé ».
  sante,

  /// IMC déjà sous 18,5.
  imcBas,

  /// Le plancher calorique atteint ou dépasse le maintien : toute cible
  /// « perte » serait en réalité un excédent.
  plancher,
}

/// Raison de refuser la perte pour ce profil, ou null si elle est permise.
RefusPerte? refusPerte(Profil p, {required DateTime maintenant}) {
  if (p.perteDeconseillee) return RefusPerte.sante;
  if (imc(p.poidsKg, p.tailleCm) < imcMinimumPerte) return RefusPerte.imcBas;
  if (plancherAuDessusDuMaintien(
    sexe: p.sexe,
    age: p.age(maintenant),
    tailleCm: p.tailleCm,
    poidsKg: p.poidsKg,
    typeDeVie: p.typeDeVie,
  )) {
    return RefusPerte.plancher;
  }
  return null;
}

/// Remplace « perdre du poids » par « garder la forme » quand ce n'est pas sûr.
Profil appliquerGardeFous(Profil p, {required DateTime maintenant}) {
  if (p.objectif == Objectif.perte &&
      refusPerte(p, maintenant: maintenant) != null) {
    return p.copyWith(objectif: Objectif.forme);
  }
  return p;
}
