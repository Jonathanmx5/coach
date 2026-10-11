import 'package:flutter/foundation.dart';

/// Un complément alimentaire suivi par un rappel quotidien. Coach ne
/// conseille aucune dose : l'utilisateur note ce qu'il prend.
@immutable
class Complement {
  const Complement({
    this.id,
    required this.nom,
    required this.minutes,
    this.actif = true,
  });

  final String? id;
  final String nom;

  /// Heure du rappel, en minutes depuis minuit.
  final int minutes;
  final bool actif;

  Complement copyWith({bool? actif}) => Complement(
    id: id,
    nom: nom,
    minutes: minutes,
    actif: actif ?? this.actif,
  );

  Map<String, Object?> toMap() => {
    'nom': nom,
    'minutes': minutes,
    'actif': actif,
  };

  static Complement fromMap(String id, Map<String, Object?> m) => Complement(
    id: id,
    nom: m['nom'] as String,
    minutes: (m['minutes'] as num).toInt(),
    actif: (m['actif'] as bool?) ?? true,
  );
}

String heureTexte(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}h'
    '${(minutes % 60).toString().padLeft(2, '0')}';
