import 'modele.dart';

/// Lundi (à minuit) de la semaine de [t].
DateTime lundiDe(DateTime t) =>
    DateTime(t.year, t.month, t.day - (t.weekday - 1));

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Jours de séance prévus (1 = lundi … 7 = dimanche) : les séances sont
/// réparties sur la semaine pour laisser des jours de repos entre elles.
Set<int> joursPrevus(int joursParSemaine) =>
    switch (joursParSemaine.clamp(1, 7)) {
      1 => {DateTime.wednesday},
      2 => {DateTime.tuesday, DateTime.friday},
      3 => {DateTime.monday, DateTime.wednesday, DateTime.friday},
      4 => {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.saturday,
      },
      5 => {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
      },
      6 => {for (var j = DateTime.monday; j <= DateTime.saturday; j++) j},
      _ => {for (var j = DateTime.monday; j <= DateTime.sunday; j++) j},
    };

/// Ce que l'onglet Sport propose aujourd'hui.
enum EtatDuJour {
  /// Jour de séance (prévu, ou séance manquée plus tôt dans la semaine).
  seance,

  /// Une séance est déjà faite aujourd'hui : une seule par jour.
  faite,

  /// Jour de repos prévu.
  repos,

  /// Toutes les séances de la semaine sont faites.
  semaineFaite,
}

/// État du jour d'après les séances faites depuis lundi ([semaine]).
EtatDuJour etatDuJour({
  required DateTime maintenant,
  required int joursParSemaine,
  required List<SeanceFaite> semaine,
}) {
  final aujourdhui = _jour(maintenant);
  final lundi = lundiDe(maintenant);
  final faites = semaine.where((s) => !s.date.isBefore(lundi)).toList();
  if (faites.any((s) => _jour(s.date) == aujourdhui)) return EtatDuJour.faite;
  if (faites.length >= joursParSemaine) return EtatDuJour.semaineFaite;
  final prevus = joursPrevus(joursParSemaine);
  if (prevus.contains(maintenant.weekday)) return EtatDuJour.seance;
  // Une séance prévue plus tôt dans la semaine a été manquée : on la
  // rattrape aujourd'hui.
  final prevusJusquIci = prevus.where((j) => j <= maintenant.weekday).length;
  return faites.length < prevusJusquIci ? EtatDuJour.seance : EtatDuJour.repos;
}

/// Prochain jour de séance prévu après aujourd'hui, [faitesSemaine] séances
/// étant déjà faites depuis lundi.
DateTime prochaineSeance({
  required DateTime maintenant,
  required int joursParSemaine,
  required int faitesSemaine,
}) {
  final prevus = joursPrevus(joursParSemaine);
  final aujourdhui = _jour(maintenant);
  var faites = faitesSemaine;
  for (var d = 1; d <= 7; d++) {
    final jour = DateTime(
      aujourdhui.year,
      aujourdhui.month,
      aujourdhui.day + d,
    );
    if (jour.weekday == DateTime.monday) faites = 0;
    if (prevus.contains(jour.weekday) && faites < joursParSemaine) return jour;
  }
  return DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day + 1);
}
