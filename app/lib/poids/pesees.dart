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
  );
}

/// Profil recalé sur [derniere] (après suppression d'une pesée plus récente).
Profil profilDepuisDerniere(Profil p, Pesee derniere) => appliquerGardeFous(
  p.copyWith(
    poidsKg: (derniere.kg * 10).round() / 10,
    poidsDate: derniere.date,
  ),
);
