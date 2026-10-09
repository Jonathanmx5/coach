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

List<JourSante> agregerParJour(
  List<PointSante> points, {
  required DateTime debut,
  required DateTime fin,
}) {
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

JourSante _resumerJour(DateTime jour, List<PointSante> points) {
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
    pas: somme(TypeMesure.pas)?.round(),
    distanceM: somme(TypeMesure.distance),
    etages: somme(TypeMesure.etages)?.round(),
    kcalActives: somme(TypeMesure.kcalActives),
    kcalTotales: somme(TypeMesure.kcalTotales),
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
