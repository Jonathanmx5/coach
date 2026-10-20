import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../compte/auth_service.dart';
import '../ecriture.dart';
import '../journal/formulaires.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'avis_repository.dart';
import 'catalogue.dart';
import 'courses_page.dart';
import 'modele.dart';
import 'planning.dart';
import 'planning_repository.dart';
import 'recette_page.dart';

/// Les repas de la semaine, calculés d'après la cible calorique du profil.
class PlanningPage extends StatefulWidget {
  const PlanningPage({
    super.key,
    required this.utilisateur,
    required this.kcalCible,
    required this.planning,
    required this.avis,
    required this.journal,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final int kcalCible;
  final PlanningRepository planning;
  final AvisRepository avis;
  final JournalRepository journal;
  final DateTime Function() horloge;

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  String get _uid => widget.utilisateur.uid;
  late final DateTime _lundi = lundiDe(widget.horloge());
  late final Stream<Planning?> _flux = widget.planning.planning(_uid, _lundi);
  bool _creation = false;

  /// Écrit le planning sans attendre l'accusé du serveur ; un refus des
  /// règles (la semaine reviendrait en arrière sans prévenir) est signalé.
  void _enregistrer(Planning p) {
    final messager = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context)!;
    ecrireSansAttendre(
      widget.planning.enregistrer(_uid, p),
      surRefus: () => messager
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.planningNonEnregistre))),
    );
  }

  /// Génère la semaine en tenant compte des recettes aimées et refusées.
  Future<void> _generer({bool vegetarien = false}) async {
    final avis = await widget.avis.avis(_uid).first;
    if (!mounted) return;
    _enregistrer(
      genererPlanning(
        lundi: _lundi,
        kcalCible: widget.kcalCible.toDouble(),
        vegetarien: vegetarien,
        avis: avis,
      ),
    );
  }

  void _creerSiAbsent(Planning? existant) {
    if (_creation) return;
    _creation = true;
    unawaited(_generer(vegetarien: existant?.vegetarien ?? false));
  }

  void _basculerVegetarien(Planning p, bool v) =>
      unawaited(_generer(vegetarien: v));

  DateTime _dateDuRepas(int jour, Moment m) {
    final heure = switch (m) {
      Moment.petitDejeuner => 8,
      Moment.dejeuner => 12,
      Moment.collation => 16,
      Moment.diner => 19,
    };
    return DateTime(_lundi.year, _lundi.month, _lundi.day + jour, heure);
  }

  Future<void> _ouvrir(Planning p, int jour, Moment moment) async {
    final repas = p.jours[jour]![moment]!;
    final action = await Navigator.of(context).push<ActionRecette>(
      MaterialPageRoute(
        builder: (_) => RecettePage(
          recette: recetteParId(repas.recetteId),
          portions: repas.portions,
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ActionRecette.ajouterAuJournal:
        final r = recetteParId(repas.recetteId);
        final t = AppLocalizations.of(context)!;
        final messager = ScaffoldMessenger.of(context);
        ecrireSansAttendre(
          widget.journal.ajouterRepas(
            _uid,
            Repas(
              date: _dateDuRepas(jour, moment),
              moment: moment,
              nom: r.nom,
              macros: r.macros.multiplie(repas.portions),
              source: SourceRepas.manuel,
            ),
          ),
          surRefus: () => messager
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(t.repasNonEnregistre))),
        );
        messager
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.repasAjoute)));
      case ActionRecette.changer:
        final choix = await Navigator.of(context).push<Recette>(
          MaterialPageRoute(
            builder: (_) =>
                ChoixRecettePage(moment: moment, vegetarien: p.vegetarien),
          ),
        );
        if (choix != null) {
          _enregistrer(
            p.avecRepas(
              jour,
              moment,
              RepasPlanifie(
                choix.id,
                portionsPour(choix, widget.kcalCible * partsDuJour[moment]!),
              ),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return StreamBuilder<Planning?>(
      stream: _flux,
      builder: (context, snap) {
        final p = snap.data;
        if (snap.connectionState != ConnectionState.waiting &&
            (p == null || !estComplet(p))) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _creerSiAbsent(p),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(t.planningTitre),
            actions: [
              IconButton(
                tooltip: t.coursesTitre,
                onPressed: p == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CoursesPage(
                            uid: _uid,
                            lundi: _lundi,
                            planning: widget.planning,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.shopping_cart_outlined),
              ),
            ],
          ),
          body: p == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Text(
                      t.planningAide(widget.kcalCible),
                      style: textes.bodySmall?.copyWith(
                        color: context.palette.texteDoux,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.sansViande),
                      value: p.vegetarien,
                      onChanged: (v) => _basculerVegetarien(p, v),
                    ),
                    for (var j = 0; j < 7; j++) _carteJour(context, p, j),
                  ],
                ),
        );
      },
    );
  }

  Widget _carteJour(BuildContext context, Planning p, int j) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final date = DateTime(_lundi.year, _lundi.month, _lundi.day + j);
    final repas = p.jours[j] ?? const <Moment, RepasPlanifie>{};
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${toBeginningOfSentenceCase(DateFormat.MMMEd('fr').format(date))}'
              ' · ${kcalTexte(macrosDuJour(repas).kcal.round())}',
              style: textes.titleMedium,
            ),
            for (final m in Moment.values)
              if (repas[m] != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(recetteParId(repas[m]!.recetteId).nom),
                  subtitle: Text(
                    '${libelleMoment(t, m)} · '
                    '${t.nbPortions(_portionsTexte(repas[m]!.portions))} · '
                    '${kcalTexte(macrosDuRepas(repas[m]!).kcal.round())}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _ouvrir(p, j, m),
                ),
          ],
        ),
      ),
    );
  }
}

String _portionsTexte(double p) =>
    p == p.roundToDouble() ? '${p.round()}' : p.toString().replaceAll('.', ',');
