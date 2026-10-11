import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../compte/auth_service.dart';
import '../compte/donnees_compte.dart';
import '../l10n/app_localizations.dart';
import '../profil/besoins.dart';
import '../profil/profil_repository.dart';
import '../sante/suivi.dart';
import '../theme.dart';
import 'analyse_photo.dart';
import 'calculs.dart';
import 'formulaires.dart';
import 'journal_repository.dart';
import 'modele.dart';
import 'photo_repas_page.dart';
import 'catalogue.dart';
import 'scanner_page.dart' show ScanCode, lireCodeBarres;
import 'photos_repas.dart';
import '../recettes/avis_repository.dart';
import '../recettes/idees_page.dart';
import 'detail_repas_page.dart';
import '../recettes/planning_page.dart';
import '../recettes/planning_repository.dart';

/// Onglet Journal : repas, activités et bilan énergétique du jour.
class JournalPage extends StatefulWidget {
  const JournalPage({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.journal,
    required this.suivi,
    required this.horloge,
    required this.analyse,
    required this.planning,
    required this.avis,
    required this.consentements,
    required this.photosRepas,
    required this.catalogue,
    this.scan = lireCodeBarres,
    this.prise = prisePhotoCamera,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final JournalRepository journal;
  final Suivi suivi;
  final DateTime Function() horloge;
  final AnalysePhoto analyse;
  final PlanningRepository planning;
  final AvisRepository avis;
  final ConsentementsRepository consentements;
  final PhotosRepas photosRepas;
  final CatalogueProduits catalogue;
  final ScanCode scan;
  final PrisePhoto prise;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late DateTime _jour = _debutDeJour(widget.horloge());
  late Stream<List<Repas>> _repas;
  late Stream<List<Activite>> _activites;

  String get _uid => widget.utilisateur.uid;

  // Totaux du jour affiché, gardés pour montrer l'effet d'un repas photographié.
  Macros _macrosDuJour = Macros.zero;
  CiblesJour? _ciblesDuJour;

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

  void _ouvrirDetail(Repas r, CiblesJour cibles, Macros totalJour) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DetailRepasPage(
          repas: r,
          dejaMange: Macros(
            kcal: totalJour.kcal - r.macros.kcal,
            proteines: totalJour.proteines - r.macros.proteines,
            glucides: totalJour.glucides - r.macros.glucides,
            lipides: totalJour.lipides - r.macros.lipides,
          ),
          cibles: cibles,
          objectif: widget.enregistre.profil.objectif,
          photos: widget.photosRepas,
          onModifier: (nouveau) => widget.journal.modifierRepas(_uid, nouveau),
        ),
      ),
    );
  }

  Future<void> _ajouterRepas() async {
    final repas = await Navigator.of(context).push<Repas>(
      MaterialPageRoute(builder: (_) => AjoutRepasPage(date: _dateAjout)),
    );
    if (repas != null) unawaited(widget.journal.ajouterRepas(_uid, repas));
  }

  Future<void> _photo() async {
    final t = AppLocalizations.of(context)!;
    // Sans analyse possible (pas de relais) ou sans l'accord de l'utilisateur
    // pour envoyer la photo, il reste la saisie à la main.
    final accord =
        widget.analyse.disponible &&
        await assurerConsentement(
          context,
          widget.consentements,
          _uid,
          Consentement.photo,
        );
    if (!mounted) return;
    if (!accord) {
      _message(t.sansAnalyse);
      await _ajouterRepas();
      return;
    }
    final resultat = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => PhotoRepasPage(
          date: _dateAjout,
          analyse: widget.analyse,
          prise: widget.prise,
          photos: widget.photosRepas,
          catalogue: widget.catalogue,
          scan: widget.scan,
          dejaMange: _macrosDuJour,
          cibles: _ciblesDuJour,
          objectif: widget.enregistre.profil.objectif,
        ),
      ),
    );
    if (resultat is Repas) {
      unawaited(widget.journal.ajouterRepas(_uid, resultat));
    } else if (resultat is SaisieManuelle && mounted) {
      await _ajouterRepas();
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
            tooltip: t.menuIdees,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IdeesPage(
                  utilisateur: widget.utilisateur,
                  objectif: widget.enregistre.profil.objectif,
                  kcalCible: widget.enregistre.reperes.kcalCible,
                  avis: widget.avis,
                  horloge: widget.horloge,
                ),
              ),
            ),
            icon: const Icon(Icons.swipe_outlined),
          ),
          IconButton(
            tooltip: t.menuPlanning,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanningPage(
                  utilisateur: widget.utilisateur,
                  kcalCible: widget.enregistre.reperes.kcalCible,
                  planning: widget.planning,
                  avis: widget.avis,
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
        tooltip: t.menuPhoto,
        onPressed: _photo,
        child: const Icon(Icons.photo_camera_outlined),
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

    // Une activité que la montre a déjà mesurée n'est pas comptée deux fois.
    final kcalManuelles = kcalActivitesNonComptees(
      activites,
      jourSante?.seances ?? const [],
    );
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
    _macrosDuJour = macros;
    _ciblesDuJour = cibles;
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
        if (repas.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CarteRecap(repas: repas),
        ],
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
              onTap: () => _ouvrirDetail(r, cibles, macros),
              onSupprimer: r.id == null
                  ? null
                  : () {
                      unawaited(widget.journal.supprimerRepas(_uid, r.id!));
                      if (r.photoId != null) {
                        unawaited(widget.photosRepas.supprimer(r.photoId!));
                      }
                    },
            ),
      ],
    );
  }
}

/// Les repas de la journée additionnés : un total par moment (petit-déjeuner,
/// midi, soir, collation) puis le total de la journée.
class _CarteRecap extends StatelessWidget {
  const _CarteRecap({required this.repas});

  final List<Repas> repas;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final parMoment = {
      for (final m in Moment.values)
        m: totalMacros(repas.where((r) => r.moment == m)),
    };
    final total = totalMacros(repas);
    String valeur(Macros m) =>
        t.recapValeur(m.kcal.round(), m.proteines.round());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.recapTitre, style: textes.titleMedium),
            const SizedBox(height: 8),
            for (final m in Moment.values)
              if (repas.any((r) => r.moment == m))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(libelleMoment(t, m)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          valeur(parMoment[m]!),
                          textAlign: TextAlign.end,
                          style: textes.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            const Divider(),
            Row(
              children: [
                Text(t.recapTotal, style: textes.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    valeur(total),
                    key: const Key('recap-total'),
                    textAlign: TextAlign.end,
                    style: textes.titleSmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
    this.onTap,
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback? onSupprimer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icone, color: CouleursCoach.vert),
        title: Text(titre),
        subtitle: Text(sousTitre),
        onTap: onTap,
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
