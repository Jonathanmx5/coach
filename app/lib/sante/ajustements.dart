import 'agregation.dart';
import 'modele.dart';

/// Spec santé connectée §4.
const joursMinimumMesures = 4;
const fenetreJours = 7;

/// Moyenne des calories totales des 7 jours avant [aujourdhui] (exclu), si
/// au moins 4 jours ont été mesurés ; sinon `null`.
double? maintienMesure(List<JourSante> jours, {required DateTime aujourdhui}) {
  final jour = jourDe(aujourdhui);
  final debut = DateTime(jour.year, jour.month, jour.day - fenetreJours);
  final valeurs = [
    for (final j in jours)
      if (j.jour.isBefore(jour) &&
          !j.jour.isBefore(debut) &&
          (j.kcalTotales ?? 0) > 0)
        j.kcalTotales!,
  ];
  if (valeurs.length < joursMinimumMesures) return null;
  return valeurs.reduce((a, b) => a + b) / valeurs.length;
}

/// La pesée la plus récente, si elle est plus récente que celle du profil.
Mesure? poidsAImporter(List<Mesure> pesees, DateTime? poidsDate) {
  if (pesees.isEmpty) return null;
  final derniere = pesees.reduce((a, b) => b.date.isAfter(a.date) ? b : a);
  if (poidsDate != null && !derniere.date.isAfter(poidsDate)) return null;
  return derniere;
}
