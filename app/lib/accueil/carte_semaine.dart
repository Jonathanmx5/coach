import 'dart:async';

import 'package:flutter/material.dart';

import '../format.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import '../l10n/app_localizations.dart';
import '../poids/pesees.dart';
import '../poids/pesees_repository.dart';
import '../profil/modele.dart';
import '../sante/suivi.dart';
import '../theme.dart';
import 'bilan_semaine.dart';

/// Carte « Ma semaine » de l'accueil : les 7 derniers jours du journal
/// (calories, jours dans la cible, protéines), les séances faites et la
/// tendance du poids. Elle lit les repas, activités et pesées déjà stockés,
/// sur deux semaines au plus ; un appui ouvre le Journal.
class CarteSemaine extends StatefulWidget {
  const CarteSemaine({
    super.key,
    required this.uid,
    required this.profil,
    required this.suivi,
    required this.journal,
    required this.pesees,
    required this.horloge,
    required this.onJournal,
  });

  final String uid;
  final Profil profil;

  /// Résumés et pesées de la montre (vides sans montre).
  final Suivi suivi;
  final JournalRepository journal;
  final PeseesRepository pesees;
  final DateTime Function() horloge;
  final VoidCallback onJournal;

  @override
  State<CarteSemaine> createState() => _CarteSemaineState();
}

class _CarteSemaineState extends State<CarteSemaine> {
  /// Le jour dont la semaine est lue ; la carte est recréée le lendemain
  /// (clé du jour sur l'accueil).
  late DateTime _jour;

  /// Null tant que le flux n'a rien donné.
  List<Repas>? _repas;
  List<Activite>? _activites;
  List<Pesee>? _pesees;
  final _abonnements = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    final m = widget.horloge();
    _jour = DateTime(m.year, m.month, m.day);
    _ecouter();
  }

  @override
  void didUpdateWidget(CarteSemaine ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.uid != widget.uid ||
        ancien.journal != widget.journal ||
        ancien.pesees != widget.pesees) {
      _ecouter();
    }
  }

  @override
  void dispose() {
    for (final a in _abonnements) {
      unawaited(a.cancel());
    }
    super.dispose();
  }

  void _ecouter() {
    for (final a in _abonnements) {
      unawaited(a.cancel());
    }
    _abonnements.clear();
    _repas = null;
    _activites = null;
    _pesees = null;
    final debut = DateTime(_jour.year, _jour.month, _jour.day - joursSemaine);
    final demain = DateTime(_jour.year, _jour.month, _jour.day + 1);
    // Deux semaines de pesées : la tendance d'une semaine plus tôt.
    final debutPesees = DateTime(
      _jour.year,
      _jour.month,
      _jour.day - (2 * joursSemaine - 1),
    );
    void recu(VoidCallback garder) {
      if (mounted) setState(garder);
    }

    // Un flux en erreur (accès refusé, réseau) compte comme vide : la carte
    // montre ce qu'elle a plutôt que de rester en chargement.
    _abonnements.addAll([
      widget.journal
          .repas(widget.uid, debut, _jour)
          .listen(
            (v) => recu(() => _repas = v),
            onError: (Object _) => recu(() => _repas ??= const []),
          ),
      widget.journal
          .activites(widget.uid, debut, demain)
          .listen(
            (v) => recu(() => _activites = v),
            onError: (Object _) => recu(() => _activites ??= const []),
          ),
      widget.pesees
          .observer(widget.uid, depuis: debutPesees)
          .listen(
            (v) => recu(() => _pesees = v),
            onError: (Object _) => recu(() => _pesees ??= const []),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final p = context.palette;
    final repas = _repas, activites = _activites, pesees = _pesees;
    final charge = repas != null && activites != null && pesees != null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(rayonCarte),
        onTap: widget.onJournal,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.maSemaine, style: textes.titleLarge),
                        Text(
                          t.maSemaineSous,
                          style: textes.bodyMedium?.copyWith(
                            color: p.texteDoux,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.texteDoux),
                ],
              ),
              const SizedBox(height: 12),
              if (!charge)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _Chiffres(
                  bilan: bilanSemaine(
                    profil: widget.profil,
                    jours: widget.suivi.jours,
                    maintienMesure: widget.suivi.maintienPour(widget.profil),
                    repas: repas,
                    activites: activites,
                    pesees: fusionnerPesees(pesees, widget.suivi.pesees),
                    maintenant: widget.horloge(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chiffres extends StatelessWidget {
  const _Chiffres({required this.bilan});

  final BilanSemaine bilan;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final p = context.palette;
    final b = bilan;
    final kcal = b.kcalMoyenne, proteines = b.proteinesMoyenne;
    final evolution = b.evolutionPoids, tendance = b.poidsTendance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Stat(
              icone: Icons.restaurant_outlined,
              couleur: p.texteOrange,
              valeur: kcal == null ? '—' : '${kcal.round()}',
              objectif: '${b.cibleMoyenne.round()} kcal',
              libelle: t.semaineKcal,
            ),
            _Stat(
              icone: Icons.track_changes_outlined,
              couleur: p.texteOrange,
              valeur: '${b.joursDansCible}',
              objectif: '${b.joursNotes}',
              libelle: t.semaineDansCible,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stat(
              icone: Icons.egg_alt_outlined,
              couleur: p.texteVert,
              valeur: proteines == null ? '—' : '${proteines.round()}',
              objectif: '${b.cibleProteines.round()} g',
              libelle: t.semaineProteines,
            ),
            _Stat(
              icone: Icons.fitness_center,
              couleur: p.texteVert,
              valeur: '${b.seances}',
              objectif: '${b.seancesPrevues}',
              libelle: t.semaineSeances,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stat(
              icone: Icons.monitor_weight_outlined,
              couleur: p.texteBleu,
              valeur: evolution != null
                  ? ecartPoidsTexte(evolution)
                  : tendance != null
                  ? '${formatDecimal(tendance)} kg'
                  : '—',
              libelle: evolution != null
                  ? t.semaineEvolutionPoids
                  : tendance != null
                  ? t.semainePoidsMoyen
                  : t.semaineSansPesee,
            ),
          ],
        ),
        if (b.joursNotes == 0) ...[
          const SizedBox(height: 12),
          Text(
            t.semaineAucunRepas,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: p.texteDoux),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icone,
    required this.couleur,
    required this.valeur,
    required this.libelle,
    this.objectif,
  });

  final IconData icone;

  /// Couleur du chiffre, lisible sur la carte.
  final Color couleur;
  final String valeur;

  /// Affiché après le chiffre : « / 2100 kcal ».
  final String? objectif;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final p = context.palette;
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.vertClair,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: CouleursCoach.vert, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: valeur,
                        style: textes.titleMedium?.copyWith(
                          color: couleur,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (objectif != null)
                        TextSpan(
                          text: ' / $objectif',
                          style: textes.bodySmall?.copyWith(color: p.texteDoux),
                        ),
                    ],
                  ),
                ),
                Text(
                  libelle,
                  style: textes.bodySmall?.copyWith(color: p.texteDoux),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
