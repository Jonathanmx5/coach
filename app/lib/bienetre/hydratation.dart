import 'package:flutter/foundation.dart';

@immutable
class EntreeEau {
  const EntreeEau({this.id, required this.date, required this.ml});

  final String? id;
  final DateTime date;
  final int ml;

  Map<String, Object?> toMap() => {
    'date': date.millisecondsSinceEpoch,
    'ml': ml,
  };

  static EntreeEau fromMap(String id, Map<String, Object?> m) => EntreeEau(
    id: id,
    date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
    ml: (m['ml'] as num).toInt(),
  );
}

/// Objectif d'eau du jour : 33 ml par kg, +10 ml par minute d'effort, +400 ml
/// à partir de 25 °C et +750 ml à partir de 30 °C (température max du jour).
/// Arrondi à 50 ml, entre 1,5 et 4,5 litres.
int objectifEauMl({
  required double poidsKg,
  int minutesEffort = 0,
  double? tempMaxC,
}) {
  var ml = poidsKg * 33 + minutesEffort * 10;
  if (tempMaxC != null) {
    if (tempMaxC >= 30) {
      ml += 750;
    } else if (tempMaxC >= 25) {
      ml += 400;
    }
  }
  final arrondi = (ml / 50).round() * 50;
  return arrondi.clamp(1500, 4500);
}

int totalEauMl(Iterable<EntreeEau> entrees) =>
    entrees.fold(0, (s, e) => s + e.ml);
