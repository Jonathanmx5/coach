import 'package:flutter/foundation.dart';

import 'analyse_photo.dart' show AlimentEstime;

enum Moment { petitDejeuner, dejeuner, diner, collation }

enum SourceRepas { manuel, codeBarres, photo }

enum TypeActivite { velo, mma, course, natation, musculation, marche, autre }

enum Intensite { legere, moderee, intense }

@immutable
class Macros {
  const Macros({
    this.kcal = 0,
    this.proteines = 0,
    this.glucides = 0,
    this.lipides = 0,
  });

  static const zero = Macros();

  final double kcal;
  final double proteines;
  final double glucides;
  final double lipides;

  Macros operator +(Macros o) => Macros(
    kcal: kcal + o.kcal,
    proteines: proteines + o.proteines,
    glucides: glucides + o.glucides,
    lipides: lipides + o.lipides,
  );

  Macros multiplie(double f) => Macros(
    kcal: kcal * f,
    proteines: proteines * f,
    glucides: glucides * f,
    lipides: lipides * f,
  );

  Map<String, Object?> toMap() => {
    'kcal': kcal,
    'proteines': proteines,
    'glucides': glucides,
    'lipides': lipides,
  };

  static Macros fromMap(Map<String, Object?> m) => Macros(
    kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
    proteines: (m['proteines'] as num?)?.toDouble() ?? 0,
    glucides: (m['glucides'] as num?)?.toDouble() ?? 0,
    lipides: (m['lipides'] as num?)?.toDouble() ?? 0,
  );
}

/// Un repas ou un aliment ajouté au journal.
@immutable
class Repas {
  const Repas({
    this.id,
    required this.date,
    required this.moment,
    required this.nom,
    required this.macros,
    required this.source,
    this.description = '',
    this.aliments = const [],
    this.photoId,
  });

  final String? id;
  final DateTime date;
  final Moment moment;
  final String nom;
  final Macros macros;
  final SourceRepas source;

  /// Pour un repas photographié : ce que l'IA a compris et les aliments
  /// retenus, pour pouvoir revoir l'analyse plus tard.
  final String description;
  final List<AlimentEstime> aliments;

  /// Référence de la photo gardée sur ce téléphone, s'il y en a une.
  final String? photoId;

  Map<String, Object?> toMap() => {
    'date': date.millisecondsSinceEpoch,
    'moment': moment.name,
    'nom': nom,
    'macros': macros.toMap(),
    'source': source.name,
    if (description.isNotEmpty) 'description': description,
    if (photoId != null) 'photoId': photoId,
    if (aliments.isNotEmpty) 'aliments': [for (final a in aliments) a.toMap()],
  };

  static Repas fromMap(String id, Map<String, Object?> m) => Repas(
    id: id,
    date: DateTime.fromMillisecondsSinceEpoch((m['date']! as num).toInt()),
    moment: Moment.values.asNameMap()[m['moment']] ?? Moment.collation,
    nom: m['nom'] as String? ?? '',
    macros: Macros.fromMap((m['macros']! as Map).cast<String, Object?>()),
    source: SourceRepas.values.asNameMap()[m['source']] ?? SourceRepas.manuel,
    description: m['description'] as String? ?? '',
    photoId: m['photoId'] as String?,
    aliments: [
      for (final a in (m['aliments'] as List?) ?? const [])
        AlimentEstime.fromMap((a as Map).cast<String, Object?>()),
    ],
  );
}

/// Une activité saisie à la main (spec journal : durée et type d'effort).
@immutable
class Activite {
  const Activite({
    this.id,
    required this.date,
    required this.type,
    required this.minutes,
    required this.intensite,
    required this.kcal,
  });

  final String? id;
  final DateTime date;
  final TypeActivite type;
  final int minutes;
  final Intensite intensite;
  final double kcal;

  Map<String, Object?> toMap() => {
    'date': date.millisecondsSinceEpoch,
    'type': type.name,
    'minutes': minutes,
    'intensite': intensite.name,
    'kcal': kcal,
  };

  static Activite fromMap(String id, Map<String, Object?> m) => Activite(
    id: id,
    date: DateTime.fromMillisecondsSinceEpoch((m['date']! as num).toInt()),
    type: TypeActivite.values.asNameMap()[m['type']] ?? TypeActivite.autre,
    minutes: (m['minutes']! as num).toInt(),
    intensite:
        Intensite.values.asNameMap()[m['intensite']] ?? Intensite.moderee,
    kcal: (m['kcal']! as num).toDouble(),
  );
}
