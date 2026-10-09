import 'package:flutter/foundation.dart';

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

const _facteurs = {
  TypeDeVie.sedentaire: 1.2,
  TypeDeVie.peuActif: 1.375,
  TypeDeVie.actif: 1.55,
  TypeDeVie.tresActif: 1.725,
};

const _deficitMax = 500.0;

/// [maintienMesure] : moyenne des calories totales mesurées par la montre ;
/// remplace l'estimation par type de vie (spec santé connectée §4).
Reperes calculerReperes(
  Profil p, {
  required DateTime maintenant,
  double? maintienMesure,
}) {
  // Mifflin-St Jeor.
  final base =
      10 * p.poidsKg +
      6.25 * p.tailleCm -
      5 * p.age(maintenant) +
      (p.sexe == Sexe.homme ? 5 : -161);
  final maintien = maintienMesure ?? base * _facteurs[p.typeDeVie]!;

  final cible = switch (p.objectif) {
    Objectif.perte => maintien - (0.15 * maintien).clamp(0, _deficitMax),
    Objectif.muscle => maintien * 1.10,
    Objectif.forme || Objectif.reprise => maintien,
  };
  final plancher = p.sexe == Sexe.femme ? 1200.0 : 1500.0;
  final cibleSure = cible < plancher ? plancher : cible;

  final grammesParKg = switch (p.objectif) {
    Objectif.perte || Objectif.muscle => 1.6,
    Objectif.forme || Objectif.reprise => 1.2,
  };

  return Reperes(
    depenseBase: base.round(),
    maintien: maintien.round(),
    kcalCible: (cibleSure / 10).round() * 10,
    proteinesG: (grammesParKg * p.poidsKg).round(),
    source: maintienMesure == null
        ? SourceMaintien.estime
        : SourceMaintien.mesure,
  );
}
