import 'package:flutter/foundation.dart';

import 'modele.dart';

/// Ce qu'on peut corriger à la main sur le total d'un repas analysé.
enum ChampMacro { kcal, proteines, glucides, lipides }

/// Pas d'un bouton + ou − : 10 kcal, ou 1 g.
double pasDe(ChampMacro champ) => champ == ChampMacro.kcal ? 10 : 1;

/// La part [part] (sucres d'une quantité de glucides, saturés d'une quantité
/// de lipides) mise à l'échelle quand cette quantité passe de [avant] à
/// [apres] par une correction à la main ; jamais plus que [apres].
double? partCorrigee(
  double? part, {
  required double avant,
  required double apres,
}) {
  if (part == null) return null;
  final mise = avant > 0 ? part * apres / avant : part;
  return mise > apres ? apres : mise;
}

/// Corrections faites à la main par-dessus les apports estimés d'un repas.
///
/// Les calories suivent les macros (4 kcal par gramme de protéines ou de
/// glucides, 9 par gramme de lipides) ; le champ [kcal] est l'écart propre aux
/// calories, quand on les corrige directement.
@immutable
class Ajustement {
  const Ajustement({
    this.kcal = 0,
    this.proteines = 0,
    this.glucides = 0,
    this.lipides = 0,
  });

  final double kcal;
  final double proteines;
  final double glucides;
  final double lipides;

  /// L'ajustement qui amène [base] à [cible].
  factory Ajustement.entre(Macros cible, Macros base) {
    final p = cible.proteines - base.proteines;
    final g = cible.glucides - base.glucides;
    final l = cible.lipides - base.lipides;
    final k = cible.kcal - base.kcal - 4 * p - 4 * g - 9 * l;
    double propre(double v) => v.abs() < 0.01 ? 0 : v;
    return Ajustement(
      kcal: propre(k),
      proteines: propre(p),
      glucides: propre(g),
      lipides: propre(l),
    );
  }

  /// Sans effet quand rien n'a été corrigé.
  bool get estNul => this == const Ajustement();

  double _kcalTotal(Macros base) =>
      base.kcal + kcal + 4 * proteines + 4 * glucides + 9 * lipides;

  /// Les apports de [base] une fois corrigés (jamais négatifs).
  Macros appliquer(Macros base) {
    double positif(double v) => v < 0 ? 0 : v;
    return Macros(
      kcal: positif(_kcalTotal(base)),
      proteines: positif(base.proteines + proteines),
      glucides: positif(base.glucides + glucides),
      lipides: positif(base.lipides + lipides),
    );
  }

  /// Un cran de plus ([sens] = 1) ou de moins (−1) sur [champ]. Sans effet si
  /// une valeur deviendrait négative.
  Ajustement avec(ChampMacro champ, int sens, Macros base) {
    final pas = sens * pasDe(champ);
    final suivant = Ajustement(
      kcal: kcal + (champ == ChampMacro.kcal ? pas : 0),
      proteines: proteines + (champ == ChampMacro.proteines ? pas : 0),
      glucides: glucides + (champ == ChampMacro.glucides ? pas : 0),
      lipides: lipides + (champ == ChampMacro.lipides ? pas : 0),
    );
    final valide =
        base.proteines + suivant.proteines >= 0 &&
        base.glucides + suivant.glucides >= 0 &&
        base.lipides + suivant.lipides >= 0 &&
        suivant._kcalTotal(base) >= 0;
    return valide ? suivant : this;
  }

  /// Le même ajustement, ramené dans les bornes valides pour [nouvelleBase]
  /// (un aliment décoché, une portion changée) : une baisse ne peut pas
  /// retirer plus que ce que la base contient, et les calories ne passent
  /// jamais sous zéro. Les hausses restent telles quelles.
  Ajustement reborne(Macros nouvelleBase) {
    double borne(double decalage, double base) =>
        decalage < -base ? -base : decalage;
    final p = borne(proteines, nouvelleBase.proteines);
    final g = borne(glucides, nouvelleBase.glucides);
    final l = borne(lipides, nouvelleBase.lipides);
    final k = borne(kcal, nouvelleBase.kcal + 4 * p + 4 * g + 9 * l);
    final suivant = Ajustement(kcal: k, proteines: p, glucides: g, lipides: l);
    return suivant == this ? this : suivant;
  }

  @override
  bool operator ==(Object other) =>
      other is Ajustement &&
      (other.kcal - kcal).abs() < 0.001 &&
      (other.proteines - proteines).abs() < 0.001 &&
      (other.glucides - glucides).abs() < 0.001 &&
      (other.lipides - lipides).abs() < 0.001;

  @override
  int get hashCode => Object.hash(
    kcal.round(),
    proteines.round(),
    glucides.round(),
    lipides.round(),
  );
}
