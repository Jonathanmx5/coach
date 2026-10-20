import 'modele.dart';

/// Spec santé connectée §4 : agrégation par jour local, sommeil rattaché au
/// jour où la nuit se termine.

DateTime jourDe(DateTime t) => DateTime(t.year, t.month, t.day);

/// Tout ce qui décrit le sommeil : les phases et la session qui les contient.
const _sommeil = {
  TypeMesure.sommeilProfond,
  TypeMesure.sommeilLeger,
  TypeMesure.sommeilParadoxal,
  TypeMesure.sommeilEveil,
  TypeMesure.sommeilEndormi,
  TypeMesure.sommeilSession,
};

/// Les phases où l'on dort (l'éveil et la session n'en sont pas).
const _phasesEndormies = {
  TypeMesure.sommeilProfond,
  TypeMesure.sommeilLeger,
  TypeMesure.sommeilParadoxal,
  TypeMesure.sommeilEndormi,
};

/// Deux morceaux de sommeil séparés de moins que ce délai font la même nuit.
const _ecartNuit = Duration(hours: 2);

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
        source: p.source,
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
    if (_sommeil.contains(p.type)) continue;
    parJour.putIfAbsent(jourDe(p.debut), () => []).add(p);
  }
  // Le sommeil compte pour le jour du réveil : une nuit entière, phases
  // d'avant minuit comprises, va au jour où elle se termine.
  final nuitsParJour = <DateTime, List<List<PointSante>>>{};
  for (final nuit in nuits(points.where((p) => _sommeil.contains(p.type)))) {
    nuitsParJour.putIfAbsent(jourDe(nuit.fin), () => []).add(nuit.points);
  }

  final jours = <JourSante>[];
  for (
    var j = jourDe(debut);
    !j.isAfter(jourDe(fin));
    j = DateTime(j.year, j.month, j.day + 1)
  ) {
    jours.add(
      _resumerJour(j, parJour[j] ?? const [], nuitsParJour[j] ?? const []),
    );
  }
  return jours;
}

/// Une nuit (ou une sieste) : l'heure du réveil et ses points.
typedef Nuit = ({DateTime fin, List<PointSante> points});

/// Regroupe les points de sommeil en nuits :
/// - une session et les phases qui la chevauchent forment une nuit (des
///   sessions qui se chevauchent, écrites par plusieurs applications, aussi) ;
/// - les phases hors session séparées de moins de 2 h forment une nuit.
List<Nuit> nuits(Iterable<PointSante> sommeil) {
  final sessions =
      sommeil.where((p) => p.type == TypeMesure.sommeilSession).toList()
        ..sort((a, b) => a.debut.compareTo(b.debut));
  final phases =
      sommeil.where((p) => p.type != TypeMesure.sommeilSession).toList()
        ..sort((a, b) => a.debut.compareTo(b.debut));

  final blocs = <({DateTime debut, DateTime fin, List<PointSante> points})>[];
  for (final s in sessions) {
    final dernier = blocs.lastOrNull;
    if (dernier != null && s.debut.isBefore(dernier.fin)) {
      blocs.last = (
        debut: dernier.debut,
        fin: s.fin.isAfter(dernier.fin) ? s.fin : dernier.fin,
        points: dernier.points..add(s),
      );
    } else {
      blocs.add((debut: s.debut, fin: s.fin, points: [s]));
    }
  }
  final nbSessions = blocs.length;

  for (final p in phases) {
    final session = blocs
        .take(nbSessions)
        .where((b) => p.debut.isBefore(b.fin) && p.fin.isAfter(b.debut))
        .firstOrNull;
    if (session != null) {
      session.points.add(p);
      continue;
    }
    final dernier = blocs.length > nbSessions ? blocs.last : null;
    if (dernier != null && p.debut.difference(dernier.fin) < _ecartNuit) {
      blocs.last = (
        debut: dernier.debut,
        fin: p.fin.isAfter(dernier.fin) ? p.fin : dernier.fin,
        points: dernier.points..add(p),
      );
    } else {
      blocs.add((debut: p.debut, fin: p.fin, points: [p]));
    }
  }
  return [for (final b in blocs) (fin: b.fin, points: b.points)];
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

JourSante _resumerJour(
  DateTime jour,
  List<PointSante> points,
  List<List<PointSante>> nuitsDuJour,
) {
  final pas = _total(points, TypeMesure.pas);
  final distance = _total(points, TypeMesure.distance);
  final etages = _total(points, TypeMesure.etages);
  final actives = _total(points, TypeMesure.kcalActives);
  final totales = _total(points, TypeMesure.kcalTotales);
  List<PointSante> de(TypeMesure t) =>
      points.where((p) => p.type == t).toList();
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
    fcRepos: derniere(TypeMesure.fcRepos),
    variabiliteMs: derniere(TypeMesure.variabilite),
    spo2: derniere(TypeMesure.spo2),
    freqResp: derniere(TypeMesure.freqResp),
    sommeil: _additionnerNuits([
      for (final n in nuitsDuJour) ?resumerSommeil(n),
    ]),
    seances: _seances(
      de(TypeMesure.seance),
      actives: [
        for (final p in de(TypeMesure.kcalActives))
          if (p.source == actives.source) p,
      ],
      principale: actives.source ?? totales.source,
    ),
  );
}

/// Durée commune à [debut, fin] et à [p].
Duration _chevauchement(DateTime debut, DateTime fin, PointSante p) {
  final d = p.debut.isAfter(debut) ? p.debut : debut;
  final f = p.fin.isBefore(fin) ? p.fin : fin;
  return f.isAfter(d) ? f.difference(d) : Duration.zero;
}

/// Séances du jour :
/// - une même séance écrite par deux applications (recouvrement de plus de
///   la moitié de la plus courte) n'est gardée qu'une fois, de préférence
///   celle de la source principale du jour ;
/// - ses calories sont les calories actives de la source retenue pour le
///   jour, au prorata de leur chevauchement avec la séance (jamais les
///   calories totales, qui comprennent le métabolisme de base).
List<Seance> _seances(
  List<PointSante> points, {
  required List<PointSante> actives,
  required String? principale,
}) {
  final candidates = [...points]
    ..sort((a, b) {
      final pa = a.source == principale ? 0 : 1;
      final pb = b.source == principale ? 0 : 1;
      if (pa != pb) return pa - pb;
      return b.fin.difference(b.debut).compareTo(a.fin.difference(a.debut));
    });
  final gardees = <PointSante>[];
  for (final p in candidates) {
    final doublon = gardees.any((g) {
      if (g.source == p.source) return false;
      final commun = _chevauchement(g.debut, g.fin, p);
      final dg = g.fin.difference(g.debut);
      final dp = p.fin.difference(p.debut);
      final plusCourte = dg < dp ? dg : dp;
      return plusCourte > Duration.zero && commun * 2 > plusCourte;
    });
    if (!doublon) gardees.add(p);
  }
  gardees.sort((a, b) => a.debut.compareTo(b.debut));

  return [
    for (final p in gardees)
      Seance(
        type: p.libelle ?? '',
        debut: p.debut,
        duree: p.fin.difference(p.debut),
        kcal: _kcalSeance(p, actives),
      ),
  ];
}

double? _kcalSeance(PointSante seance, List<PointSante> actives) {
  var kcal = 0.0;
  for (final a in actives) {
    final commun = _chevauchement(seance.debut, seance.fin, a);
    if (commun == Duration.zero) continue;
    final duree = a.fin.difference(a.debut);
    kcal += duree <= Duration.zero
        ? a.valeur
        : a.valeur * commun.inMicroseconds / duree.inMicroseconds;
  }
  return kcal > 0 ? kcal : null;
}

/// Plusieurs nuits le même jour (une sieste après la nuit) : additionnées.
ResumeSommeil? _additionnerNuits(List<ResumeSommeil> resumes) {
  if (resumes.isEmpty) return null;
  if (resumes.length == 1) return resumes.single;
  Duration somme(Duration Function(ResumeSommeil) champ) =>
      resumes.fold(Duration.zero, (s, r) => s + champ(r));
  return ResumeSommeil(
    endormi: somme((r) => r.endormi),
    profond: somme((r) => r.profond),
    leger: somme((r) => r.leger),
    paradoxal: somme((r) => r.paradoxal),
    eveil: somme((r) => r.eveil),
  );
}

/// Résumé d'une nuit. Plusieurs applications peuvent l'enregistrer, et
/// classer différemment la même minute : on ne garde que la source qui couvre
/// le plus longtemps la nuit. Le temps endormi est l'union de ses phases
/// endormies (une minute ne compte qu'une fois) ; une session sans phases
/// compte pour sa durée, moins les éveils.
ResumeSommeil? resumerSommeil(List<PointSante> segments) {
  if (segments.isEmpty) return null;
  final parSource = <String?, List<PointSante>>{};
  for (final s in segments) {
    parSource.putIfAbsent(s.source, () => []).add(s);
  }
  var retenus = parSource.values.first;
  var couverture = _dureeFusionnee(retenus);
  for (final l in parSource.values.skip(1)) {
    final c = _dureeFusionnee(l);
    if (c > couverture) {
      couverture = c;
      retenus = l;
    }
  }

  Duration duree(TypeMesure t) =>
      _dureeFusionnee(retenus.where((s) => s.type == t));
  final eveil = duree(TypeMesure.sommeilEveil);
  var endormi = _dureeFusionnee(
    retenus.where((s) => _phasesEndormies.contains(s.type)),
  );
  if (endormi == Duration.zero) {
    final session = duree(TypeMesure.sommeilSession);
    if (session > eveil) endormi = session - eveil;
  }
  return ResumeSommeil(
    endormi: endormi,
    profond: duree(TypeMesure.sommeilProfond),
    leger: duree(TypeMesure.sommeilLeger),
    paradoxal: duree(TypeMesure.sommeilParadoxal),
    eveil: eveil,
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
