import 'package:flutter/foundation.dart';

/// Mesures lues dans Health Connect, indépendamment de l'extension utilisée.
enum TypeMesure {
  pas,
  distance,
  etages,
  kcalActives,
  kcalTotales,
  fc,
  fcRepos,
  variabilite,
  spo2,
  freqResp,
  poids,
  masseGrasse,
  sommeilProfond,
  sommeilLeger,
  sommeilParadoxal,
  sommeilEveil,
  sommeilEndormi,
  seance,
}

/// Un point brut : valeur sur un intervalle (ou un instant si debut == fin).
@immutable
class PointSante {
  const PointSante({
    required this.type,
    required this.debut,
    required this.fin,
    required this.valeur,
    this.libelle,
  });

  final TypeMesure type;
  final DateTime debut;
  final DateTime fin;
  final double valeur;

  /// Type d'activité pour une séance.
  final String? libelle;
}

@immutable
class ResumeSommeil {
  const ResumeSommeil({
    required this.endormi,
    required this.profond,
    required this.leger,
    required this.paradoxal,
    required this.eveil,
  });

  final Duration endormi;
  final Duration profond;
  final Duration leger;
  final Duration paradoxal;
  final Duration eveil;

  bool get aDesPhases =>
      profond > Duration.zero ||
      leger > Duration.zero ||
      paradoxal > Duration.zero;
}

@immutable
class Seance {
  const Seance({
    required this.type,
    required this.debut,
    required this.duree,
    this.kcal,
  });

  final String type;
  final DateTime debut;
  final Duration duree;
  final double? kcal;
}

/// Résumé d'un jour calendaire local.
@immutable
class JourSante {
  const JourSante({
    required this.jour,
    this.pas,
    this.distanceM,
    this.etages,
    this.kcalActives,
    this.kcalTotales,
    this.fcMoyenne,
    this.fcRepos,
    this.variabiliteMs,
    this.spo2,
    this.freqResp,
    this.sommeil,
    this.seances = const [],
  });

  final DateTime jour;
  final int? pas;
  final double? distanceM;
  final int? etages;
  final double? kcalActives;
  final double? kcalTotales;
  final double? fcMoyenne;
  final double? fcRepos;
  final double? variabiliteMs;
  final double? spo2;
  final double? freqResp;
  final ResumeSommeil? sommeil;
  final List<Seance> seances;
}

@immutable
class Mesure {
  const Mesure({required this.date, required this.valeur});

  final DateTime date;
  final double valeur;
}
