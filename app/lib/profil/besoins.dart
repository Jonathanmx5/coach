import 'package:flutter/foundation.dart';

import 'garde_fous.dart';
import 'modele.dart';

/// D'où vient le maintien : formule (type de vie) ou calories mesurées.
enum SourceMaintien { estime, mesure }

/// Repères énergétiques du jour (spec §3), en kcal et grammes.
@immutable
class Reperes {
  const Reperes({
    required this.depenseBase,
    required this.maintien,
    required this.kcalCible,
    required this.proteinesG,
    this.source = SourceMaintien.estime,
  });

  final int depenseBase;
  final int maintien;
  final int kcalCible;
  final int proteinesG;
  final SourceMaintien source;

  Map<String, Object?> toMap() => {
    'depenseBase': depenseBase,
    'maintien': maintien,
    'kcalCible': kcalCible,
    'proteinesG': proteinesG,
    'source': source.name,
  };

  static Reperes fromMap(Map<String, Object?> m) => Reperes(
    depenseBase: (m['depenseBase']! as num).toInt(),
    maintien: (m['maintien']! as num).toInt(),
    kcalCible: (m['kcalCible']! as num).toInt(),
    proteinesG: (m['proteinesG']! as num).toInt(),
    source:
        SourceMaintien.values.asNameMap()[m['source']] ?? SourceMaintien.estime,
  );

  @override
  bool operator ==(Object other) =>
      other is Reperes &&
      other.depenseBase == depenseBase &&
      other.maintien == maintien &&
      other.kcalCible == kcalCible &&
      other.proteinesG == proteinesG &&
      other.source == source;

  @override
  int get hashCode =>
      Object.hash(depenseBase, maintien, kcalCible, proteinesG, source);

  @override
  String toString() =>
      'Reperes(base: $depenseBase, maintien: $maintien, cible: $kcalCible, '
      'protéines: $proteinesG, source: ${source.name})';
}

const _deficitMax = 500.0;

/// Part du maintien retirée pour perdre du poids.
const partDeficit = 0.15;

/// Perte suivie par un médecin : déficit plus doux, à ajuster avec lui.
const partDeficitMedecin = 0.10;

/// Recomposition : léger déficit, protéines élevées.
const partDeficitRecomposition = 0.10;

/// À partir de cet IMC, « prendre du muscle » devient une recomposition :
/// un surplus ferait surtout prendre du gras.
const imcRecomposition = 27.0;

/// Au-delà de cet IMC, les protéines sont calculées sur le poids de
/// référence (celui d'un IMC de [imcReference]) plutôt que sur le poids
/// total.
const imcPoidsReference = 30.0;
const imcReference = 25.0;

/// Énergie d'un kilo de poids corporel, en kcal.
const kcalParKgCorps = 7700.0;

/// Vrai si l'objectif muscle est traité en recomposition (IMC ≥ 27) : léger
/// déficit et protéines élevées. Pas quand la perte est déconseillée
/// (grossesse…) : la cible reste alors le maintien, sans surplus.
bool estRecomposition(Profil p) => _muscleEnSurpoids(p) && !p.perteDeconseillee;

bool _muscleEnSurpoids(Profil p) =>
    p.objectif == Objectif.muscle &&
    imc(p.poidsKg, p.tailleCm) >= imcRecomposition;

/// Poids servant au calcul des protéines : le poids total, ou celui d'un IMC
/// de 25 au-delà d'un IMC de 30 (des chiffres irréalistes sinon).
double poidsReferenceProteines(Profil p) {
  if (imc(p.poidsKg, p.tailleCm) <= imcPoidsReference) return p.poidsKg;
  final metres = p.tailleCm / 100;
  return imcReference * metres * metres;
}

/// [maintienMesure] : moyenne des calories totales mesurées par la montre ;
/// remplace l'estimation par type de vie (spec santé connectée §4).
Reperes calculerReperes(
  Profil p, {
  required DateTime maintenant,
  double? maintienMesure,
}) {
  final base = metabolismeBase(p, maintenant);
  final maintien = maintienMesure ?? maintienEstime(p, maintenant);
  final recomposition = estRecomposition(p);

  final cible = switch (p.objectif) {
    Objectif.perte =>
      maintien -
          ((p.precautions.contains(Precaution.perteSuivieMedecin)
                      ? partDeficitMedecin
                      : partDeficit) *
                  maintien)
              .clamp(0, _deficitMax),
    Objectif.muscle when recomposition =>
      maintien - partDeficitRecomposition * maintien,
    Objectif.muscle when _muscleEnSurpoids(p) => maintien,
    Objectif.muscle => maintien * 1.10,
    Objectif.forme || Objectif.reprise => maintien,
  };
  final plancher = plancherKcal(p.sexe);
  final cibleSure = cible < plancher ? plancher : cible;

  final grammesParKg = switch (p.objectif) {
    Objectif.muscle when recomposition => 2.0,
    Objectif.perte || Objectif.muscle => 1.6,
    Objectif.forme || Objectif.reprise => 1.2,
  };

  return Reperes(
    depenseBase: base.round(),
    maintien: maintien.round(),
    kcalCible: (cibleSure / 10).round() * 10,
    proteinesG: (grammesParKg * poidsReferenceProteines(p)).round(),
    source: maintienMesure == null
        ? SourceMaintien.estime
        : SourceMaintien.mesure,
  );
}

/// Variation de poids attendue par semaine (kg, négative pour une perte) si
/// la cible est tenue ; 0 pour un objectif de maintien.
double rythmeKgParSemaine(Reperes r) =>
    (r.kcalCible - r.maintien) * 7 / kcalParKgCorps;

/// Sous ce rythme (kg par semaine), le poids est considéré stable.
const rythmeStable = 0.05;

/// Au-delà, la date n'aurait pas de sens (plus de trois ans).
const semainesMaxEstimation = 156;

/// Date estimée pour atteindre [poidsCibleKg] au [rythme] donné ; null sans
/// poids cible, si le rythme est stable, s'il va dans l'autre sens ou si la
/// date dépasse [semainesMaxEstimation].
DateTime? dateEstimee({
  required double poidsKg,
  required double? poidsCibleKg,
  required double rythme,
  required DateTime maintenant,
}) {
  if (poidsCibleKg == null || rythme.abs() < rythmeStable) return null;
  final ecart = poidsCibleKg - poidsKg;
  if (ecart.abs() < 0.1 || ecart * rythme <= 0) return null;
  final semaines = ecart / rythme;
  if (semaines > semainesMaxEstimation) return null;
  return DateTime(
    maintenant.year,
    maintenant.month,
    maintenant.day + (semaines * 7).ceil(),
  );
}
