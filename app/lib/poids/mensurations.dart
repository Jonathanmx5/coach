import 'package:flutter/foundation.dart';

enum TypeMensuration { taille, poitrine, bras, masseGrasse }

/// Plage plausible de chaque mesure (cm, ou % pour la masse grasse).
const plagesMensuration = {
  TypeMensuration.taille: (min: 40.0, max: 200.0),
  TypeMensuration.poitrine: (min: 50.0, max: 200.0),
  TypeMensuration.bras: (min: 15.0, max: 70.0),
  TypeMensuration.masseGrasse: (min: 3.0, max: 60.0),
};

/// Une prise de mesures : au moins une valeur (tour de taille, de poitrine,
/// de bras en cm, masse grasse en %).
@immutable
class Mensuration {
  const Mensuration({this.id, required this.date, required this.valeurs});

  final String? id;
  final DateTime date;
  final Map<TypeMensuration, double> valeurs;

  Map<String, Object?> toMap() => {
    'date': date.millisecondsSinceEpoch,
    for (final e in valeurs.entries) e.key.name: e.value,
  };

  static Mensuration fromMap(String id, Map<String, Object?> m) => Mensuration(
    id: id,
    date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
    valeurs: {
      for (final t in TypeMensuration.values)
        if (m[t.name] is num) t: (m[t.name]! as num).toDouble(),
    },
  );
}

/// Dernière valeur d'une mesure (liste triée par date) et son écart depuis la
/// première ; null si jamais saisie, écart null s'il n'y a qu'une valeur.
({double valeur, double? ecart})? derniereMesure(
  List<Mensuration> triees,
  TypeMensuration type,
) {
  final valeurs = [
    for (final m in triees)
      if (m.valeurs[type] != null) m.valeurs[type]!,
  ];
  if (valeurs.isEmpty) return null;
  return (
    valeur: valeurs.last,
    ecart: valeurs.length < 2 ? null : valeurs.last - valeurs.first,
  );
}
