import 'hydratation.dart';

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Jours calendaires (sans l'heure) d'une liste de dates.
Set<DateTime> joursDe(Iterable<DateTime> dates) => {
  for (final d in dates) _jour(d),
};

/// Jours où l'eau bue atteint [objectifMl].
Set<DateTime> joursEauAtteinte(Iterable<EntreeEau> entrees, int objectifMl) {
  final parJour = <DateTime, int>{};
  for (final e in entrees) {
    parJour.update(_jour(e.date), (v) => v + e.ml, ifAbsent: () => e.ml);
  }
  return {
    for (final e in parJour.entries)
      if (e.value >= objectifMl) e.key,
  };
}

/// Série en cours : jours consécutifs jusqu'à aujourd'hui. Si aujourd'hui
/// n'est pas encore fait, la série d'hier reste vivante (la journée n'est pas
/// finie) ; si hier manque aussi, elle retombe à 0.
int serieEnCours(Set<DateTime> jours, DateTime aujourdhui) {
  var j = _jour(aujourdhui);
  if (!jours.contains(j)) j = DateTime(j.year, j.month, j.day - 1);
  var n = 0;
  while (jours.contains(j)) {
    n++;
    j = DateTime(j.year, j.month, j.day - 1);
  }
  return n;
}

/// Série en cours lue sur une fenêtre qui commence à [debut] : les jours
/// consécutifs comme [serieEnCours], mais un jour absent de [joursPrevus]
/// (1 = lundi … 7 = dimanche ; tous si null) est un jour de repos qui ne
/// coupe pas la série. [tronquee] : la série remonte jusqu'à [debut], elle
/// continue peut-être avant et il faut lire plus loin pour la connaître.
({int jours, bool tronquee}) serieSurFenetre(
  Set<DateTime> jours,
  DateTime aujourdhui, {
  required DateTime debut,
  Set<int>? joursPrevus,
}) {
  final premier = _jour(debut);
  var j = _jour(aujourdhui);
  if (!jours.contains(j)) j = DateTime(j.year, j.month, j.day - 1);
  var n = 0;
  while (!j.isBefore(premier)) {
    if (jours.contains(j)) {
      n++;
    } else if (joursPrevus == null || joursPrevus.contains(j.weekday)) {
      return (jours: n, tronquee: false);
    }
    j = DateTime(j.year, j.month, j.day - 1);
  }
  return (jours: n, tronquee: true);
}
