import '../profil/garde_fous.dart';
import '../profil/modele.dart';
import 'agregation.dart';
import 'modele.dart';

/// Spec santé connectée §4.
const joursMinimumMesures = 4;
const fenetreJours = 7;

/// Heure à partir de laquelle la dernière mesure de calories rend la journée
/// complète : avant, la montre n'a pas été portée (ou synchronisée) jusqu'au
/// soir et le total est partiel.
const heureJourneeComplete = 20;

/// Bornes du maintien mesuré, en multiples du métabolisme de base.
const maintienMinParBase = 1.1;
const maintienMaxParBase = 2.5;

/// Vrai si la montre a mesuré des calories totales jusqu'au soir. Sans heure
/// de dernière mesure (anciennes données), le total est pris tel quel.
bool journeeComplete(JourSante j) {
  if ((j.kcalTotales ?? 0) <= 0) return false;
  final derniere = j.derniereMesureKcal;
  return derniere == null ||
      !derniere.isBefore(
        DateTime(j.jour.year, j.jour.month, j.jour.day, heureJourneeComplete),
      );
}

/// Journée complète dont le total est vraisemblable : pas sous le métabolisme
/// de base (montre peu portée), pas au-delà de 3 fois (mesure aberrante).
bool _journeeValide(JourSante j, int depenseBase) =>
    journeeComplete(j) &&
    j.kcalTotales! >= depenseBase &&
    j.kcalTotales! <= 3 * depenseBase;

/// Les journées valides des 7 jours avant [aujourdhui] (exclu).
List<JourSante> _joursValides(
  List<JourSante> jours, {
  required DateTime aujourdhui,
  required int depenseBase,
}) {
  final jour = jourDe(aujourdhui);
  final debut = DateTime(jour.year, jour.month, jour.day - fenetreJours);
  return [
    for (final j in jours)
      if (j.jour.isBefore(jour) &&
          !j.jour.isBefore(debut) &&
          _journeeValide(j, depenseBase))
        j,
  ];
}

/// Moyenne des calories totales des journées valides des 7 jours avant
/// [aujourdhui] (exclu), s'il y en a au moins 4 ; sinon `null`. Le résultat
/// est borné entre 1,1 et 2,5 fois le métabolisme de base.
double? maintienMesure(
  List<JourSante> jours, {
  required DateTime aujourdhui,
  required int depenseBase,
}) {
  final valeurs = [
    for (final j in _joursValides(
      jours,
      aujourdhui: aujourdhui,
      depenseBase: depenseBase,
    ))
      j.kcalTotales!,
  ];
  if (valeurs.length < joursMinimumMesures) return null;
  final moyenne = valeurs.reduce((a, b) => a + b) / valeurs.length;
  return moyenne.clamp(
    maintienMinParBase * depenseBase,
    maintienMaxParBase * depenseBase,
  );
}

/// Moyenne des calories actives des journées valides des 7 jours avant
/// [aujourdhui] (exclu) : l'activité habituelle, déjà comprise dans le
/// maintien mesuré. `null` si aucune de ces journées n'a de calories actives.
double? moyenneActive(
  List<JourSante> jours, {
  required DateTime aujourdhui,
  required int depenseBase,
}) {
  final valeurs = [
    for (final j in _joursValides(
      jours,
      aujourdhui: aujourdhui,
      depenseBase: depenseBase,
    ))
      if (j.kcalActives != null) j.kcalActives!,
  ];
  if (valeurs.isEmpty) return null;
  return valeurs.reduce((a, b) => a + b) / valeurs.length;
}

/// Pesées vraisemblables pour un adulte ; au-delà, balance partagée ou erreur.
const poidsMinKg = 30.0;
const poidsMaxKg = 300.0;

/// Écart avec le poids du profil qui demande une confirmation, s'il apparaît
/// en moins de 7 jours.
const ecartAConfirmerKg = 3.0;

/// Une pesée à importer, avec l'indication qu'elle doit être confirmée.
class PeseeAImporter extends Mesure {
  const PeseeAImporter({
    required super.date,
    required super.valeur,
    this.aConfirmer = false,
  });

  /// Plus de 3 kg d'écart avec le poids du profil en moins de 7 jours :
  /// probablement une autre personne sur la balance.
  final bool aConfirmer;
}

/// La pesée vraisemblable (30 à 300 kg) la plus récente, si elle est plus
/// récente que celle du profil. [poidsProfilKg] sert à repérer un écart
/// suspect.
PeseeAImporter? poidsAImporter(
  List<Mesure> pesees,
  DateTime? poidsDate, {
  double? poidsProfilKg,
}) {
  final valables = [
    for (final p in pesees)
      if (p.valeur >= poidsMinKg && p.valeur <= poidsMaxKg) p,
  ];
  if (valables.isEmpty) return null;
  final derniere = valables.reduce((a, b) => b.date.isAfter(a.date) ? b : a);
  if (poidsDate != null && !derniere.date.isAfter(poidsDate)) return null;
  final aConfirmer =
      poidsProfilKg != null &&
      poidsDate != null &&
      (derniere.valeur - poidsProfilKg).abs() > ecartAConfirmerKg &&
      derniere.date.difference(poidsDate) < const Duration(days: 7);
  return PeseeAImporter(
    date: derniere.date,
    valeur: derniere.valeur,
    aConfirmer: aConfirmer,
  );
}

/// Le profil après l'import d'une pesée, avec les garde-fous santé (spec §3)
/// comme pour une saisie à la main.
Profil profilApresImport(Profil profil, Mesure pesee) => appliquerGardeFous(
  profil.copyWith(
    poidsKg: (pesee.valeur * 10).round() / 10,
    poidsDate: pesee.date,
  ),
  maintenant: pesee.date,
);
