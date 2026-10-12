import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../compte/auth_service.dart';
import '../compte/donnees_compte.dart';
import '../l10n/app_localizations.dart';
import '../profil/besoins.dart';
import '../profil/profil_repository.dart';
import '../sante/suivi.dart';
import 'analyse_photo.dart';
import 'calculs.dart';
import 'formulaires.dart';
import 'journal_repository.dart';
import 'modele.dart';
import 'photo_repas_page.dart';
import 'cartes_journal.dart';
import 'catalogue.dart';
import 'scanner_page.dart' show ScanCode, lireCodeBarres;
import 'photos_repas.dart';
import '../recettes/avis_repository.dart';
import '../recettes/idees_page.dart';
import 'detail_repas_page.dart';
import '../recettes/planning_page.dart';
import '../recettes/planning_repository.dart';

/// Demande d'ouvrir l'écran de photo du repas (bouton d'un widget) ; [source]
/// non nulle : on passe directement par l'appareil ou la bibliothèque.
class DemandePhoto {
  const DemandePhoto(this.numero, [this.source]);

  /// Change à chaque demande, pour que deux demandes identiques se distinguent.
  final int numero;
  final SourcePhoto? source;
}

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
    this.demandePhoto,
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

  /// Chaque changement ouvre l'écran de photo du repas (bouton d'un widget).
  final ValueListenable<DemandePhoto>? demandePhoto;
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
    widget.demandePhoto?.addListener(_surDemandePhoto);
  }

  void _surDemandePhoto() =>
      unawaited(_photo(source: widget.demandePhoto?.value.source));

  @override
  void dispose() {
    widget.demandePhoto?.removeListener(_surDemandePhoto);
    super.dispose();
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

  Future<void> _photo({SourcePhoto? source}) async {
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
          sourceInitiale: source,
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
        SelecteurJour(
          jour: _jour,
          estAujourdhui: _estAujourdhui,
          onChanger: _changerJour,
        ),
        const SizedBox(height: 12),
        CarteBilan(
          mange: macros.kcal,
          depense: depense,
          ecart: ecart,
          cible: cibles.kcal,
          intensite: intensiteDuJour(kcalExercice),
        ),
        const SizedBox(height: 16),
        CarteMacros(macros: macros, cibles: cibles),
        if (repas.isNotEmpty) ...[
          const SizedBox(height: 16),
          CarteRecap(repas: repas),
        ],
        const SizedBox(height: 24),
        Text(t.repasTitre, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (repas.isEmpty)
          Vide(t.aucunRepas)
        else
          for (final r in repas)
            Ligne(
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
