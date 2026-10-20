import 'package:flutter/foundation.dart';

import '../journal/calculs.dart';
import '../journal/modele.dart';
import '../poids/pesees.dart';
import '../profil/modele.dart';
import '../sante/modele.dart';

/// Nombre de jours résumés par la carte « Ma semaine ».
const joursSemaine = 7;

/// Écart toléré autour de la cible du jour pour qu'une journée y soit.
const toleranceCible = 0.10;

/// Vrai si [mange] est à ±[toleranceCible] de [cible].
bool dansLaCible(double mange, double cible) =>
    cible > 0 && (mange - cible).abs() <= toleranceCible * cible + 1e-9;

/// Ce que résume la carte « Ma semaine » de l'accueil.
@immutable
class BilanSemaine {
  const BilanSemaine({
    required this.joursNotes,
    required this.kcalMoyenne,
    required this.cibleMoyenne,
    required this.joursDansCible,
    required this.proteinesMoyenne,
    required this.cibleProteines,
    required this.seances,
    required this.seancesPrevues,
    required this.poidsTendance,
    required this.evolutionPoids,
  });

  /// Journées terminées des 7 derniers jours avec au moins un repas noté.
  final int joursNotes;

  /// Calories mangées par jour noté en moyenne ; null sans jour noté.
  final double? kcalMoyenne;

  /// Cible du jour (exercice compris) en moyenne sur les mêmes jours ; sur
  /// les 7 jours s'il n'y a aucun jour noté.
  final double cibleMoyenne;

  /// Jours notés à ±10 % de leur cible.
  final int joursDansCible;

  /// Protéines mangées par jour noté en moyenne ; null sans jour noté.
  final double? proteinesMoyenne;
  final double cibleProteines;

  /// Séances faites (activités du journal, séances guidées comprises) sur
  /// les 7 derniers jours, aujourd'hui compris.
  final int seances;

  /// Séances prévues par semaine dans le profil.
  final int seancesPrevues;

  /// Poids lissé (moyenne mobile sur 7 jours) à la dernière pesée des 7
  /// derniers jours ; null sans pesée récente.
  final double? poidsTendance;

  /// [poidsTendance] moins la moyenne mobile une semaine plus tôt ; null
  /// s'il manque l'une des deux.
  final double? evolutionPoids;
}

DateTime _jourDe(DateTime d) => DateTime(d.year, d.month, d.day);

/// Résumé des 7 derniers jours, avec les mêmes calculs que le Journal
/// ([bilanDuJour]) :
/// - calories, protéines et jours dans la cible sur les 7 journées terminées
///   avant aujourd'hui (la journée en cours fausserait les moyennes), en ne
///   comptant que les jours où au moins un repas est noté (un jour oublié
///   n'est pas un jeûne) ;
/// - séances et poids sur les 7 derniers jours, aujourd'hui compris.
///
/// [repas] et [activites] couvrent au moins les 7 jours avant aujourd'hui et
/// aujourd'hui ; [pesees] (triées, saisies et montre) les 14 derniers jours
/// pour comparer la tendance du poids à celle d'une semaine plus tôt.
BilanSemaine bilanSemaine({
  required Profil profil,
  List<JourSante> jours = const [],
  double? maintienMesure,
  required List<Repas> repas,
  required List<Activite> activites,
  required List<Pesee> pesees,
  required DateTime maintenant,
}) {
  final aujourdhui = _jourDe(maintenant);
  final debut = DateTime(
    aujourdhui.year,
    aujourdhui.month,
    aujourdhui.day - joursSemaine,
  );

  final repasParJour = <DateTime, List<Repas>>{};
  for (final r in repas) {
    final j = _jourDe(r.date);
    if (j.isBefore(debut) || !j.isBefore(aujourdhui)) continue;
    repasParJour.putIfAbsent(j, () => []).add(r);
  }
  final activitesParJour = <DateTime, List<Activite>>{};
  for (final a in activites) {
    activitesParJour.putIfAbsent(_jourDe(a.date), () => []).add(a);
  }

  var mangees = 0.0, proteines = 0.0, ciblesNotes = 0.0, ciblesToutes = 0.0;
  var notes = 0, dansCible = 0;
  double cibleProteines = 0;
  for (var i = 0; i < joursSemaine; i++) {
    final jour = DateTime(debut.year, debut.month, debut.day + i);
    final repasDuJour = repasParJour[jour] ?? const <Repas>[];
    final bilan = bilanDuJour(
      profil: profil,
      jours: jours,
      maintienMesure: maintienMesure,
      repas: repasDuJour,
      activites: activitesParJour[jour] ?? const [],
      jour: jour,
      maintenant: maintenant,
    );
    cibleProteines = bilan.cibles.proteines;
    ciblesToutes += bilan.cibles.kcal;
    if (repasDuJour.isEmpty) continue;
    notes++;
    mangees += bilan.mangees;
    proteines += bilan.macros.proteines;
    ciblesNotes += bilan.cibles.kcal;
    if (dansLaCible(bilan.mangees, bilan.cibles.kcal)) dansCible++;
  }

  final debutRecent = DateTime(
    aujourdhui.year,
    aujourdhui.month,
    aujourdhui.day - (joursSemaine - 1),
  );
  final demain = DateTime(
    aujourdhui.year,
    aujourdhui.month,
    aujourdhui.day + 1,
  );
  final seances = activites
      .where((a) => !a.date.isBefore(debutRecent) && a.date.isBefore(demain))
      .length;

  // Tendance : la moyenne mobile à la dernière pesée des 7 derniers jours,
  // comparée à celle de la dernière pesée de la semaine d'avant.
  final debutAvant = DateTime(
    aujourdhui.year,
    aujourdhui.month,
    aujourdhui.day - (2 * joursSemaine - 1),
  );
  final tendance = moyenneMobile([
    for (final p in pesees)
      if (p.date.isBefore(demain)) p,
  ], jours: joursSemaine);
  final actuel = tendance
      .where((p) => !p.date.isBefore(debutRecent))
      .lastOrNull;
  final avant = tendance
      .where(
        (p) => !p.date.isBefore(debutAvant) && p.date.isBefore(debutRecent),
      )
      .lastOrNull;

  return BilanSemaine(
    joursNotes: notes,
    kcalMoyenne: notes == 0 ? null : mangees / notes,
    cibleMoyenne: notes == 0
        ? ciblesToutes / joursSemaine
        : ciblesNotes / notes,
    joursDansCible: dansCible,
    proteinesMoyenne: notes == 0 ? null : proteines / notes,
    cibleProteines: cibleProteines,
    seances: seances,
    seancesPrevues: profil.joursParSemaine,
    poidsTendance: actuel?.kg,
    evolutionPoids: actuel == null || avant == null
        ? null
        : actuel.kg - avant.kg,
  );
}

/// Écart de poids avec le signe, au dixième : −0,4 kg, +0,2 kg, 0,0 kg.
String ecartPoidsTexte(double kg) {
  final dixiemes = (kg * 10).round();
  if (dixiemes == 0) return '0,0 kg';
  final texte = (dixiemes.abs() / 10).toStringAsFixed(1).replaceAll('.', ',');
  return dixiemes > 0 ? '+$texte kg' : '−$texte kg';
}
