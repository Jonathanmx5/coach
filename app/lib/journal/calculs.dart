import '../profil/besoins.dart';
import '../profil/modele.dart';
import '../sante/ajustements.dart' as ajustements;
import '../sante/modele.dart' as sante;
import 'modele.dart';

/// Équivalents métaboliques (MET) usuels par type d'effort.
const _met = {
  TypeActivite.velo: 7.5,
  TypeActivite.mma: 10.0,
  TypeActivite.course: 9.8,
  TypeActivite.natation: 8.0,
  TypeActivite.musculation: 5.0,
  TypeActivite.marche: 3.5,
  TypeActivite.autre: 5.0,
};

const _facteurIntensite = {
  Intensite.legere: 0.8,
  Intensite.moderee: 1.0,
  Intensite.intense: 1.2,
};

/// Calories NETTES d'une activité : (MET × facteur d'intensité − 1) × poids
/// × heures. Le « − 1 » retire le métabolisme de repos de l'heure d'effort,
/// déjà compté dans le maintien.
double kcalActivite(
  TypeActivite type,
  int minutes,
  Intensite intensite,
  double poidsKg,
) {
  final met = _met[type]! * _facteurIntensite[intensite]! - 1;
  return (met < 0 ? 0 : met) * poidsKg * minutes / 60;
}

enum IntensiteJour { repos, modere, intense }

/// Repos sous 100 kcal d'exercice, intense à partir de 400.
IntensiteJour intensiteDuJour(double kcalExercice) => kcalExercice >= 400
    ? IntensiteJour.intense
    : kcalExercice >= 100
    ? IntensiteJour.modere
    : IntensiteJour.repos;

class CiblesJour {
  const CiblesJour({
    required this.kcal,
    required this.proteines,
    required this.glucides,
    required this.lipides,
  });

  final double kcal;
  final double proteines;
  final double glucides;
  final double lipides;
}

/// Part des calories d'exercice ajoutée à la cible du jour.
const partExerciceMangee = 0.7;

/// Repères du profil + 70 % des calories d'exercice du jour. Protéines
/// inchangées, lipides à 25 % des calories, glucides pour le reste.
CiblesJour ciblesDuJour(Reperes r, {required double kcalExercice}) {
  final kcal = r.kcalCible + partExerciceMangee * kcalExercice;
  final lipides = kcal * 0.25 / 9;
  final proteines = r.proteinesG.toDouble();
  final glucides = (kcal - proteines * 4 - lipides * 9) / 4;
  return CiblesJour(
    kcal: kcal,
    proteines: proteines,
    glucides: glucides < 0 ? 0 : glucides,
    lipides: lipides,
  );
}

Macros totalMacros(Iterable<Repas> repas) =>
    repas.fold(Macros.zero, (s, r) => s + r.macros);

/// Calories dépensées par le corps sur la part [ecoule] (0 à 1) de la
/// journée, hors activités saisies :
/// - le total de la montre s'il existe ;
/// - sinon le métabolisme de base au prorata + les calories actives de la
///   montre (même source) ;
/// - sinon le maintien au prorata (type de vie), plus les calories des
///   séances de la montre ([kcalSeances]).
double depenseCorps({
  required int depenseBase,
  required int maintien,
  double? kcalTotales,
  double? kcalActives,
  double kcalSeances = 0,
  required double ecoule,
}) {
  if ((kcalTotales ?? 0) > 0) return kcalTotales!;
  if ((kcalActives ?? 0) > 0) return depenseBase * ecoule + kcalActives!;
  return maintien * ecoule + kcalSeances;
}

/// Dépense de la journée entière : calories totales de la montre si elles
/// existent, sinon le maintien du profil (même chiffre que la cible), plus
/// les activités saisies (calories nettes) que la montre n'a pas comptées.
/// Avec [depenseBase], les calories actives de la montre remplacent le
/// maintien estimé quand il n'y a pas de total.
double depenseDuJour({
  required int maintien,
  required double? kcalMontre,
  required double kcalActivites,
  double? kcalActives,
  int? depenseBase,
}) =>
    depenseCorps(
      depenseBase: depenseBase ?? 0,
      maintien: maintien,
      kcalTotales: kcalMontre,
      kcalActives: depenseBase == null ? null : kcalActives,
      ecoule: 1,
    ) +
    kcalActivites;

/// Négatif = déficit, positif = excédent.
double solde({required double mange, required double depense}) =>
    mange - depense;

const kcalParKg = 7700.0;

/// Nombre minimal de journées complètes pour projeter le poids.
const joursMinProjection = 4;

/// Poids prévus pour les [jours] prochains jours d'après le solde moyen des
/// journées complètes ; null s'il y en a moins de [joursMin] (une moyenne sur
/// un ou deux jours serait trompeuse).
List<double>? projeterPoids({
  required double poidsKg,
  required List<double> soldes,
  int jours = 5,
  int joursMin = joursMinProjection,
}) {
  if (soldes.isEmpty || soldes.length < joursMin) return null;
  final moyenne = soldes.reduce((a, b) => a + b) / soldes.length;
  final parJour = moyenne / kcalParKg;
  return [for (var i = 1; i <= jours; i++) poidsKg + parJour * i];
}

DateTime _jourDe(DateTime d) => DateTime(d.year, d.month, d.day);

/// Repas notés au minimum pour qu'une journée du journal compte.
const repasMinJournee = 2;

/// Part de la cible du jour à atteindre pour qu'une journée du journal compte.
const partMinCible = 0.6;

/// Vrai si la journée semble entièrement notée : au moins [repasMinJournee]
/// repas et au moins [partMinCible] de [kcalCibleJour]. Une journée où seul le
/// petit-déjeuner est noté passerait sinon pour un jeûne.
bool journalComplet({
  required int nombreRepas,
  required double kcalMangees,
  required double kcalCibleJour,
}) =>
    nombreRepas >= repasMinJournee &&
    kcalMangees >= partMinCible * kcalCibleJour;

/// Solde (mangé − dépensé) de chaque journée complète du journal entre
/// [debut] (inclus) et [fin] (exclu) ; voir [journalComplet], avec pour cible
/// du jour [kcalCible] plus la part mangée des activités saisies (comme
/// [ciblesDuJour]). Les autres jours sont ignorés (journal oublié ou noté en
/// partie, pas jeûne). Dépense : le total de la montre si la journée a été
/// mesurée jusqu'au soir ([jours]), sinon le [maintien] du profil ; plus les
/// activités saisies que la montre n'a pas comptées.
List<double> soldesRecents({
  required List<Repas> repas,
  required List<Activite> activites,
  required int maintien,
  required int kcalCible,
  List<sante.JourSante> jours = const [],
  required DateTime debut,
  required DateTime fin,
}) {
  final mange = <DateTime, double>{};
  final nombre = <DateTime, int>{};
  for (final r in repas) {
    if (r.date.isBefore(debut) || !r.date.isBefore(fin)) continue;
    final jour = _jourDe(r.date);
    mange.update(jour, (v) => v + r.macros.kcal, ifAbsent: () => r.macros.kcal);
    nombre.update(jour, (n) => n + 1, ifAbsent: () => 1);
  }
  final sport = <DateTime, List<Activite>>{};
  for (final a in activites) {
    sport.putIfAbsent(_jourDe(a.date), () => []).add(a);
  }
  double saisies(DateTime jour) =>
      (sport[jour] ?? const []).fold(0.0, (s, a) => s + a.kcal);
  final montre = {
    for (final j in jours)
      if (ajustements.journeeComplete(j)) j.jour: j,
  };
  return [
    for (final e in mange.entries)
      if (journalComplet(
        nombreRepas: nombre[e.key]!,
        kcalMangees: e.value,
        kcalCibleJour: kcalCible + partExerciceMangee * saisies(e.key),
      ))
        solde(
          mange: e.value,
          depense: switch (montre[e.key]) {
            final j? =>
              j.kcalTotales! +
                  kcalActivitesNonComptees(
                    sport[e.key] ?? const [],
                    j.seances,
                    kcalTotales: j.kcalTotales,
                    derniereMesureKcal: j.derniereMesureKcal,
                  ),
            null => depenseDuJour(
              maintien: maintien,
              kcalMontre: null,
              kcalActivites: saisies(e.key),
            ),
          },
        ),
  ];
}

/// Mots des types de séance Health Connect (RUNNING, BIKING…) qui
/// correspondent à chaque type d'activité saisie. « Autre » va avec tout.
const _motsSeance = {
  TypeActivite.course: ['run', 'jog', 'course'],
  TypeActivite.velo: ['bik', 'cycl', 'velo'],
  TypeActivite.natation: ['swim', 'natation'],
  TypeActivite.marche: ['walk', 'hik', 'marche'],
  TypeActivite.musculation: ['strength', 'weight', 'muscu'],
  TypeActivite.mma: ['martial', 'box', 'wrestl', 'mma'],
};

/// Vrai si une séance de la montre de type [typeSeance] peut être l'activité
/// saisie de type [type]. Une séance sans type précis va avec tout.
bool typesProches(TypeActivite type, String typeSeance) {
  final s = typeSeance.toLowerCase();
  if (s.isEmpty || s.contains('other') || s.contains('workout')) return true;
  final mots = _motsSeance[type];
  return mots == null || mots.any(s.contains);
}

/// Durées à ±30 % près.
bool _dureesProches(int minutes, Duration duree) =>
    (duree.inMinutes - minutes).abs() <= 0.3 * minutes;

/// Calories des activités saisies que la montre n'a pas déjà comptées. Une
/// activité est déjà dans la dépense de la montre si :
/// - la montre a un total de calories mesuré au moins jusqu'à la fin de
///   l'activité ([kcalTotales], [derniereMesureKcal]) : portée, elle a compté
///   l'effort même sans mode séance ;
/// - ou une séance de la montre du même jour a un type et une durée proches,
///   quelle que soit l'heure de saisie ;
/// - ou une séance de la montre chevauche l'activité (à la durée près, avant
///   ou après l'heure de saisie).
double kcalActivitesNonComptees(
  List<Activite> activites,
  List<sante.Seance> seancesMontre, {
  double? kcalTotales,
  DateTime? derniereMesureKcal,
}) {
  var total = 0.0;
  for (final a in activites) {
    final parLeTotal =
        (kcalTotales ?? 0) > 0 &&
        derniereMesureKcal != null &&
        !derniereMesureKcal.isBefore(a.date);
    final debut = a.date.subtract(Duration(minutes: a.minutes));
    final fin = a.date.add(Duration(minutes: a.minutes));
    final parUneSeance = seancesMontre.any(
      (s) =>
          (s.debut.isBefore(fin) && s.debut.add(s.duree).isAfter(debut)) ||
          (_jourDe(s.debut) == _jourDe(a.date) &&
              typesProches(a.type, s.type) &&
              _dureesProches(a.minutes, s.duree)),
    );
    if (!parLeTotal && !parUneSeance) total += a.kcal;
  }
  return total;
}

/// Les chiffres énergétiques d'une journée, communs à l'Accueil, au Journal
/// et au widget de l'écran d'accueil.
class BilanJour {
  const BilanJour({
    required this.reperes,
    required this.kcalExercice,
    required this.cibles,
    required this.brulees,
    required this.depenseJour,
    required this.intensite,
    required this.macros,
    required this.estime,
  });

  final Reperes reperes;

  /// Exercice ajouté à la cible : ce qui dépasse l'activité habituelle.
  final double kcalExercice;
  final CiblesJour cibles;

  /// Calories brûlées jusqu'à maintenant (toute la journée pour un jour
  /// passé).
  final double brulees;

  /// Dépense de la journée, pour le bilan mangé − dépensé.
  final double depenseJour;
  final IntensiteJour intensite;
  final Macros macros;

  /// Vrai si aucune calorie n'a été mesurée par la montre : la dépense vient
  /// du type de vie.
  final bool estime;

  double get mangees => macros.kcal;

  /// Négatif = déficit, positif = excédent.
  double get ecart => solde(mange: mangees, depense: depenseJour);
}

/// Bilan de [jour] : [repas] et [activites] sont ceux de ce jour, [jours]
/// les résumés Health Connect (vide sans montre), [maintienMesure] le
/// maintien mesuré par la montre s'il existe.
///
/// Exercice ajouté à la cible, jamais les calories actives de toute la
/// journée (le maintien contient déjà l'activité habituelle) :
/// - avec un maintien mesuré : ce qui dépasse la moyenne active des 7 jours
///   précédents, plus les activités saisies non comptées par la montre ;
/// - avec une montre sans maintien mesuré : les séances de la montre, plus
///   les activités saisies non comptées ;
/// - sans montre : les calories nettes des activités saisies.
BilanJour bilanDuJour({
  required Profil profil,
  required List<sante.JourSante> jours,
  double? maintienMesure,
  required List<Repas> repas,
  required List<Activite> activites,
  required DateTime jour,
  required DateTime maintenant,
}) {
  final leJour = _jourDe(jour);
  final reperes = calculerReperes(
    profil,
    maintenant: maintenant,
    maintienMesure: maintienMesure,
  );
  final jourSante = jours.where((j) => j.jour == leJour).firstOrNull;
  final kcalTotales = jourSante?.kcalTotales;
  final kcalActives = jourSante?.kcalActives;
  final seances = jourSante?.seances ?? const <sante.Seance>[];
  final mesure = (kcalTotales ?? 0) > 0 || (kcalActives ?? 0) > 0;
  final kcalSeances = seances.fold<double>(0, (s, x) => s + (x.kcal ?? 0));

  final saisies = jourSante == null
      ? activites.fold<double>(0, (s, a) => s + a.kcal)
      : kcalActivitesNonComptees(
          activites,
          seances,
          kcalTotales: kcalTotales,
          derniereMesureKcal: jourSante.derniereMesureKcal,
        );

  var exerciceMontre = 0.0;
  if (maintienMesure != null && kcalActives != null) {
    final moyenne = ajustements.moyenneActive(
      jours,
      aujourdhui: leJour,
      depenseBase: reperes.depenseBase,
    );
    if (moyenne != null && kcalActives > moyenne) {
      exerciceMontre = kcalActives - moyenne;
    }
  } else if (maintienMesure == null) {
    exerciceMontre = kcalSeances;
  }
  final kcalExercice = exerciceMontre + saisies;

  final aujourdhui = _jourDe(maintenant);
  final ecoule = leJour.isBefore(aujourdhui)
      ? 1.0
      : leJour.isAfter(aujourdhui)
      ? 0.0
      : (maintenant.hour * 60 + maintenant.minute) / 1440;
  double corps(double part) => depenseCorps(
    depenseBase: reperes.depenseBase,
    maintien: reperes.maintien,
    kcalTotales: kcalTotales,
    kcalActives: kcalActives,
    kcalSeances: kcalSeances,
    ecoule: part,
  );

  return BilanJour(
    reperes: reperes,
    kcalExercice: kcalExercice,
    cibles: ciblesDuJour(reperes, kcalExercice: kcalExercice),
    brulees: corps(ecoule) + saisies,
    depenseJour: corps(1) + saisies,
    intensite: intensiteDuJour(kcalExercice),
    macros: totalMacros(repas),
    estime: !mesure,
  );
}
