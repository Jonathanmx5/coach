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
