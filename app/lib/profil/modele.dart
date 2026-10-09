import 'package:flutter/foundation.dart';

enum Objectif { perte, muscle, forme, reprise }

enum Sexe { homme, femme }

enum TypeDeVie { sedentaire, peuActif, actif, tresActif }

enum TypeEntrainement { salle, maison, course, marche }

enum Niveau { debutant, reprise, regulier }

/// Application qui accompagne la montre ou le bracelet.
enum AppMontre { googleFit, samsungHealth, miFitness, fitbit, garmin, autre }

/// Réponses du questionnaire de départ (spec §3).
@immutable
class Profil {
  const Profil({
    required this.objectif,
    required this.sexe,
    required this.anneeNaissance,
    required this.tailleCm,
    required this.poidsKg,
    required this.typeDeVie,
    required this.typesEntrainement,
    required this.niveau,
    required this.joursParSemaine,
    required this.dureeSeanceMin,
    required this.problemeSante,
    this.montre = false,
    this.appMontre,
    this.poidsDate,
  });

  final Objectif objectif;
  final Sexe sexe;
  final int anneeNaissance;
  final int tailleCm;
  final double poidsKg;
  final TypeDeVie typeDeVie;
  final Set<TypeEntrainement> typesEntrainement;
  final Niveau niveau;
  final int joursParSemaine;
  final int dureeSeanceMin;
  final bool problemeSante;
  final bool montre;
  final AppMontre? appMontre;

  /// Date de la pesée connue (saisie ou importée de Health Connect).
  final DateTime? poidsDate;

  int age(DateTime maintenant) => maintenant.year - anneeNaissance;

  Profil copyWith({
    Objectif? objectif,
    Sexe? sexe,
    int? anneeNaissance,
    int? tailleCm,
    double? poidsKg,
    TypeDeVie? typeDeVie,
    Set<TypeEntrainement>? typesEntrainement,
    Niveau? niveau,
    int? joursParSemaine,
    int? dureeSeanceMin,
    bool? problemeSante,
    bool? montre,
    AppMontre? appMontre,
    bool effacerAppMontre = false,
    DateTime? poidsDate,
  }) => Profil(
    objectif: objectif ?? this.objectif,
    sexe: sexe ?? this.sexe,
    anneeNaissance: anneeNaissance ?? this.anneeNaissance,
    tailleCm: tailleCm ?? this.tailleCm,
    poidsKg: poidsKg ?? this.poidsKg,
    typeDeVie: typeDeVie ?? this.typeDeVie,
    typesEntrainement: typesEntrainement ?? this.typesEntrainement,
    niveau: niveau ?? this.niveau,
    joursParSemaine: joursParSemaine ?? this.joursParSemaine,
    dureeSeanceMin: dureeSeanceMin ?? this.dureeSeanceMin,
    problemeSante: problemeSante ?? this.problemeSante,
    montre: montre ?? this.montre,
    appMontre: effacerAppMontre ? null : appMontre ?? this.appMontre,
    poidsDate: poidsDate ?? this.poidsDate,
  );

  Map<String, Object?> toMap() => {
    'objectif': objectif.name,
    'sexe': sexe.name,
    'anneeNaissance': anneeNaissance,
    'tailleCm': tailleCm,
    'poidsKg': poidsKg,
    'typeDeVie': typeDeVie.name,
    'typesEntrainement':
        (typesEntrainement.toList()..sort((a, b) => a.index.compareTo(b.index)))
            .map((t) => t.name)
            .toList(),
    'niveau': niveau.name,
    'joursParSemaine': joursParSemaine,
    'dureeSeanceMin': dureeSeanceMin,
    'problemeSante': problemeSante,
    'montre': montre,
    'appMontre': appMontre?.name,
    'poidsDate': poidsDate?.millisecondsSinceEpoch,
  };

  static Profil fromMap(Map<String, Object?> m) => Profil(
    objectif: Objectif.values.byName(m['objectif']! as String),
    sexe: Sexe.values.byName(m['sexe']! as String),
    anneeNaissance: (m['anneeNaissance']! as num).toInt(),
    tailleCm: (m['tailleCm']! as num).toInt(),
    poidsKg: (m['poidsKg']! as num).toDouble(),
    typeDeVie: TypeDeVie.values.byName(m['typeDeVie']! as String),
    typesEntrainement: (m['typesEntrainement']! as List)
        .map((t) => TypeEntrainement.values.byName(t as String))
        .toSet(),
    niveau: Niveau.values.byName(m['niveau']! as String),
    joursParSemaine: (m['joursParSemaine']! as num).toInt(),
    dureeSeanceMin: (m['dureeSeanceMin']! as num).toInt(),
    problemeSante: m['problemeSante']! as bool,
    // Profils antérieurs à la santé connectée : champs absents.
    montre: m['montre'] as bool? ?? false,
    appMontre: AppMontre.values.asNameMap()[m['appMontre']],
    poidsDate: switch (m['poidsDate']) {
      final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
      _ => null,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is Profil &&
      other.objectif == objectif &&
      other.sexe == sexe &&
      other.anneeNaissance == anneeNaissance &&
      other.tailleCm == tailleCm &&
      other.poidsKg == poidsKg &&
      other.typeDeVie == typeDeVie &&
      setEquals(other.typesEntrainement, typesEntrainement) &&
      other.niveau == niveau &&
      other.joursParSemaine == joursParSemaine &&
      other.dureeSeanceMin == dureeSeanceMin &&
      other.problemeSante == problemeSante &&
      other.montre == montre &&
      other.appMontre == appMontre &&
      other.poidsDate == poidsDate;

  @override
  int get hashCode => Object.hash(
    objectif,
    sexe,
    anneeNaissance,
    tailleCm,
    poidsKg,
    typeDeVie,
    Object.hashAllUnordered(typesEntrainement),
    niveau,
    joursParSemaine,
    dureeSeanceMin,
    problemeSante,
    montre,
    appMontre,
    poidsDate,
  );
}
