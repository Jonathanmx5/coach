import '../profil/besoins.dart';
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

/// Calories d'une activité : MET × facteur d'intensité × poids × heures.
double kcalActivite(
  TypeActivite type,
  int minutes,
  Intensite intensite,
  double poidsKg,
) => _met[type]! * _facteurIntensite[intensite]! * poidsKg * minutes / 60;

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

/// Repères du profil + 70 % des calories d'exercice du jour. Protéines
/// inchangées, lipides à 25 % des calories, glucides pour le reste.
CiblesJour ciblesDuJour(Reperes r, {required double kcalExercice}) {
  final kcal = r.kcalCible + 0.7 * kcalExercice;
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

/// Dépense du jour : calories totales de la montre si elles existent, sinon le
/// métabolisme de base × 1,2 (vie sans exercice), plus les activités saisies.
double depenseDuJour({
  required int depenseBase,
  required double? kcalMontre,
  required double kcalActivites,
}) => ((kcalMontre ?? 0) > 0 ? kcalMontre! : depenseBase * 1.2) + kcalActivites;

/// Négatif = déficit, positif = excédent.
double solde({required double mange, required double depense}) =>
    mange - depense;

const kcalParKg = 7700.0;

/// Poids prévus pour les [jours] prochains jours d'après le solde moyen des
/// jours renseignés ; null s'il n'y a aucun jour.
List<double>? projeterPoids({
  required double poidsKg,
  required List<double> soldes,
  int jours = 5,
}) {
  if (soldes.isEmpty) return null;
  final moyenne = soldes.reduce((a, b) => a + b) / soldes.length;
  final parJour = moyenne / kcalParKg;
  return [for (var i = 1; i <= jours; i++) poidsKg + parJour * i];
}

/// Solde (mangé − dépensé) de chaque jour entre [debut] (inclus) et [fin]
/// (exclu) où au moins un repas est noté ; les jours sans repas sont ignorés
/// (journal oublié, pas jeûne). Dépense = base × 1,2 + activités saisies.
List<double> soldesRecents({
  required List<Repas> repas,
  required List<Activite> activites,
  required int depenseBase,
  required DateTime debut,
  required DateTime fin,
}) {
  DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);
  final mange = <DateTime, double>{};
  for (final r in repas) {
    if (r.date.isBefore(debut) || !r.date.isBefore(fin)) continue;
    mange.update(
      jour(r.date),
      (v) => v + r.macros.kcal,
      ifAbsent: () => r.macros.kcal,
    );
  }
  final sport = <DateTime, double>{};
  for (final a in activites) {
    sport.update(jour(a.date), (v) => v + a.kcal, ifAbsent: () => a.kcal);
  }
  return [
    for (final e in mange.entries)
      solde(
        mange: e.value,
        depense: depenseDuJour(
          depenseBase: depenseBase,
          kcalMontre: null,
          kcalActivites: sport[e.key] ?? 0,
        ),
      ),
  ];
}
