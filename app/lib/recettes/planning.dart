import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../journal/modele.dart';
import 'avis.dart';
import 'catalogue.dart';
import 'modele.dart';

@immutable
class RepasPlanifie {
  const RepasPlanifie(this.recetteId, this.portions);

  final String recetteId;
  final double portions;
}

/// Repas prévus pour une semaine (du lundi au dimanche) et articles déjà
/// cochés dans la liste de courses.
@immutable
class Planning {
  const Planning({
    required this.lundi,
    required this.jours,
    this.vegetarien = false,
    this.coches = const {},
  });

  final DateTime lundi;

  /// Jour 0 = lundi.
  final Map<int, Map<Moment, RepasPlanifie>> jours;
  final bool vegetarien;
  final Set<String> coches;

  Planning avecRepas(int jour, Moment moment, RepasPlanifie repas) => Planning(
    lundi: lundi,
    vegetarien: vegetarien,
    coches: coches,
    jours: {
      for (final e in jours.entries) e.key: {...e.value},
      jour: {...?jours[jour], moment: repas},
    },
  );

  Planning avecCoche(String cle, bool coche) => Planning(
    lundi: lundi,
    vegetarien: vegetarien,
    jours: jours,
    coches: coche ? {...coches, cle} : ({...coches}..remove(cle)),
  );

  Map<String, Object?> toMap() => {
    'vegetarien': vegetarien,
    'coches': coches.toList(),
    'repas': {
      for (final j in jours.entries)
        '${j.key}': {
          for (final m in j.value.entries)
            m.key.name: {'id': m.value.recetteId, 'p': m.value.portions},
        },
    },
  };

  static Planning fromMap(DateTime lundi, Map<String, Object?> m) {
    final jours = <int, Map<Moment, RepasPlanifie>>{};
    final repas = (m['repas'] as Map?) ?? const {};
    for (final j in repas.entries) {
      final index = int.tryParse('${j.key}');
      if (index == null) continue;
      final moments = <Moment, RepasPlanifie>{};
      for (final r in (j.value as Map).entries) {
        final moment = Moment.values.asNameMap()['${r.key}'];
        final id = (r.value as Map)['id'] as String?;
        if (moment == null || id == null || recetteOuNull(id) == null) continue;
        moments[moment] = RepasPlanifie(
          id,
          ((r.value as Map)['p'] as num?)?.toDouble() ?? 1,
        );
      }
      jours[index] = moments;
    }
    return Planning(
      lundi: lundi,
      jours: jours,
      vegetarien: m['vegetarien'] == true,
      coches: {...?(m['coches'] as List?)?.cast<String>()},
    );
  }
}

DateTime lundiDe(DateTime t) =>
    DateTime(t.year, t.month, t.day - (t.weekday - 1));

/// Part des calories du jour par repas.
const partsDuJour = {
  Moment.petitDejeuner: 0.25,
  Moment.dejeuner: 0.35,
  Moment.diner: 0.30,
  Moment.collation: 0.10,
};

/// Portions pour approcher [kcalVisees] : de 0,5 à 2, par pas de 0,25.
double portionsPour(Recette r, double kcalVisees) {
  final brut = (kcalVisees / r.macros.kcal).clamp(0.5, 2.0);
  return (brut * 4).round() / 4;
}

List<Recette> recettesPour(Moment moment, {required bool vegetarien}) => [
  for (final r in catalogueRecettes)
    if (r.moment == moment && (!vegetarien || r.vegetarien)) r,
];

/// Recettes d'un moment pour le planning : les refusées sont écartées (tant
/// qu'il en reste au moins deux autres) et les aimées reviennent plus souvent,
/// intercalées entre les autres.
List<Recette> recettesSelonAvis(
  Moment moment, {
  required bool vegetarien,
  required Map<String, Avis> avis,
}) {
  final toutes = recettesPour(moment, vegetarien: vegetarien);
  final sansRefus = [
    for (final r in toutes)
      if (avis[r.id] != Avis.refuse) r,
  ];
  final base = sansRefus.length >= 2 ? sansRefus : toutes;
  final aimees = [
    for (final r in base)
      if (avis[r.id] == Avis.aime) r,
  ];
  final autres = [
    for (final r in base)
      if (avis[r.id] != Avis.aime) r,
  ];
  if (aimees.isEmpty || autres.length < 2) return base;
  final liste = <Recette>[];
  for (var i = 0; i < autres.length; i++) {
    liste.add(autres[i]);
    if (i.isOdd) liste.add(aimees[(i ~/ 2) % aimees.length]);
  }
  return liste;
}

/// Une semaine de repas qui vise [kcalCible] par jour. Les recettes tournent
/// d'un jour à l'autre et d'une semaine à l'autre.
Planning genererPlanning({
  required DateTime lundi,
  required double kcalCible,
  bool vegetarien = false,
  Set<String> coches = const {},
  Map<String, Avis> avis = const {},
}) {
  final graine = lundi.difference(DateTime(2024)).inDays ~/ 7;
  final jours = <int, Map<Moment, RepasPlanifie>>{};
  for (var j = 0; j < 7; j++) {
    final repas = <Moment, RepasPlanifie>{};
    for (final e in partsDuJour.entries) {
      final liste = recettesSelonAvis(
        e.key,
        vegetarien: vegetarien,
        avis: avis,
      );
      final r = liste[(graine + j) % liste.length];
      repas[e.key] = RepasPlanifie(r.id, portionsPour(r, kcalCible * e.value));
    }
    jours[j] = repas;
  }
  return Planning(
    lundi: lundi,
    jours: jours,
    vegetarien: vegetarien,
    coches: coches,
  );
}

/// Tous les repas du jour 0 au jour 6 sont présents (un planning enregistré
/// avec des recettes retirées du catalogue est à refaire).
bool estComplet(Planning p) => [
  for (var j = 0; j < 7; j++)
    for (final m in Moment.values) p.jours[j]?[m],
].every((r) => r != null);

Macros macrosDuRepas(RepasPlanifie p) =>
    recetteParId(p.recetteId).macros.multiplie(p.portions);

Macros macrosDuJour(Map<Moment, RepasPlanifie>? repas) => (repas ?? const {})
    .values
    .fold(Macros.zero, (s, p) => s + macrosDuRepas(p));

@immutable
class LigneCourse {
  const LigneCourse({
    required this.cle,
    required this.nom,
    required this.quantite,
    required this.unite,
    required this.rayon,
  });

  /// Identifiant stable, utilisé pour cocher l'article.
  final String cle;
  final String nom;
  final double quantite;
  final Unite unite;
  final Rayon rayon;

  /// Quantité à acheter, arrondie : 5 g / 5 ml près, pièces entières.
  String get quantiteTexte => switch (unite) {
    Unite.piece => '${quantite.ceil()}',
    Unite.g => _arrondi(quantite, 'g'),
    Unite.ml => _arrondi(quantite, 'ml'),
  };

  static String _arrondi(double v, String u) {
    final r = math.max(5, (v / 5).ceil() * 5);
    return r >= 1000
        ? '${(r / 1000).toString().replaceAll('.', ',')} k$u'
        : '$r $u';
  }
}

/// Liste de courses de la semaine, regroupée par rayon (ordre du magasin),
/// puis par nom. Les articles identiques s'additionnent.
List<LigneCourse> listeCourses(Planning planning) {
  final total = <String, ({Ingredient ing, double q})>{};
  for (final jour in planning.jours.values) {
    for (final repas in jour.values) {
      for (final i in recetteParId(repas.recetteId).ingredients) {
        final cle = '${i.nom}|${i.unite.name}';
        final q = i.quantite * repas.portions;
        final actuel = total[cle];
        total[cle] = (ing: i, q: (actuel?.q ?? 0) + q);
      }
    }
  }
  final lignes = [
    for (final e in total.entries)
      LigneCourse(
        cle: e.key,
        nom: e.value.ing.nom,
        quantite: e.value.q,
        unite: e.value.ing.unite,
        rayon: e.value.ing.rayon,
      ),
  ];
  lignes.sort((a, b) {
    final r = a.rayon.index.compareTo(b.rayon.index);
    return r != 0 ? r : a.nom.compareTo(b.nom);
  });
  return lignes;
}
