import 'package:flutter/foundation.dart';

import '../profil/modele.dart';
import 'calculs.dart';
import 'modele.dart';

/// Carton du coach : vert = bon choix, orange = à ajuster, rouge = à éviter.
enum Feu { vert, orange, rouge }

@immutable
class Verdict {
  const Verdict({
    required this.feu,
    required this.points,
    required this.conclusion,
  });

  final Feu feu;

  /// Phrases d'explication, dans l'ordre de lecture.
  final List<String> points;
  final String conclusion;

  Map<String, Object?> toMap() => {
    'feu': feu.name,
    'points': points,
    'conclusion': conclusion,
  };

  static Verdict fromMap(Map<String, Object?> m) => Verdict(
    feu: Feu.values.asNameMap()[m['feu']] ?? Feu.orange,
    points: [for (final p in (m['points'] as List?) ?? const []) '$p'],
    conclusion: m['conclusion'] as String? ?? '',
  );
}

String _objectif(Objectif o) => switch (o) {
  Objectif.muscle => 'prise de muscle',
  Objectif.perte => 'perte de poids',
  Objectif.forme => 'remise en forme',
  Objectif.reprise => 'reprise en douceur',
};

/// Jugement d'un repas ou d'un produit selon l'objectif de la personne et sa
/// journée : protéines, place dans le budget calorique, sucres, graisses
/// saturées. Les seuils sont des repères de bon sens, pas un avis médical.
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

  // Protéines.
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

  // Budget calorique du jour.
  final apres = dejaMange.kcal + kcal;
  final cible = cibles.kcal;
  if (apres > cible * 1.1) {
    critiques++;
    points.add(
      'Avec ce repas, tu dépasserais ton objectif du jour de '
      '${(apres - cible).round()} kcal.',
    );
  } else if (apres > cible) {
    avertissements++;
    points.add(
      'Tu atteindrais ton objectif calorique du jour '
      '(${apres.round()} / ${cible.round()} kcal).',
    );
  } else {
    points.add(
      'Il te resterait ${(cible - apres).round()} kcal pour le reste de la '
      'journée.',
    );
  }
  if (objectif == Objectif.perte && cible > 0 && kcal > cible * 0.45) {
    avertissements++;
    points.add('C\'est près de la moitié de ta journée en un seul repas.');
  }

  // Sucres et glucides.
  final g = repas.glucides;
  if (sucres != null && sucres >= 30) {
    critiques++;
    points.add('${sucres.round()} g de sucres : beaucoup d\'un coup.');
  } else if (sucres != null && sucres >= 15) {
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
  if (satures != null && satures >= 10) {
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
      'À ajuster : prends une portion plus petite ou compense sur les '
          'prochains repas.',
    Feu.rouge => 'À éviter aujourd\'hui, ou à réduire fortement.',
  };
  return Verdict(feu: feu, points: points, conclusion: conclusion);
}
