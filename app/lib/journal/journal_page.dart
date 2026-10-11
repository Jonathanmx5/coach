import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../compte/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../profil/besoins.dart';
import '../profil/profil_repository.dart';
import '../sante/suivi.dart';
import '../theme.dart';
import 'analyse_photo.dart';
import 'calculs.dart';
import 'catalogue.dart';
import 'formulaires.dart';
import 'journal_repository.dart';
import 'modele.dart';
import 'photo_repas_page.dart';
import '../recettes/planning_page.dart';
import '../recettes/planning_repository.dart';
import 'scanner_page.dart';

/// Lit un code-barres (caméra par défaut) ; null si l'utilisateur annule.
typedef LecteurCode = Future<String?> Function(BuildContext context);

Future<String?> lecteurCodeCamera(BuildContext context) =>
    Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScannerPage()));

/// Onglet Journal : repas, activités et bilan énergétique du jour.
class JournalPage extends StatefulWidget {
  const JournalPage({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.journal,
    required this.catalogue,
    required this.suivi,
    required this.horloge,
    required this.analyse,
    required this.planning,
    this.lecteurCode = lecteurCodeCamera,
    this.prise = prisePhotoCamera,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final JournalRepository journal;
  final CatalogueProduits catalogue;
  final Suivi suivi;
  final DateTime Function() horloge;
  final LecteurCode lecteurCode;
  final AnalysePhoto analyse;
  final PlanningRepository planning;
  final PrisePhoto prise;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late DateTime _jour = _debutDeJour(widget.horloge());
  late Stream<List<Repas>> _repas;
  late Stream<List<Activite>> _activites;

  String get _uid => widget.utilisateur.uid;

  static DateTime _debutDeJour(DateTime t) => DateTime(t.year, t.month, t.day);

  DateTime get _aujourdhui => _debutDeJour(widget.horloge());
  bool get _estAujourdhui => _jour == _aujourdhui;

  @override
  void initState() {
    super.initState();
    _ouvrirFlux();
  }

  void _ouvrirFlux() {
    final fin = DateTime(_jour.year, _jour.month, _jour.day + 1);
    _repas = widget.journal.repas(_uid, _jour, fin);
    _activites = widget.journal.activites(_uid, _jour, fin);
  }

  void _changerJour(int decalage) => setState(() {
    _jour = DateTime(_jour.year, _jour.month, _jour.day + decalage);
    _ouvrirFlux();
  });

  /// Aujourd'hui : l'heure exacte ; un autre jour : midi.
  DateTime get _dateAjout => _estAujourdhui
      ? widget.horloge()
      : DateTime(_jour.year, _jour.month, _jour.day, 12);

  void _message(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _ouvrirMenu() async {
    final t = AppLocalizations.of(context)!;
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: Text(t.menuRepas),
              onTap: () => Navigator.of(context).pop('repas'),
            ),
            if (widget.analyse.disponible)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(t.menuPhoto),
                onTap: () => Navigator.of(context).pop('photo'),
              ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(t.menuScanner),
              onTap: () => Navigator.of(context).pop('scan'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: Text(t.menuActivite),
              onTap: () => Navigator.of(context).pop('activite'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choix) {
      case 'repas':
        await _ajouterRepas();
      case 'photo':
        await _photo();
      case 'scan':
        await _scanner();
      case 'activite':
        await _ajouterActivite();
    }
  }

  Future<void> _ajouterRepas() async {
    final repas = await Navigator.of(context).push<Repas>(
      MaterialPageRoute(builder: (_) => AjoutRepasPage(date: _dateAjout)),
    );
    if (repas != null) unawaited(widget.journal.ajouterRepas(_uid, repas));
  }

  Future<void> _photo() async {
    final repas = await Navigator.of(context).push<Repas>(
      MaterialPageRoute(
        builder: (_) => PhotoRepasPage(
          date: _dateAjout,
          analyse: widget.analyse,
          prise: widget.prise,
        ),
      ),
    );
    if (repas != null) unawaited(widget.journal.ajouterRepas(_uid, repas));
  }

  Future<void> _scanner() async {
    final t = AppLocalizations.of(context)!;
    final code = await widget.lecteurCode(context);
    if (code == null || !mounted) return;
    try {
      final produit = await widget.catalogue.chercher(code);
      if (!mounted) return;
      if (produit == null) {
        _message(t.produitIntrouvable);
        return;
      }
      final repas = await showModalBottomSheet<Repas>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FeuilleProduit(produit: produit, date: _dateAjout),
      );
      if (repas != null) unawaited(widget.journal.ajouterRepas(_uid, repas));
    } on ErreurCatalogue {
      if (mounted) _message(t.erreurReseauProduit);
    }
  }

  Future<void> _ajouterActivite() async {
    final activite = await Navigator.of(context).push<Activite>(
      MaterialPageRoute(
        builder: (_) => AjoutActivitePage(
          date: _dateAjout,
          poidsKg: widget.enregistre.profil.poidsKg,
        ),
      ),
    );
    if (activite != null) {
      unawaited(widget.journal.ajouterActivite(_uid, activite));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.tabJournal),
        actions: [
          IconButton(
            tooltip: t.menuPlanning,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanningPage(
                  utilisateur: widget.utilisateur,
                  kcalCible: widget.enregistre.reperes.kcalCible,
                  planning: widget.planning,
                  journal: widget.journal,
                  horloge: widget.horloge,
                ),
              ),
            ),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-journal',
        tooltip: t.ajouter,
        onPressed: _ouvrirMenu,
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: widget.suivi,
        builder: (context, _) => StreamBuilder<List<Repas>>(
          stream: _repas,
          builder: (context, snapRepas) => StreamBuilder<List<Activite>>(
            stream: _activites,
            builder: (context, snapActivites) => _contenu(
              context,
              snapRepas.data ?? const [],
              snapActivites.data ?? const [],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenu(
    BuildContext context,
    List<Repas> repas,
    List<Activite> activites,
  ) {
    final t = AppLocalizations.of(context)!;
    final profil = widget.enregistre.profil;
    final jourSante = widget.suivi.jours
        .where((j) => j.jour == _jour)
        .firstOrNull;

    final kcalManuelles = activites.fold<double>(0, (s, a) => s + a.kcal);
    final kcalSeancesMontre = jourSante == null
        ? 0.0
        : (jourSante.kcalActives ??
              jourSante.seances.fold<double>(0, (s, x) => s + (x.kcal ?? 0)));
    final kcalExercice = kcalManuelles + kcalSeancesMontre;

    final reperes = calculerReperes(
      profil,
      maintenant: widget.horloge(),
      maintienMesure: widget.suivi.maintien,
    );
    final cibles = ciblesDuJour(reperes, kcalExercice: kcalExercice);
    final macros = totalMacros(repas);
    final depense = depenseDuJour(
      depenseBase: reperes.depenseBase,
      kcalMontre: jourSante?.kcalTotales,
      kcalActivites: kcalManuelles,
    );
    final ecart = solde(mange: macros.kcal, depense: depense);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      children: [
        _SelecteurJour(
          jour: _jour,
          estAujourdhui: _estAujourdhui,
          onChanger: _changerJour,
        ),
        const SizedBox(height: 12),
        _CarteBilan(
          mange: macros.kcal,
          depense: depense,
          ecart: ecart,
          cible: cibles.kcal,
          intensite: intensiteDuJour(kcalExercice),
        ),
        const SizedBox(height: 16),
        _CarteMacros(macros: macros, cibles: cibles),
        const SizedBox(height: 24),
        Text(t.repasTitre, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (repas.isEmpty)
          _Vide(t.aucunRepas)
        else
          for (final r in repas)
            _Ligne(
              icone: Icons.restaurant,
              titre: r.nom,
              sousTitre:
                  '${libelleMoment(t, r.moment)} · '
                  '${t.kcalValeur(r.macros.kcal.round().toString())}',
              onSupprimer: r.id == null
                  ? null
                  : () => unawaited(widget.journal.supprimerRepas(_uid, r.id!)),
            ),
        const SizedBox(height: 24),
        Text(t.activitesTitre, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (activites.isEmpty)
          _Vide(t.aucuneActivite)
        else
          for (final a in activites)
            _Ligne(
              icone: iconesActivite[a.type]!,
              titre: libelleActivite(t, a.type),
              sousTitre:
                  '${a.minutes} min · '
                  '${t.kcalValeur(a.kcal.round().toString())}',
              onSupprimer: a.id == null
                  ? null
                  : () => unawaited(
                      widget.journal.supprimerActivite(_uid, a.id!),
                    ),
            ),
      ],
    );
  }
}

class _SelecteurJour extends StatelessWidget {
  const _SelecteurJour({
    required this.jour,
    required this.estAujourdhui,
    required this.onChanger,
  });

  final DateTime jour;
  final bool estAujourdhui;
  final ValueChanged<int> onChanger;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Row(
      children: [
        IconButton(
          tooltip: t.jourPrecedent,
          onPressed: () => onChanger(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            estAujourdhui
                ? t.jourAujourdhui
                : DateFormat.MMMEd('fr').format(jour),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: t.jourSuivant,
          onPressed: estAujourdhui ? null : () => onChanger(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _CarteBilan extends StatelessWidget {
  const _CarteBilan({
    required this.mange,
    required this.depense,
    required this.ecart,
    required this.cible,
    required this.intensite,
  });

  final double mange;
  final double depense;
  final double ecart;
  final double cible;
  final IntensiteJour intensite;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final deficit = ecart <= 0;
    final libelleIntensite = switch (intensite) {
      IntensiteJour.repos => t.jourRepos,
      IntensiteJour.modere => t.jourModere,
      IntensiteJour.intense => t.jourIntense,
    };
    final signe = ecart < 0 ? '−' : (ecart > 0 ? '+' : '');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.bilanTitre, style: textes.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: intensite == IntensiteJour.intense
                        ? CouleursCoach.orangeClair
                        : CouleursCoach.vertClair,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(libelleIntensite, style: textes.labelMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: cible <= 0 ? 0 : (mange / cible).clamp(0, 1),
                minHeight: 10,
                color: CouleursCoach.orange,
                backgroundColor: CouleursCoach.orangeClair,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.cibleJour(cible.round()),
              style: textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Valeur(
                  cle: 'valeur-mange',
                  libelle: t.bilanMange,
                  valeur: t.kcalValeur(mange.round().toString()),
                ),
                _Valeur(
                  cle: 'valeur-depense',
                  libelle: t.bilanDepense,
                  valeur: t.kcalValeur(depense.round().toString()),
                ),
                _Valeur(
                  cle: 'valeur-solde',
                  libelle: deficit ? t.soldeDeficit : t.soldeExcedent,
                  valeur: t.kcalValeur('$signe${ecart.abs().round()}'),
                  couleur: deficit
                      ? CouleursCoach.vert
                      : CouleursCoach.orangeFonce,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Valeur extends StatelessWidget {
  const _Valeur({
    required this.cle,
    required this.libelle,
    required this.valeur,
    this.couleur,
  });

  final String cle;
  final String libelle;
  final String valeur;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux),
          ),
          Text(
            valeur,
            key: ValueKey(cle),
            style: textes.titleMedium?.copyWith(color: couleur),
          ),
        ],
      ),
    );
  }
}

class _CarteMacros extends StatelessWidget {
  const _CarteMacros({required this.macros, required this.cibles});

  final Macros macros;
  final CiblesJour cibles;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.macrosTitre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _BarreMacro(
              t.macroProteines,
              macros.proteines,
              cibles.proteines,
              CouleursCoach.vert,
            ),
            _BarreMacro(
              t.macroGlucides,
              macros.glucides,
              cibles.glucides,
              CouleursCoach.orange,
            ),
            _BarreMacro(
              t.macroLipides,
              macros.lipides,
              cibles.lipides,
              const Color(0xFF378ADD),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarreMacro extends StatelessWidget {
  const _BarreMacro(this.nom, this.mange, this.cible, this.couleur);

  final String nom;
  final double mange;
  final double cible;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(nom, style: textes.bodyMedium)),
              Text(
                t.macroProgression(mange.round(), cible.round()),
                style: textes.bodySmall?.copyWith(
                  color: CouleursCoach.texteDoux,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cible <= 0 ? 0 : (mange / cible).clamp(0, 1),
              minHeight: 8,
              color: couleur,
              backgroundColor: couleur.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      texte,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: CouleursCoach.texteDoux),
    ),
  );
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.onSupprimer,
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icone, color: CouleursCoach.vert),
        title: Text(titre),
        subtitle: Text(sousTitre),
        trailing: onSupprimer == null
            ? null
            : IconButton(
                tooltip: t.supprimer,
                onPressed: onSupprimer,
                icon: const Icon(Icons.delete_outline),
              ),
      ),
    );
  }
}
