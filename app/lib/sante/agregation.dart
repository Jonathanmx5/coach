import 'modele.dart';

/// Spec santé connectée §4 : agrégation par jour local, sommeil rattaché au
/// jour où la nuit se termine.

DateTime jourDe(DateTime t) => DateTime(t.year, t.month, t.day);

const _phasesSommeil = {
  TypeMesure.sommeilProfond,
  TypeMesure.sommeilLeger,
  TypeMesure.sommeilParadoxal,
  TypeMesure.sommeilEveil,
  TypeMesure.sommeilEndormi,
};

/// Les mesures qui s'additionnent sur un intervalle : si l'intervalle se
/// prolonge dans le futur, seule la part déjà écoulée compte.
const _additives = {
  TypeMesure.pas,
  TypeMesure.distance,
  TypeMesure.etages,
  TypeMesure.kcalActives,
  TypeMesure.kcalTotales,
};

/// Coupe à [maintenant] les points additifs qui dépassent. Google Fit écrit
/// par exemple un total de calories « de 7 h 13 à minuit » dès le matin :
/// sans ce découpage, la journée afficherait plus de calories brûlées qu'elle
/// n'a eu le temps d'en brûler. Une valeur est répartie à égalité sur la durée.
List<PointSante> couperAuPresent(List<PointSante> points, DateTime maintenant) {
  final sortie = <PointSante>[];
  for (final p in points) {
    if (!_additives.contains(p.type) || !p.fin.isAfter(maintenant)) {
      sortie.add(p);
      continue;
    }
    if (!p.debut.isBefore(maintenant)) continue; // entièrement dans le futur
    final total = p.fin.difference(p.debut).inMicroseconds;
    final ecoule = maintenant.difference(p.debut).inMicroseconds;
    sortie.add(
      PointSante(
        type: p.type,
        debut: p.debut,
        fin: maintenant,
        valeur: total <= 0 ? p.valeur : p.valeur * ecoule / total,
        libelle: p.libelle,
      ),
    );
  }
  return sortie;
}

List<JourSante> agregerParJour(
  List<PointSante> points, {
  required DateTime debut,
  required DateTime fin,
  DateTime? maintenant,
}) {
  if (maintenant != null) points = couperAuPresent(points, maintenant);
  final parJour = <DateTime, List<PointSante>>{};
  for (final p in points) {
    // Le sommeil compte pour le jour du réveil, le reste pour le jour du début.
    final cle = _phasesSommeil.contains(p.type)
        ? jourDe(p.fin)
        : jourDe(p.debut);
    parJour.putIfAbsent(cle, () => []).add(p);
  }

  final jours = <JourSante>[];
  for (
    var j = jourDe(debut);
    !j.isAfter(jourDe(fin));
    j = DateTime(j.year, j.month, j.day + 1)
  ) {
    jours.add(_resumerJour(j, parJour[j] ?? const []));
  }
  return jours;
}

/// Total d'une mesure additive pour un jour. Plusieurs applications peuvent
/// écrire la même mesure (pas du téléphone et de la montre, calories de Google
/// Fit et de Mi Fitness) : les additionner la compterait deux fois. On garde
/// donc le total de la source la plus complète du jour, jamais la somme.
({double? valeur, String? source, DateTime? derniere}) _total(
  List<PointSante> points,
  TypeMesure type,
) {
  final parSource = <String?, List<PointSante>>{};
  for (final p in points.where((p) => p.type == type)) {
    parSource.putIfAbsent(p.source, () => []).add(p);
  }
  if (parSource.isEmpty) return (valeur: null, source: null, derniere: null);
  String? meilleure;
  var total = -1.0;
  for (final e in parSource.entries) {
    final s = e.value.fold<double>(0, (a, p) => a + p.valeur);
    if (s > total) {
      total = s;
      meilleure = e.key;
    }
  }
  final derniere = parSource[meilleure]!
      .map((p) => p.fin)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  return (valeur: total, source: meilleure, derniere: derniere);
}

JourSante _resumerJour(DateTime jour, List<PointSante> points) {
  final pas = _total(points, TypeMesure.pas);
  final distance = _total(points, TypeMesure.distance);
  final etages = _total(points, TypeMesure.etages);
  final actives = _total(points, TypeMesure.kcalActives);
  final totales = _total(points, TypeMesure.kcalTotales);
  List<PointSante> de(TypeMesure t) =>
      points.where((p) => p.type == t).toList();
  double? somme(TypeMesure t) {
    final l = de(t);
    return l.isEmpty ? null : l.fold<double>(0, (s, p) => s + p.valeur);
  }

  double? moyenne(TypeMesure t) {
    final l = de(t);
    return l.isEmpty ? null : somme(t)! / l.length;
  }

  double? derniere(TypeMesure t) {
    final l = de(t)..sort((a, b) => a.fin.compareTo(b.fin));
    return l.isEmpty ? null : l.last.valeur;
  }

  return JourSante(
    jour: jour,
    pas: pas.valeur?.round(),
    distanceM: distance.valeur,
    etages: etages.valeur?.round(),
    kcalActives: actives.valeur,
    kcalTotales: totales.valeur,
    sourceKcal: totales.source ?? actives.source,
    derniereMesureKcal: totales.derniere ?? actives.derniere,
    sourcePas: pas.source,
    fcMoyenne: moyenne(TypeMesure.fc),
    fcRepos: derniere(TypeMesure.fcRepos),
    variabiliteMs: derniere(TypeMesure.variabilite),
    spo2: derniere(TypeMesure.spo2),
    freqResp: derniere(TypeMesure.freqResp),
    sommeil: resumerSommeil(
      points.where((p) => _phasesSommeil.contains(p.type)).toList(),
    ),
    seances: [
      for (final p in de(
        TypeMesure.seance,
      )..sort((a, b) => a.debut.compareTo(b.debut)))
        Seance(
          type: p.libelle ?? '',
          debut: p.debut,
          duree: p.fin.difference(p.debut),
          kcal: p.valeur > 0 ? p.valeur : null,
        ),
    ],
  );
}

/// Résumé d'une nuit ; les intervalles qui se chevauchent ne comptent qu'une
/// fois (plusieurs sources peuvent enregistrer la même nuit).
ResumeSommeil? resumerSommeil(List<PointSante> segments) {
  if (segments.isEmpty) return null;
  Duration duree(TypeMesure t) =>
      _dureeFusionnee(segments.where((s) => s.type == t));

  final profond = duree(TypeMesure.sommeilProfond);
  final leger = duree(TypeMesure.sommeilLeger);
  final paradoxal = duree(TypeMesure.sommeilParadoxal);
  final phases = profond + leger + paradoxal;
  return ResumeSommeil(
    endormi: phases > Duration.zero ? phases : duree(TypeMesure.sommeilEndormi),
    profond: profond,
    leger: leger,
    paradoxal: paradoxal,
    eveil: duree(TypeMesure.sommeilEveil),
  );
}

Duration _dureeFusionnee(Iterable<PointSante> segments) {
  final tries = segments.toList()..sort((a, b) => a.debut.compareTo(b.debut));
  var total = Duration.zero;
  DateTime? debut;
  DateTime? fin;
  for (final s in tries) {
    if (fin == null || s.debut.isAfter(fin)) {
      if (debut != null) total += fin!.difference(debut);
      debut = s.debut;
      fin = s.fin;
    } else if (s.fin.isAfter(fin)) {
      fin = s.fin;
    }
  }
  if (debut != null) total += fin!.difference(debut);
  return total;
}

List<Mesure> mesures(List<PointSante> points, TypeMesure type) => [
  for (final p in points.where((p) => p.type == type))
    Mesure(date: p.fin, valeur: p.valeur),
]..sort((a, b) => a.date.compareTo(b.date));
