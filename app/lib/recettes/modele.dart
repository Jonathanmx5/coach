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
