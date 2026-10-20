import 'package:coach/journal/modele.dart';
import 'package:coach/poids/pesees.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';

/// Mardi 20 octobre, 15 h : la semaine nutrition va du 13 au 19, les
/// séances et le poids du 14 au 20.
final maintenant = DateTime(2026, 10, 20, 15);

const profil = Profil(
  objectif: Objectif.forme,
  sexe: Sexe.homme,
  anneeNaissance: 1996,
  tailleCm: 180,
  poidsKg: 80,
  typeDeVie: TypeDeVie.peuActif,
  typesEntrainement: {TypeEntrainement.salle},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 45,
);

/// Cible du jour sans exercice.
final cible = calculerReperes(profil, maintenant: maintenant).kcalCible;

Repas repas(int jour, double kcal, {double proteines = 0, int heure = 12}) =>
    Repas(
      date: DateTime(2026, 10, jour, heure),
      moment: Moment.dejeuner,
      nom: 'repas',
      macros: Macros(kcal: kcal, proteines: proteines),
      source: SourceRepas.manuel,
    );

Activite activite(int jour, {double kcal = 200}) => Activite(
  date: DateTime(2026, 10, jour, 18),
  type: TypeActivite.musculation,
  minutes: 45,
  intensite: Intensite.moderee,
  kcal: kcal,
);

Pesee pesee(int jour, double kg) => Pesee(
  date: DateTime(2026, 10, jour, 7),
  kg: kg,
  source: SourcePesee.manuel,
);
