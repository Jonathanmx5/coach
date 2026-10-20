import 'package:flutter/foundation.dart';

import '../profil/modele.dart';
import 'calculs.dart';
import 'modele.dart';

/// Carton du coach, selon la composition du repas seule : vert = bon choix,
/// orange = à ajuster, rouge = à garder pour les occasions. Le budget de la
/// journée n'en change jamais la couleur.
enum Feu { vert, orange, rouge }

@immutable
class Verdict {
  const Verdict({
    required this.feu,
    required this.points,
    required this.conclusion,
    this.budget,
  });

  final Feu feu;

  /// Phrases d'explication sur la composition, dans l'ordre de lecture.
  final List<String> points;
  final String conclusion;

  /// Place du repas dans la journée (« Il te reste 600 kcal… »), à part du
  /// carton ; null si les objectifs du jour sont inconnus (ancien repas).
  final String? budget;

  Map<String, Object?> toMap() => {
    'feu': feu.name,
    'points': points,
    'conclusion': conclusion,
    if (budget != null) 'budget': budget,
  };

  static Verdict fromMap(Map<String, Object?> m) => Verdict(
    feu: Feu.values.asNameMap()[m['feu']] ?? Feu.orange,
    points: [for (final p in (m['points'] as List?) ?? const []) '$p'],
    conclusion: m['conclusion'] as String? ?? '',
    budget: m['budget'] is String ? m['budget'] as String : null,
  );
}

String _objectif(Objectif o) => switch (o) {
  Objectif.muscle => 'prise de muscle',
  Objectif.perte => 'perte de poids',
  Objectif.forme => 'remise en forme',
  Objectif.reprise => 'reprise en douceur',
};

/// Sucres totaux (fruits et lait compris, faute de connaître les sucres
/// ajoutés) : au-delà, un avertissement ; au-delà du second seuil, le carton
/// est rouge.
const seuilSucres = 25.0, seuilSucresCritique = 45.0;

/// Graisses saturées : au-delà, un avertissement.
const seuilSatures = 10.0;

/// Jugement d'un repas ou d'un produit selon sa composition (protéines,
/// sucres, graisses saturées, part des graisses) et l'objectif de la
/// personne ; à part, sa place dans le budget calorique du jour. Les seuils
/// sont des repères de bon sens, pas un avis médical.
Verdict verdictRepas({
  required Macros repas,
  double? sucres,
  double? satures,
  required Macros dejaMange,
  required CiblesJour cibles,
  required Objectif objectif,
}) {
  final kcal = repas.kcal;
  final p = repas.proteines;
  final cibleP = cibles.proteines.round();
  final points = <String>[];
  var avertissements = 0;
  var critiques = 0;

  // Protéines : quantité et densité (part des calories qui en vient).
  final densite = kcal > 0 ? p * 4 / kcal : 0.0;
  if (p >= 15 && densite >= 0.25) {
    points.add(
      '${p.round()} g de protéines pour ${kcal.round()} kcal : très efficace '
      'pour ton objectif de $cibleP g par jour.',
    );
  } else if (p >= 10 || densite >= 0.18) {
    points.add('${p.round()} g de protéines : un apport correct.');
  } else if (kcal >= 150) {
    avertissements++;
    points.add(
      'Seulement ${p.round()} g de protéines pour ${kcal.round()} kcal : peu '
      'utile pour ton objectif de $cibleP g par jour.',
    );
  }

  // Sucres (totaux) et glucides.
  final g = repas.glucides;
  if (sucres != null && sucres >= seuilSucresCritique) {
    critiques++;
    points.add('${sucres.round()} g de sucres : beaucoup d\'un coup.');
  } else if (sucres != null && sucres >= seuilSucres) {
    avertissements++;
    points.add(
      '${sucres.round()} g de sucres : à réserver aux moments où tu bouges.',
    );
  } else if (g >= 5 && g <= 60) {
    final dont = sucres == null ? '' : ' (dont ${sucres.round()} g de sucres)';
    points.add(
      'Les ${g.round()} g de glucides$dont apportent de l\'énergie sans '
      'faire exploser ton total.',
    );
  }

  // Graisses.
  if (satures != null && satures >= seuilSatures) {
    avertissements++;
    points.add('${satures.round()} g de graisses saturées : à limiter.');
  }
  if (kcal >= 250 && repas.lipides * 9 / kcal > 0.5) {
    avertissements++;
    points.add('Repas très gras : ${repas.lipides.round()} g de lipides.');
  }

  final feu = (critiques > 0 || avertissements >= 3)
      ? Feu.rouge
      : (avertissements > 0 ? Feu.orange : Feu.vert);
  final conclusion = switch (feu) {
    Feu.vert =>
      'Validé ! Un très bon choix pour ton objectif de ${_objectif(objectif)}.',
    Feu.orange =>
      'À ajuster : plus de protéines, moins de sucres ou de gras la '
          'prochaine fois.',
    Feu.rouge =>
      'À garder pour les occasions : cette composition sert peu ton '
          'objectif de ${_objectif(objectif)}.',
  };
  return Verdict(
    feu: feu,
    points: points,
    conclusion: conclusion,
    budget: budgetDuJour(
      repas: repas,
      dejaMange: dejaMange,
      cibles: cibles,
      objectif: objectif,
    ),
  );
}

/// La place du repas dans la journée, en une phrase neutre : ce qu'il reste,
/// ou de combien l'objectif est dépassé. Pour la prise de muscle, un
/// dépassement n'est pas un problème. Null sans objectif calorique.
String? budgetDuJour({
  required Macros repas,
  required Macros dejaMange,
  required CiblesJour cibles,
  required Objectif objectif,
}) {
  final cible = cibles.kcal;
  if (cible <= 0) return null;
  final apres = dejaMange.kcal + repas.kcal;
  final ecart = (apres - cible).round();
  final String phrase;
  if (ecart <= 0) {
    phrase = 'Il te reste ${-ecart} kcal pour la journée avec ce repas.';
  } else {
    final suite = objectif == Objectif.muscle
        ? 'Pour la prise de muscle, ce n\'est pas un problème.'
        : 'Allège un peu les prochains repas, sans en sauter.';
    phrase =
        'Tu dépasses de $ecart kcal ton objectif du jour avec ce repas. $suite';
  }
  final gros = objectif == Objectif.perte && repas.kcal > cible * 0.45;
  return gros
      ? '$phrase C\'est près de la moitié de ta journée en un seul repas.'
      : phrase;
}
