import 'package:flutter/foundation.dart';

import '../profil/garde_fous.dart';
import '../profil/modele.dart';
import '../sante/modele.dart';

enum SourcePesee { manuel, montre }

/// Une pesée : saisie dans Coach (avec un id Firestore) ou lue dans
/// Health Connect (sans id, non supprimable depuis Coach).
@immutable
class Pesee {
  const Pesee({
    this.id,
    required this.date,
    required this.kg,
    required this.source,
  });

  final String? id;
  final DateTime date;
  final double kg;
  final SourcePesee source;
}

enum CategorieImc { maigreur, normal, surpoids, obesite }

/// Seuils de l'OMS pour l'adulte.
CategorieImc categorieImc(double imc) {
  if (imc < 18.5) return CategorieImc.maigreur;
  if (imc < 25) return CategorieImc.normal;
  if (imc < 30) return CategorieImc.surpoids;
  return CategorieImc.obesite;
}

List<Pesee> fusionnerPesees(List<Pesee> manuelles, List<Mesure> montre) => [
  ...manuelles,
  for (final m in montre)
    Pesee(date: m.date, kg: m.valeur, source: SourcePesee.montre),
]..sort((a, b) => a.date.compareTo(b.date));

/// Écart entre la dernière et la première pesée (liste triée), ou null.
double? ecartDepuisPremiere(List<Pesee> triees) =>
    triees.length < 2 ? null : triees.last.kg - triees.first.kg;

List<Pesee> peseesDepuis(List<Pesee> triees, DateTime debut) => [
  for (final p in triees)
    if (!p.date.isBefore(debut)) p,
];

/// Un point de la tendance du poids.
typedef PointPoids = ({DateTime date, double kg});

/// Moyenne mobile sur [jours] jours : pour chaque pesée (liste triée), la
/// moyenne des pesées de son jour et des [jours] − 1 jours précédents. Lisse
/// les variations d'eau d'un jour à l'autre, qui masquent la tendance.
List<PointPoids> moyenneMobile(List<Pesee> triees, {int jours = 7}) {
  final points = <PointPoids>[];
  var debut = 0;
  var somme = 0.0;
  for (var i = 0; i < triees.length; i++) {
    final d = triees[i].date;
    final limite = DateTime(d.year, d.month, d.day - (jours - 1));
    somme += triees[i].kg;
    while (triees[debut].date.isBefore(limite)) {
      somme -= triees[debut].kg;
      debut++;
    }
    points.add((date: d, kg: somme / (i - debut + 1)));
  }
  return points;
}

/// Ancienneté maximale de la dernière pesée pour projeter le poids.
const ageMaxPeseeProjection = Duration(days: 7);

/// Vrai si la dernière pesée (liste triée) date de [ageMaxPeseeProjection]
/// au plus : partir d'un poids de plusieurs semaines fausserait la projection.
bool peseeRecente(List<Pesee> triees, DateTime maintenant) =>
    triees.isNotEmpty &&
    maintenant.difference(triees.last.date) <= ageMaxPeseeProjection;

/// Profil mis à jour si la pesée est plus récente que celle qu'il connaît
/// (garde-fous réappliqués) ; sinon null.
Profil? profilAvecPesee(
  Profil p, {
  required double kg,
  required DateTime date,
}) {
  if (p.poidsDate != null && !date.isAfter(p.poidsDate!)) return null;
  return appliquerGardeFous(
    p.copyWith(poidsKg: (kg * 10).round() / 10, poidsDate: date),
    maintenant: date,
  );
}

/// Profil recalé sur [derniere] (après suppression d'une pesée plus récente).
Profil profilDepuisDerniere(Profil p, Pesee derniere) => appliquerGardeFous(
  p.copyWith(
    poidsKg: (derniere.kg * 10).round() / 10,
    poidsDate: derniere.date,
  ),
  maintenant: derniere.date,
);
