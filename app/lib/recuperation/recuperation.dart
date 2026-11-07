import 'package:flutter/foundation.dart';

import '../sante/modele.dart';

enum NiveauRecuperation { bon, moyen, faible }

/// Ressenti du matin : 1 = fatigué, 2 = moyen, 3 = en forme.
const ressentiFatigue = 1;
const ressentiMoyen = 2;
const ressentiForme = 3;

@immutable
class Recuperation {
  const Recuperation({required this.score, required this.niveau});

  /// De 0 à 100.
  final int score;
  final NiveauRecuperation niveau;
}

NiveauRecuperation niveauDuScore(int score) => score >= 70
    ? NiveauRecuperation.bon
    : score >= 45
    ? NiveauRecuperation.moyen
    : NiveauRecuperation.faible;

/// Score du sommeil : durée (7 à 9 h = 100) et, si la montre donne les
/// phases, part de sommeil profond + paradoxal (35 % = 100).
double scoreSommeil(ResumeSommeil s) {
  final h = s.endormi.inMinutes / 60;
  final duree = h >= 7 && h <= 9
      ? 100.0
      : h < 7
      ? ((h - 4) / 3 * 100).clamp(0, 100).toDouble()
      : (100 - (h - 9) * 20).clamp(60, 100).toDouble();
  if (!s.aDesPhases || s.endormi == Duration.zero) return duree;
  final part = (s.profond + s.paradoxal).inMinutes / s.endormi.inMinutes;
  final qualite = (part / 0.35 * 100).clamp(0, 100).toDouble();
  return 0.7 * duree + 0.3 * qualite;
}

double? _moyenne(Iterable<double> v) {
  final l = v.toList();
  return l.length < 3 ? null : l.reduce((a, b) => a + b) / l.length;
}

/// Score de récupération du matin, de 0 à 100, ou null sans aucune donnée.
/// Mélange le sommeil de la nuit (50), la variabilité cardiaque (25) et la
/// fréquence cardiaque au repos (15) comparées à la moyenne des jours
/// précédents, et le ressenti (30). Seules les données disponibles comptent.
Recuperation? calculerRecuperation({
  JourSante? nuit,
  List<JourSante> precedents = const [],
  int? ressenti,
}) {
  final composantes = <({double score, double poids})>[];

  final sommeil = nuit?.sommeil;
  if (sommeil != null && sommeil.endormi > Duration.zero) {
    composantes.add((score: scoreSommeil(sommeil), poids: 50));
  }

  final vfc = nuit?.variabiliteMs;
  final vfcRef = _moyenne([
    for (final j in precedents)
      if (j.variabiliteMs != null) j.variabiliteMs!,
  ]);
  if (vfc != null && vfcRef != null && vfcRef > 0) {
    final ratio = vfc / vfcRef;
    composantes.add((
      score: ratio >= 1 ? 100 : (100 - (1 - ratio) * 250).clamp(0, 100),
      poids: 25,
    ));
  }

  final fc = nuit?.fcRepos;
  final fcRef = _moyenne([
    for (final j in precedents)
      if (j.fcRepos != null) j.fcRepos!,
  ]);
  if (fc != null && fcRef != null) {
    final ecart = fc - fcRef;
    composantes.add((
      score: ecart <= 0 ? 100 : (100 - ecart * 10).clamp(0, 100),
      poids: 15,
    ));
  }

  if (ressenti != null) {
    composantes.add((
      score: switch (ressenti) {
        ressentiForme => 90.0,
        ressentiMoyen => 60.0,
        _ => 25.0,
      },
      poids: 30,
    ));
  }

  if (composantes.isEmpty) return null;
  final poids = composantes.fold<double>(0, (s, c) => s + c.poids);
  final score =
      (composantes.fold<double>(0, (s, c) => s + c.score * c.poids) / poids)
          .round();
  return Recuperation(score: score, niveau: niveauDuScore(score));
}
