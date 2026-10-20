import 'package:flutter/foundation.dart';

/// Matériel qu'on peut avoir chez soi.
enum Materiel {
  halteres,
  elastiques,
  barreTraction,
  kettlebell,
  banc,
  cordeASauter,
}

/// Où se passe la séance.
enum Lieu { maison, salle, course, marche }

enum Groupe { jambes, pousser, tirer, tronc, cardio }

@immutable
class Exercice {
  const Exercice({
    required this.id,
    required this.nom,
    required this.groupe,
    required this.consigne,
    this.requis = const {},
    this.salleSeulement = false,
    this.duree = false,
    this.alternative,
    this.impact = false,
    this.allonge = false,
    this.varianteDouce = false,
  });

  final String id;
  final String nom;
  final Groupe groupe;
  final String consigne;

  /// Matériel nécessaire à la maison.
  final Set<Materiel> requis;

  /// Machines ou barre de salle : impossible à la maison.
  final bool salleSeulement;

  /// Exercice chronométré (gainage…) plutôt qu'en répétitions.
  final bool duree;

  /// Remplaçant (id) quand le matériel manque.
  final String? alternative;

  /// Sauts ou course sur place : exclu pour une grossesse, un suivi médical
  /// ou des douleurs articulaires.
  final bool impact;

  /// Allongé sur le dos ou à plat ventre : exclu pour une grossesse.
  final bool allonge;

  /// Variante sans impact, proposée seulement quand l'impact est exclu.
  final bool varianteDouce;
}

/// Un exercice dans une séance, avec ses séries.
@immutable
class ExerciceSeance {
  const ExerciceSeance({
    required this.exercice,
    required this.series,
    required this.reps,
    required this.secondes,
    required this.reposSecondes,
    this.remplace,
  });

  final Exercice exercice;
  final int series;

  /// Répétitions par série (0 pour un exercice chronométré).
  final int reps;

  /// Durée d'une série chronométrée (0 pour un exercice en répétitions).
  final int secondes;
  final int reposSecondes;

  /// Exercice prévu au départ, remplacé faute de matériel.
  final Exercice? remplace;
}

/// Une étape de la séance guidée : un effort (répétitions ou chronométré) ou
/// un repos.
@immutable
class Etape {
  const Etape({
    required this.titre,
    required this.consigne,
    this.secondes = 0,
    this.reps = 0,
    this.repos = false,
    this.exerciceId,
  });

  final String titre;
  final String consigne;

  /// > 0 : étape chronométrée. 0 : l'utilisateur valide « Fait ».
  final int secondes;
  final int reps;
  final bool repos;

  /// Exercice montré à l'écran (animation) ; null pour un repos ou un
  /// échauffement.
  final String? exerciceId;
}

@immutable
class Seance {
  const Seance({
    required this.titre,
    required this.lieu,
    required this.etapes,
    this.exercices = const [],
  });

  final String titre;
  final Lieu lieu;
  final List<Etape> etapes;
  final List<ExerciceSeance> exercices;

  /// Durée estimée en minutes (étapes chronométrées + 40 s par effort en
  /// répétitions).
  int get minutes {
    var s = 0;
    for (final e in etapes) {
      s += e.secondes > 0 ? e.secondes : 40;
    }
    return (s / 60).ceil();
  }
}

/// Réglages d'entraînement de l'utilisateur.
@immutable
class Reglages {
  const Reglages({this.materiel = const {}});

  final Set<Materiel> materiel;

  Map<String, Object?> toMap() => {
    'materiel': [for (final m in materiel) m.name],
  };

  static Reglages fromMap(Map<String, Object?> m) => Reglages(
    materiel: {
      for (final n in (m['materiel'] as List?) ?? const [])
        for (final v in Materiel.values)
          if (v.name == n) v,
    },
  );
}

/// Une séance terminée (pour la progression).
@immutable
class SeanceFaite {
  const SeanceFaite({
    this.id,
    required this.date,
    required this.lieu,
    required this.minutes,
  });

  final String? id;
  final DateTime date;
  final Lieu lieu;
  final int minutes;

  Map<String, Object?> toMap() => {
    'date': date.millisecondsSinceEpoch,
    'lieu': lieu.name,
    'minutes': minutes,
  };

  static SeanceFaite fromMap(String id, Map<String, Object?> m) => SeanceFaite(
    id: id,
    date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
    lieu: Lieu.values.firstWhere(
      (l) => l.name == m['lieu'],
      orElse: () => Lieu.maison,
    ),
    minutes: (m['minutes'] as num).toInt(),
  );
}
