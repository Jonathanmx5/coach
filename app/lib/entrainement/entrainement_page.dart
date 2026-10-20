import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../compte/auth_service.dart';
import '../ecriture.dart';
import '../journal/calculs.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import '../journal/signalement.dart';
import '../l10n/app_localizations.dart';
import '../profil/modele.dart';
import '../profil/profil_repository.dart';
import '../recuperation/carte_recuperation.dart';
import '../recuperation/recuperation.dart';
import '../sante/suivi.dart';
import '../theme.dart';
import '../journal/formulaires.dart';
import 'animation_exercice.dart';
import 'carte_mobilite.dart';
import 'entrainement_repository.dart';
import 'generateur.dart';
import 'mobilite.dart';
import 'modele.dart';
import 'seance_guidee_page.dart';
import 'semaine.dart';
import 'voix.dart';
import '../route_verre.dart';

String _libelleLieu(AppLocalizations t, Lieu l) => switch (l) {
  Lieu.maison => t.lieuMaison,
  Lieu.salle => t.lieuSalle,
  Lieu.course => t.lieuCourse,
  Lieu.marche => t.lieuMarche,
};

String _libelleMateriel(AppLocalizations t, Materiel m) => switch (m) {
  Materiel.halteres => t.materielHalteres,
  Materiel.elastiques => t.materielElastiques,
  Materiel.barreTraction => t.materielBarre,
  Materiel.kettlebell => t.materielKettlebell,
  Materiel.banc => t.materielBanc,
  Materiel.cordeASauter => t.materielCorde,
};

/// Lieux proposés d'après les types d'entraînement du questionnaire (la
/// maison par défaut).
List<Lieu> lieuxDuProfil(Profil p) {
  final l = <Lieu>[
    if (p.typesEntrainement.contains(TypeEntrainement.maison)) Lieu.maison,
    if (p.typesEntrainement.contains(TypeEntrainement.salle)) Lieu.salle,
    if (p.typesEntrainement.contains(TypeEntrainement.course)) Lieu.course,
    if (p.typesEntrainement.contains(TypeEntrainement.marche)) Lieu.marche,
  ];
  return l.isEmpty ? [Lieu.maison] : l;
}

/// Lieux d'un même programme : renforcement maison + salle confondus ;
/// course et marche chacune à part. Ses séances faites règlent la
/// progression.
Set<Lieu> lieuxDuProgramme(Lieu lieu) => switch (lieu) {
  Lieu.maison || Lieu.salle => {Lieu.maison, Lieu.salle},
  _ => {lieu},
};

/// Noms des jours de séance prévus (« lundi, mercredi, vendredi »).
String nomsJoursPrevus(int joursParSemaine) {
  final format = DateFormat.EEEE('fr');
  // Le 1er janvier 2024 est un lundi.
  return [
    for (final j in joursPrevus(joursParSemaine).toList()..sort())
      format.format(DateTime(2024, 1, j)),
  ].join(', ');
}

TypeActivite _typeActivite(Lieu l) => switch (l) {
  Lieu.course => TypeActivite.course,
  Lieu.marche => TypeActivite.marche,
  _ => TypeActivite.musculation,
};

/// Onglet Entraînement : séance du jour selon le lieu et le matériel.
class EntrainementPage extends StatefulWidget {
  const EntrainementPage({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.entrainement,
    required this.journal,
    required this.voix,
    required this.suivi,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final EntrainementRepository entrainement;
  final JournalRepository journal;
  final Voix voix;
  final Suivi suivi;
  final DateTime Function() horloge;

  @override
  State<EntrainementPage> createState() => _EntrainementPageState();
}

class _EntrainementPageState extends State<EntrainementPage> {
  late Lieu _lieu = lieuxDuProfil(widget.enregistre.profil).first;
  late final Stream<Reglages> _reglages = widget.entrainement.reglages(
    widget.utilisateur.uid,
  );

  DateTime? _lundiSeances;
  Stream<List<SeanceFaite>>? _fluxSemaine;

  /// Dernières séances reçues depuis lundi.
  List<SeanceFaite> _semaine = const [];

  /// Séances faites depuis lundi (seule fenêtre utile à l'écran, la
  /// collection grandissant sans fin) ; le flux change chaque lundi.
  Stream<List<SeanceFaite>> _seancesDeLaSemaine(DateTime maintenant) {
    final lundi = lundiDe(maintenant);
    if (_lundiSeances != lundi) {
      _lundiSeances = lundi;
      _semaine = const [];
      _fluxSemaine = widget.entrainement.seances(_uid, depuis: lundi);
    }
    return _fluxSemaine!;
  }

  DateTime? _jourNombres;
  final _nombres = <Lieu, Future<int>>{};

  /// Séances déjà faites du programme de [lieu], comptées par le serveur.
  /// Une seule séance par jour : le compte n'est relu que le lendemain.
  Future<int> _nombreDuProgramme(Lieu lieu, DateTime maintenant) {
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    if (_jourNombres != jour) {
      _jourNombres = jour;
      _nombres.clear();
    }
    final programme = lieuxDuProgramme(lieu);
    return _nombres.putIfAbsent(
      programme.first,
      () => widget.entrainement.nombreSeances(_uid, programme).catchError((
        Object e,
        StackTrace s,
      ) {
        signalerErreur(e, s);
        return 0;
      }),
    );
  }

  bool _faiteAujourdhui() =>
      etatDuJour(
        maintenant: widget.horloge(),
        joursParSemaine: _profil.joursParSemaine,
        semaine: _semaine,
      ) ==
      EtatDuJour.faite;

  DateTime? _jourRessenti;
  Stream<int?>? _fluxRessenti;

  /// Le ressenti est celui du jour : le flux change à minuit.
  Stream<int?> _ressentiDuJour(DateTime maintenant) {
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    if (_jourRessenti != jour) {
      _jourRessenti = jour;
      _fluxRessenti = widget.entrainement.ressenti(_uid, jour);
    }
    return _fluxRessenti!;
  }

  void _lancerRoutine(Routine r) {
    Navigator.of(context).push(
      routeVerre<void>(
        (_) => SeanceGuideePage(seance: routine(r), voix: widget.voix),
      ),
    );
  }

  String get _uid => widget.utilisateur.uid;
  Profil get _profil => widget.enregistre.profil;

  /// Affiche [message] à la place du message en cours.
  void _dire(ScaffoldMessengerState messager, String message) => messager
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// Écriture sans attente ; un refus des règles est signalé par [message].
  void _ecrire(Future<void> ecriture, String message) {
    final messager = ScaffoldMessenger.of(context);
    ecrireSansAttendre(ecriture, surRefus: () => _dire(messager, message));
  }

  void _basculerMateriel(Reglages r, Materiel m, bool actif) {
    final nouveau = {...r.materiel};
    actif ? nouveau.add(m) : nouveau.remove(m);
    _ecrire(
      widget.entrainement.enregistrerReglages(
        _uid,
        Reglages(materiel: nouveau),
      ),
      AppLocalizations.of(context)!.modificationNonEnregistree,
    );
  }

  Future<void> _commencer(Seance seance) async {
    final t = AppLocalizations.of(context)!;
    final messager = ScaffoldMessenger.of(context);
    // Une seule séance « faite » par jour.
    if (_faiteAujourdhui()) return _dire(messager, t.seanceDejaFaite);
    final fini = await Navigator.of(context).push<bool>(
      routeVerre((_) => SeanceGuideePage(seance: seance, voix: widget.voix)),
    );
    if (fini != true) return;
    // Une séance a pu être enregistrée entre-temps (autre appareil).
    if (_faiteAujourdhui()) return _dire(messager, t.seanceDejaFaite);
    final maintenant = widget.horloge();
    final minutes = seance.minutes;
    ecrireSansAttendre(
      widget.entrainement.ajouterSeance(
        _uid,
        SeanceFaite(date: maintenant, lieu: seance.lieu, minutes: minutes),
      ),
      surRefus: () => _dire(messager, t.seanceNonEnregistree),
    );
    // La séance compte dans le bilan énergétique du journal.
    ecrireSansAttendre(
      widget.journal.ajouterActivite(
        _uid,
        Activite(
          date: maintenant,
          type: _typeActivite(seance.lieu),
          minutes: minutes,
          intensite: Intensite.moderee,
          kcal: kcalActivite(
            _typeActivite(seance.lieu),
            minutes,
            Intensite.moderee,
            _profil.poidsKg,
          ),
        ),
      ),
      surRefus: () => _dire(messager, t.activiteNonEnregistree),
    );
  }

  DateTime? _jourActivites;
  Stream<List<Activite>>? _activites;

  /// Activités saisies du jour courant ; le flux change à minuit.
  Stream<List<Activite>> _activitesDuJour(DateTime maintenant) {
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    if (_jourActivites != jour) {
      _jourActivites = jour;
      _activites = widget.journal.activites(
        _uid,
        jour,
        DateTime(jour.year, jour.month, jour.day + 1),
      );
    }
    return _activites!;
  }

  Future<void> _ajouterActivite() async {
    final activite = await Navigator.of(context).push<Activite>(
      routeVerre(
        (_) =>
            AjoutActivitePage(date: widget.horloge(), poidsKg: _profil.poidsKg),
      ),
    );
    if (activite != null && mounted) {
      _ecrire(
        widget.journal.ajouterActivite(_uid, activite),
        AppLocalizations.of(context)!.activiteNonEnregistree,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final lieux = lieuxDuProfil(_profil);
    return Scaffold(
      appBar: AppBar(title: Text(t.tabEntrainement)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-sport',
        onPressed: _ajouterActivite,
        icon: const Icon(Icons.add),
        label: Text(t.menuActivite),
      ),
      body: ListenableBuilder(
        listenable: widget.suivi,
        builder: (context, _) => StreamBuilder<int?>(
          stream: _ressentiDuJour(widget.horloge()),
          builder: (context, snapRessenti) {
            final nuit = widget.suivi.aujourdhui;
            final recuperation = calculerRecuperation(
              nuit: nuit,
              precedents: [
                for (final j in widget.suivi.jours)
                  if (nuit != null && j.jour.isBefore(nuit.jour)) j,
              ],
              ressenti: snapRessenti.data,
            );
            return StreamBuilder<Reglages>(
              stream: _reglages,
              builder: (context, snapReglages) =>
                  StreamBuilder<List<SeanceFaite>>(
                    stream: _seancesDeLaSemaine(widget.horloge()),
                    builder: (context, snapFaites) {
                      final reglages = snapReglages.data ?? const Reglages();
                      final faites = _semaine =
                          snapFaites.data ?? const <SeanceFaite>[];
                      final maintenant = widget.horloge();
                      final lundi = lundiDe(maintenant);
                      final cetteSemaine = faites
                          .where((s) => !s.date.isBefore(lundi))
                          .length;
                      final etat = etatDuJour(
                        maintenant: maintenant,
                        joursParSemaine: _profil.joursParSemaine,
                        semaine: faites,
                      );
                      final prochaine = DateFormat.EEEE('fr').format(
                        prochaineSeance(
                          maintenant: maintenant,
                          joursParSemaine: _profil.joursParSemaine,
                          faitesSemaine: cetteSemaine,
                        ),
                      );
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                        children: [
                          Text(
                            t.seancesSemaine(
                              cetteSemaine,
                              _profil.joursParSemaine,
                            ),
                            style: textes.titleMedium,
                          ),
                          Text(
                            t.joursPrevus(
                              nomsJoursPrevus(_profil.joursParSemaine),
                            ),
                            style: textes.bodySmall?.copyWith(
                              color: context.palette.texteDoux,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CarteRecuperation(
                            recuperation: recuperation,
                            ressenti: snapRessenti.data,
                            onRessenti: (v) => _ecrire(
                              widget.entrainement.noterRessenti(
                                _uid,
                                maintenant,
                                v,
                              ),
                              t.modificationNonEnregistree,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (lieux.length > 1)
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final l in lieux)
                                  ChoiceChip(
                                    label: Text(_libelleLieu(t, l)),
                                    selected: l == _lieu,
                                    onSelected: (_) =>
                                        setState(() => _lieu = l),
                                  ),
                              ],
                            ),
                          if (_lieu == Lieu.maison) ...[
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.monMateriel,
                                      style: textes.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t.materielAide,
                                      style: textes.bodySmall?.copyWith(
                                        color: context.palette.texteDoux,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        for (final m in Materiel.values)
                                          FilterChip(
                                            label: Text(_libelleMateriel(t, m)),
                                            selected: reglages.materiel
                                                .contains(m),
                                            onSelected: (v) =>
                                                _basculerMateriel(
                                                  reglages,
                                                  m,
                                                  v,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (etat == EtatDuJour.faite)
                            _CarteSeanceFaite(prochaine: prochaine)
                          else
                            FutureBuilder<int>(
                              future: _nombreDuProgramme(_lieu, maintenant),
                              builder: (context, snapNombre) {
                                if (!snapNombre.hasData) {
                                  return const Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  );
                                }
                                final seance = genererSeance(
                                  lieu: _lieu,
                                  materiel: reglages.materiel,
                                  profil: _profil,
                                  seancesFaites: snapNombre.data!,
                                );
                                return _CarteSeance(
                                  seance: seance,
                                  repos: switch (etat) {
                                    EtatDuJour.repos =>
                                      '${t.jourDeRepos} '
                                          '${t.prochaineSeance(prochaine)}',
                                    EtatDuJour.semaineFaite =>
                                      '${t.semaineFaite} '
                                          '${t.prochaineSeance(prochaine)}',
                                    _ => null,
                                  },
                                  onCommencer: () => _commencer(seance),
                                );
                              },
                            ),
                          const SizedBox(height: 16),
                          CarteMobilite(
                            conseillee: routineConseillee(
                              seanceAujourdhui: etat == EtatDuJour.faite,
                              recuperationFaible:
                                  recuperation?.niveau ==
                                  NiveauRecuperation.faible,
                            ),
                            onLancer: _lancerRoutine,
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<List<Activite>>(
                            stream: _activitesDuJour(maintenant),
                            builder: (context, snapActivites) =>
                                _CarteActivites(
                                  activites: snapActivites.data ?? const [],
                                  onSupprimer: (a) => _ecrire(
                                    widget.journal.supprimerActivite(
                                      _uid,
                                      a.id!,
                                    ),
                                    t.modificationNonEnregistree,
                                  ),
                                ),
                          ),
                        ],
                      );
                    },
                  ),
            );
          },
        ),
      ),
    );
  }
}

/// La séance du jour est faite : plus de seconde séance, place au repos.
class _CarteSeanceFaite extends StatelessWidget {
  const _CarteSeanceFaite({required this.prochaine});

  /// Jour de la prochaine séance (« lundi »).
  final String prochaine;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: CouleursCoach.vertMoyen,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.seanceDuJourFaite, style: textes.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${t.prochaineSeance(prochaine)} ${t.reposOuMobilite}',
                    style: textes.bodyMedium?.copyWith(
                      color: context.palette.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteSeance extends StatelessWidget {
  const _CarteSeance({
    required this.seance,
    required this.repos,
    required this.onCommencer,
  });

  final Seance seance;

  /// Non nul un jour de repos : le message, et la séance reste possible.
  final String? repos;
  final VoidCallback onCommencer;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (repos != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.bedtime_outlined,
                    color: context.palette.texteDoux,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(repos!, style: textes.bodyMedium)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(seance.titre, style: textes.titleLarge),
            Text(
              t.dureeEstimee(seance.minutes),
              style: textes.bodyMedium?.copyWith(
                color: context.palette.texteDoux,
              ),
            ),
            const SizedBox(height: 12),
            if (seance.exercices.isEmpty)
              for (final e in seance.etapes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${e.titre} — ${_duree(e.secondes)}',
                    style: textes.bodyMedium,
                  ),
                )
            else
              for (final e in seance.exercices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: exercicesAnimes.contains(e.exercice.id)
                      ? SizedBox(
                          width: 84,
                          child: AnimationExercice(
                            exerciceId: e.exercice.id,
                            arrondi: 10,
                          ),
                        )
                      : null,
                  title: Text(e.exercice.nom),
                  subtitle: Text(
                    [
                      e.exercice.duree
                          ? '${e.series} × ${e.secondes} s'
                          : '${e.series} × ${e.reps}',
                      if (e.remplace != null)
                        t.remplace(e.remplace!.nom.toLowerCase()),
                    ].join(' · '),
                  ),
                ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: repos == null
                  ? FilledButton.icon(
                      onPressed: onCommencer,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(t.commencerSeance),
                    )
                  : OutlinedButton.icon(
                      onPressed: onCommencer,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(t.commencerQuandMeme),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _duree(int s) => s >= 60 ? '${s ~/ 60} min' : '$s s';
}

/// Activités sportives saisies aujourd'hui, avec leurs calories estimées.
class _CarteActivites extends StatelessWidget {
  const _CarteActivites({required this.activites, required this.onSupprimer});

  final List<Activite> activites;
  final ValueChanged<Activite> onSupprimer;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.activitesDuJour, style: textes.titleMedium),
            const SizedBox(height: 4),
            if (activites.isEmpty)
              Text(
                t.aucuneActivite,
                style: textes.bodyMedium?.copyWith(
                  color: context.palette.texteDoux,
                ),
              )
            else
              for (final a in activites)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(iconesActivite[a.type]!),
                  title: Text(libelleActivite(t, a.type)),
                  subtitle: Text('${a.minutes} min · ${a.kcal.round()} kcal'),
                  trailing: a.id == null
                      ? null
                      : IconButton(
                          tooltip: t.supprimerActivite,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onSupprimer(a),
                        ),
                ),
          ],
        ),
      ),
    );
  }
}
