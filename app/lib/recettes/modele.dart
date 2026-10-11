import 'package:flutter/foundation.dart';

import '../journal/modele.dart';

/// Rayons d'un magasin, dans l'ordre où on les parcourt.
enum Rayon {
  fruitsLegumes,
  boulangerie,
  viandePoisson,
  cremerieOeufs,
  epicerie,
}

enum Unite { g, ml, piece }

@immutable
class Ingredient {
  const Ingredient(this.nom, this.quantite, this.unite, this.rayon);

  final String nom;

  /// Pour une portion de la recette.
  final double quantite;
  final Unite unite;
  final Rayon rayon;
}

@immutable
class Recette {
  const Recette({
    required this.id,
    required this.nom,
    required this.moment,
    required this.minutes,
    required this.macros,
    required this.ingredients,
    required this.etapes,
    this.vegetarien = false,
  });

  final String id;
  final String nom;
  final Moment moment;

  /// Préparation + cuisson.
  final int minutes;

  /// Pour une portion.
  final Macros macros;
  final List<Ingredient> ingredients;
  final List<String> etapes;

  /// Sans viande ni poisson.
  final bool vegetarien;
}

/// Critères « fitness et remise en forme » : au moins 16 % des calories en
/// protéines et au plus 42 % en lipides. Tout le catalogue les respecte (un
/// test le vérifie) : l'application ne propose que ce type de recettes.
bool recetteAdapteeFitness(Recette r) {
  final m = r.macros;
  return m.proteines * 4 / m.kcal >= 0.16 && m.lipides * 9 / m.kcal <= 0.42;
}
