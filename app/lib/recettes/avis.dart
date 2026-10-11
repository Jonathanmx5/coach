import 'dart:math' as math;

import '../journal/modele.dart';
import '../profil/modele.dart';
import 'catalogue.dart';
import 'modele.dart';

/// Avis donné en balayant une carte : à droite « j'aime, pour une prochaine
/// fois », à gauche « je n'aime pas ».
enum Avis { aime, refuse }

/// Part des recettes refusées qui reviennent quand même dans les idées.
const chanceRefusee = 0.05;

/// Poids d'une recette dans le tirage : de la viande maigre et des protéines
/// pour la prise de muscle, un bon rapport protéines/calories pour la perte.
double affinite(Recette r, Objectif objectif) {
  final part = r.macros.proteines * 4 / r.macros.kcal;
  return switch (objectif) {
    Objectif.muscle => part >= 0.25 ? 1.6 : (part >= 0.18 ? 1.2 : 1.0),
    Objectif.perte => part >= 0.25 ? 1.4 : (r.macros.kcal <= 400 ? 1.2 : 1.0),
    _ => 1.0,
  };
}

/// Idées de repas à proposer, dans l'ordre. Les recettes déjà aimées sont
/// gardées de côté (liste « Mes envies »), les refusées reviennent très
/// rarement ([chanceRefusee]). Le tirage est pondéré par [affinite] et
/// reproductible pour une même [graine].
List<Recette> construireDeck({
  required Map<String, Avis> avis,
  required Objectif objectif,
  required int graine,
  Moment? moment,
  bool vegetarien = false,
}) {
  final rng = math.Random(graine);
  final cles = <Recette, double>{};
  for (final r in catalogueRecettes) {
    if (moment != null && r.moment != moment) continue;
    if (vegetarien && !r.vegetarien) continue;
    final a = avis[r.id];
    if (a == Avis.aime) continue;
    if (a == Avis.refuse && rng.nextDouble() >= chanceRefusee) continue;
    // Tirage pondéré sans remise (Efraimidis-Spirakis).
    cles[r] = math.pow(rng.nextDouble(), 1 / affinite(r, objectif)).toDouble();
  }
  final liste = cles.keys.toList()
    ..sort((a, b) => cles[b]!.compareTo(cles[a]!));
  return liste;
}

List<Recette> recettesAimees(Map<String, Avis> avis) => [
  for (final r in catalogueRecettes)
    if (avis[r.id] == Avis.aime) r,
];
