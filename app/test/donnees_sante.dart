import 'package:coach/sante/modele.dart';

/// Semaine type au 9 octobre 2026 : 8 jours complets à 2 600 kcal,
/// 6 500 pas aujourd'hui, nuit de 7 h, pesée à 79,5 kg ce matin.
List<PointSante> semaineType() => [
  for (var i = 1; i <= 8; i++)
    PointSante(
      type: TypeMesure.kcalTotales,
      debut: DateTime(2026, 10, 9 - i, 12),
      fin: DateTime(2026, 10, 9 - i, 13),
      valeur: 2600,
    ),
  PointSante(
    type: TypeMesure.pas,
    debut: DateTime(2026, 10, 9, 8),
    fin: DateTime(2026, 10, 9, 18),
    valeur: 6500,
  ),
  PointSante(
    type: TypeMesure.sommeilEndormi,
    debut: DateTime(2026, 10, 8, 23),
    fin: DateTime(2026, 10, 9, 6),
    valeur: 420,
  ),
  PointSante(
    type: TypeMesure.poids,
    debut: DateTime(2026, 10, 9, 7),
    fin: DateTime(2026, 10, 9, 7),
    valeur: 79.5,
  ),
];
