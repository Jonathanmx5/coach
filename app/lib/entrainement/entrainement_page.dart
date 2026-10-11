import 'dart:async';

import 'package:flutter/material.dart';

import '../compte/auth_service.dart';
import '../journal/calculs.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import '../l10n/app_localizations.dart';
import '../profil/modele.dart';
import '../profil/profil_repository.dart';
import '../recuperation/carte_recuperation.dart';
import '../recuperation/recuperation.dart';
import '../sante/suivi.dart';
import '../theme.dart';
import '../journal/formulaires.dart';
import 'carte_mobilite.dart';
import 'entrainement_repository.dart';
import 'generateur.dart';
import 'mobilite.dart';
import 'modele.dart';
import 'seance_guidee_page.dart';
import 'voix.dart';

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

/// Séances déjà faites du même programme (renforcement maison + salle
/// confondus ; course et marche chacune à part).
int seancesDuProgramme(List<SeanceFaite> faites, Lieu lieu) {
  bool renfo(Lieu l) => l == Lieu.maison || l == Lieu.salle;
  return faites
      .where((s) => renfo(lieu) ? renfo(s.lieu) : s.lieu == lieu)
      .length;
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
  late final Stream<List<SeanceFaite>> _faites = widget.entrainement.seances(
    widget.utilisateur.uid,
  );

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
      MaterialPageRoute<void>(
        builder: (_) => SeanceGuideePage(seance: routine(r), voix: widget.voix),
      ),
    );
  }

  String get _uid => widget.utilisateur.uid;
  Profil get _profil => widget.enregistre.profil;

  void _basculerMateriel(Reglages r, Materiel m, bool actif) {
    final nouveau = {...r.materiel};
    actif ? nouveau.add(m) : nouveau.remove(m);
    unawaited(
      widget.entrainement.enregistrerReglages(
        _uid,
        Reglages(materiel: nouveau),
      ),
    );
  }

  Future<void> _commencer(Seance seance) async {
    final fini = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SeanceGuideePage(seance: seance, voix: widget.voix),
      ),
    );
    if (fini != true) return;
    final maintenant = widget.horloge();
    final minutes = seance.minutes;
    unawaited(
      widget.entrainement.ajouterSeance(
        _uid,
        SeanceFaite(date: maintenant, lieu: seance.lieu, minutes: minutes),
      ),
    );
    // La séance compte dans le bilan énergétique du journal.
    unawaited(
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
      MaterialPageRoute(
        builder: (_) =>
            AjoutActivitePage(date: widget.horloge(), poidsKg: _profil.poidsKg),
      ),
    );
    if (activite != null) {
      unawaited(widget.journal.ajouterActivite(_uid, activite));
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
                    stream: _faites,
                    builder: (context, snapFaites) {
                      final reglages = snapReglages.data ?? const Reglages();
                      final faites = snapFaites.data ?? const <SeanceFaite>[];
                      final seance = genererSeance(
                        lieu: _lieu,
                        materiel: reglages.materiel,
                        profil: _profil,
                        seancesFaites: seancesDuProgramme(faites, _lieu),
                      );
                      final maintenant = widget.horloge();
                      final lundi = DateTime(
                        maintenant.year,
                        maintenant.month,
                        maintenant.day - (maintenant.weekday - 1),
                      );
                      final cetteSemaine = faites
                          .where((s) => !s.date.isBefore(lundi))
                          .length;
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
                          const SizedBox(height: 12),
                          CarteRecuperation(
                            recuperation: recuperation,
                            ressenti: snapRessenti.data,
                            onRessenti: (v) => unawaited(
                              widget.entrainement.noterRessenti(
                                _uid,
                                maintenant,
                                v,
                              ),
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
                                        color: CouleursCoach.texteDoux,
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
                          _CarteSeance(
                            seance: seance,
                            onCommencer: () => _commencer(seance),
                          ),
                          const SizedBox(height: 16),
                          CarteMobilite(
                            conseillee: routineConseillee(
                              seanceAujourdhui: faites.any(
                                (s) =>
                                    s.date.year == maintenant.year &&
                                    s.date.month == maintenant.month &&
                                    s.date.day == maintenant.day,
                              ),
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
                                  onSupprimer: (a) => unawaited(
                                    widget.journal.supprimerActivite(
                                      _uid,
                                      a.id!,
                                    ),
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

class _CarteSeance extends StatelessWidget {
  const _CarteSeance({required this.seance, required this.onCommencer});

  final Seance seance;
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
            Text(seance.titre, style: textes.titleLarge),
            Text(
              t.dureeEstimee(seance.minutes),
              style: textes.bodyMedium?.copyWith(
                color: CouleursCoach.texteDoux,
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
              child: FilledButton.icon(
                onPressed: onCommencer,
                icon: const Icon(Icons.play_arrow),
                label: Text(t.commencerSeance),
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
                  color: CouleursCoach.texteDoux,
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
