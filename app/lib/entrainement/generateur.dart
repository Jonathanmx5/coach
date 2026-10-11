import '../profil/modele.dart';
import 'catalogue.dart';
import 'modele.dart';

/// Exercice réalisable avec ce matériel : lui-même, sinon son remplaçant.
/// Null seulement si le catalogue est mal formé.
Exercice? resoudre(Exercice e, Lieu lieu, Set<Materiel> materiel) {
  var courant = e;
  for (var i = 0; i < 5; i++) {
    final ok =
        lieu == Lieu.salle ||
        (!courant.salleSeulement && materiel.containsAll(courant.requis));
    if (ok) return courant;
    if (courant.alternative == null) return null;
    courant = exerciceParId(courant.alternative!);
  }
  return null;
}

const _ordreGroupes = [
  Groupe.jambes,
  Groupe.pousser,
  Groupe.tirer,
  Groupe.tronc,
  Groupe.cardio,
];

typedef _Candidat = ({Exercice exo, Exercice? remplace});

List<_Candidat> _candidats(Groupe g, Lieu lieu, Set<Materiel> materiel) {
  final directs = <_Candidat>[];
  final remplaces = <_Candidat>[];
  final vus = <String>{};
  for (final e in catalogueExercices.where((e) => e.groupe == g)) {
    final r = resoudre(e, lieu, materiel);
    if (r == null) continue;
    if (r.id == e.id && vus.add(r.id)) directs.add((exo: r, remplace: null));
  }
  for (final e in catalogueExercices.where((e) => e.groupe == g)) {
    final r = resoudre(e, lieu, materiel);
    if (r == null || r.id == e.id) continue;
    if (r.groupe == g && vus.add(r.id)) remplaces.add((exo: r, remplace: e));
  }
  return [...directs, ...remplaces];
}

/// Palier de progression : +1 répétition (ou +5 s) toutes les 3 séances, 4 fois
/// au plus ; au-delà, une série de plus (4 au maximum).
({int palier, int seriesEnPlus}) progression(int seancesFaites) {
  final p = seancesFaites ~/ 3;
  return (
    palier: p > 4 ? 4 : p,
    seriesEnPlus: p > 4 ? ((p - 4) ~/ 2 + 1).clamp(0, 2) : 0,
  );
}

/// Séance de renforcement (maison ou salle) pour le niveau, l'objectif et la
/// durée du profil. Les exercices tournent d'une séance à l'autre ; les
/// répétitions montent avec [seancesFaites].
Seance genererRenforcement({
  required Lieu lieu,
  required Set<Materiel> materiel,
  required Profil profil,
  required int seancesFaites,
}) {
  final prog = progression(seancesFaites);
  final seriesBase = profil.niveau == Niveau.regulier ? 3 : 2;
  final series = (seriesBase + prog.seriesEnPlus).clamp(2, 4);
  final repos = profil.objectif == Objectif.muscle ? 75 : 60;
  final repsBase = switch (profil.objectif) {
    Objectif.muscle => 8,
    Objectif.reprise => 10,
    _ => 12,
  };
  // ~1,2 min d'effort + repos par série, échauffement de 2 min.
  final parSerie = 0.7 + repos / 60;
  final nb = ((profil.dureeSeanceMin - 2) / (series * parSerie)).floor().clamp(
    3,
    6,
  );

  final choisis = <ExerciceSeance>[];
  final pris = <String>{};
  for (var i = 0; i < nb; i++) {
    final groupe = _ordreGroupes[i % _ordreGroupes.length];
    final tous = _candidats(groupe, lieu, materiel);
    final dispo = [
      for (final c in tous)
        if (!pris.contains(c.exo.id)) c,
    ];
    if (dispo.isEmpty) continue;
    final c = dispo[(seancesFaites + i ~/ _ordreGroupes.length) % dispo.length];
    pris.add(c.exo.id);
    choisis.add(
      ExerciceSeance(
        exercice: c.exo,
        remplace: c.remplace,
        series: series,
        reps: c.exo.duree ? 0 : repsBase + prog.palier,
        secondes: c.exo.duree ? 30 + 5 * prog.palier : 0,
        reposSecondes: repos,
      ),
    );
  }

  final etapes = <Etape>[
    const Etape(
      titre: 'Échauffement',
      consigne: 'Marche sur place, cercles d\'épaules et de hanches.',
      secondes: 120,
    ),
  ];
  for (var i = 0; i < choisis.length; i++) {
    final e = choisis[i];
    for (var s = 1; s <= e.series; s++) {
      etapes.add(
        Etape(
          titre: '${e.exercice.nom} · série $s/${e.series}',
          consigne: e.exercice.consigne,
          secondes: e.secondes,
          reps: e.reps,
          exerciceId: e.exercice.id,
        ),
      );
      final derniere = i == choisis.length - 1 && s == e.series;
      if (!derniere) {
        etapes.add(
          Etape(
            titre: 'Repos',
            consigne: 'Respire, bois une gorgée.',
            secondes: e.reposSecondes,
            repos: true,
          ),
        );
      }
    }
  }
  return Seance(
    titre: lieu == Lieu.salle ? 'Séance en salle' : 'Séance à la maison',
    lieu: lieu,
    etapes: etapes,
    exercices: choisis,
  );
}

// Programme de course à pied en 8 semaines : (course s, marche s, tours).
const _semainesCourse = <({int course, int marche, int tours})>[
  (course: 60, marche: 90, tours: 8),
  (course: 90, marche: 90, tours: 6),
  (course: 120, marche: 90, tours: 5),
  (course: 180, marche: 90, tours: 4),
  (course: 300, marche: 120, tours: 3),
  (course: 480, marche: 120, tours: 2),
  (course: 600, marche: 60, tours: 2),
  (course: 1200, marche: 0, tours: 1),
];

/// Semaine du programme de course : une semaine toutes les 3 séances ;
/// un niveau « régulier » démarre à la semaine 4.
int semaineCourse(int seancesFaites, Niveau niveau) {
  final depart = niveau == Niveau.regulier ? 3 : 0;
  return (depart + seancesFaites ~/ 3).clamp(0, _semainesCourse.length - 1);
}

Seance genererCourse({required Profil profil, required int seancesFaites}) {
  final semaine = semaineCourse(seancesFaites, profil.niveau);
  final w = _semainesCourse[semaine];
  final etapes = <Etape>[
    const Etape(
      titre: 'Échauffement',
      consigne: 'Marche d\'un bon pas pour réveiller les jambes.',
      secondes: 300,
    ),
  ];
  for (var t = 1; t <= w.tours; t++) {
    etapes.add(
      Etape(
        titre: 'Course ($t/${w.tours})',
        consigne: 'Trotte à un rythme où tu peux encore parler.',
        secondes: w.course,
      ),
    );
    if (w.marche > 0 && t < w.tours) {
      etapes.add(
        Etape(
          titre: 'Marche',
          consigne: 'Récupère en marchant.',
          secondes: w.marche,
          repos: true,
        ),
      );
    }
  }
  etapes.add(
    const Etape(
      titre: 'Retour au calme',
      consigne: 'Marche tranquille, respire.',
      secondes: 300,
      repos: true,
    ),
  );
  return Seance(
    titre: 'Course · semaine ${semaine + 1}',
    lieu: Lieu.course,
    etapes: etapes,
  );
}

/// Marche active : 20 minutes au départ, +5 minutes toutes les 3 séances,
/// jusqu'à 60.
Seance genererMarche({required int seancesFaites}) {
  final minutes = (20 + 5 * (seancesFaites ~/ 3)).clamp(20, 60);
  return Seance(
    titre: 'Marche active · $minutes min',
    lieu: Lieu.marche,
    etapes: [
      const Etape(
        titre: 'Mise en route',
        consigne: 'Marche à allure tranquille.',
        secondes: 180,
      ),
      Etape(
        titre: 'Marche rapide',
        consigne: 'Pas soutenu, bras actifs : tu respires plus fort mais tu peux parler.',
        secondes: (minutes - 6) * 60,
      ),
      const Etape(
        titre: 'Retour au calme',
        consigne: 'Ralentis peu à peu.',
        secondes: 180,
        repos: true,
      ),
    ],
  );
}

/// Séance proposée pour ce lieu.
Seance genererSeance({
  required Lieu lieu,
  required Set<Materiel> materiel,
  required Profil profil,
  required int seancesFaites,
}) => switch (lieu) {
  Lieu.course => genererCourse(profil: profil, seancesFaites: seancesFaites),
  Lieu.marche => genererMarche(seancesFaites: seancesFaites),
  _ => genererRenforcement(
    lieu: lieu,
    materiel: materiel,
    profil: profil,
    seancesFaites: seancesFaites,
  ),
};
