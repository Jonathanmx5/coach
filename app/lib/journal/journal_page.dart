import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../compte/auth_service.dart';
import '../compte/donnees_compte.dart';
import '../ecriture.dart';
import '../l10n/app_localizations.dart';
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
import 'signalement.dart';
import '../recettes/avis_repository.dart';
import '../recettes/idees_page.dart';
import 'detail_repas_page.dart';
import '../recettes/planning_page.dart';
import '../recettes/planning_repository.dart';
import '../route_verre.dart';

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

class _JournalPageState extends State<JournalPage> with WidgetsBindingObserver {
  late DateTime _jour = _debutDeJour(widget.horloge());
  late Stream<List<Repas>> _repas;
  late Stream<List<Activite>> _activites;

  /// Vrai tant que l'utilisateur n'a pas choisi un autre jour : l'écran passe
  /// alors au lendemain après minuit, même resté en mémoire.
  bool _suitAujourdhui = true;

  /// Un écran photo (ou la saisie qui le remplace) est déjà ouvert : une
  /// nouvelle demande du widget n'en empile pas un second.
  bool _photoEnCours = false;

  String get _uid => widget.utilisateur.uid;

  // Totaux du jour affiché, gardés pour montrer l'effet d'un repas photographié.
  Macros _macrosDuJour = Macros.zero;
  CiblesJour? _ciblesDuJour;

  /// Jour auquel correspondent [_macrosDuJour] et [_ciblesDuJour] (null tant
  /// que ses repas et activités n'ont pas été lus).
  DateTime? _jourDesTotaux;

  static DateTime _debutDeJour(DateTime t) => DateTime(t.year, t.month, t.day);

  DateTime get _aujourdhui => _debutDeJour(widget.horloge());
  bool get _estAujourdhui => _jour == _aujourdhui;

  @override
  void initState() {
    super.initState();
    _ouvrirFlux();
    WidgetsBinding.instance.addObserver(this);
    widget.demandePhoto?.addListener(_surDemandePhoto);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat != AppLifecycleState.resumed) return;
    // Données de la montre trop anciennes ou d'un autre jour : relues, pour
    // que le bilan et les cibles suivent la journée réelle.
    unawaited(widget.suivi.rechargerSiNecessaire());
    if (_doitPasserAujourdhui) setState(_revenirAujourdhui);
  }

  /// L'écran suivait le jour courant, et minuit est passé.
  bool get _doitPasserAujourdhui => _suitAujourdhui && !_estAujourdhui;

  void _revenirAujourdhui() {
    _jour = _aujourdhui;
    _suitAujourdhui = true;
    _ouvrirFlux();
  }

  /// Demande venue du widget : le repas est toujours celui de maintenant,
  /// quel que soit le jour affiché.
  void _surDemandePhoto() {
    if (_photoEnCours) return;
    if (!_estAujourdhui || !_suitAujourdhui) setState(_revenirAujourdhui);
    unawaited(
      _photo(source: widget.demandePhoto?.value.source, date: widget.horloge()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    _suitAujourdhui = _estAujourdhui;
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
      routeVerre(
        (_) => DetailRepasPage(
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

  void _supprimerPhoto(String id) => unawaited(
    widget.photosRepas
        .supprimer(id)
        .catchError((Object e, StackTrace s) => signalerErreur(e, s)),
  );

  /// Écrit le repas sans attendre l'accusé du serveur. S'il est refusé, le
  /// repas disparaît du journal : l'utilisateur est prévenu et la photo, qui
  /// ne sert plus à rien, est effacée.
  void _enregistrer(
    Repas repas,
    ScaffoldMessengerState messager,
    AppLocalizations t,
  ) {
    final photo = repas.photoId;
    ecrireSansAttendre(
      widget.journal.ajouterRepas(_uid, repas),
      surRefus: () {
        messager
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.repasNonEnregistre)));
        if (photo != null) _supprimerPhoto(photo);
      },
    );
  }

  /// Supprime le repas tout de suite, avec « Annuler » pendant quelques
  /// secondes ; la photo, qui n'existe que sur le téléphone, n'est effacée
  /// qu'une fois la suppression confirmée.
  void _supprimer(Repas r) {
    final t = AppLocalizations.of(context)!;
    ecrireSansAttendre(widget.journal.supprimerRepas(_uid, r.id!));
    final messager = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final barre = messager.showSnackBar(
      SnackBar(
        content: Text(t.repasSupprime),
        persist: false,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: t.annuler,
          // Même identifiant : le repas revient tel qu'il était.
          onPressed: () =>
              ecrireSansAttendre(widget.journal.modifierRepas(_uid, r)),
        ),
      ),
    );
    final photo = r.photoId;
    if (photo != null) {
      unawaited(
        barre.closed.then((raison) {
          if (raison != SnackBarClosedReason.action) _supprimerPhoto(photo);
        }),
      );
    }
  }

  Future<void> _ajouterRepas({DateTime? date}) async {
    final t = AppLocalizations.of(context)!;
    final messager = ScaffoldMessenger.of(context);
    final repas = await Navigator.of(
      context,
    ).push<Repas>(routeVerre((_) => AjoutRepasPage(date: date ?? _dateAjout)));
    if (repas != null) _enregistrer(repas, messager, t);
  }

  /// Ce qui est déjà mangé et les cibles de [jour], pour l'effet du repas
  /// photographié. Sans les totaux du jour affiché (demande du widget alors
  /// qu'un autre jour était affiché), ils sont relus ; s'ils restent
  /// introuvables, le verdict n'est pas montré plutôt que d'être faux.
  Future<(Macros, CiblesJour?)> _totauxDe(DateTime jour) async {
    if (_jourDesTotaux == jour) return (_macrosDuJour, _ciblesDuJour);
    final fin = DateTime(jour.year, jour.month, jour.day + 1);
    const delai = Duration(seconds: 3);
    try {
      final repas = await widget.journal
          .repas(_uid, jour, fin)
          .first
          .timeout(delai);
      final activites = await widget.journal
          .activites(_uid, jour, fin)
          .first
          .timeout(delai);
      final bilan = _bilan(jour, repas, activites);
      return (bilan.macros, bilan.cibles);
    } on TimeoutException {
      return (Macros.zero, null);
    } catch (e, s) {
      signalerErreur(e, s);
      return (Macros.zero, null);
    }
  }

  /// Écran photo du repas ; [date] : celle du repas (par défaut, selon le
  /// jour affiché).
  Future<void> _photo({SourcePhoto? source, DateTime? date}) async {
    if (_photoEnCours) return;
    _photoEnCours = true;
    try {
      await _ouvrirPhoto(source: source, date: date ?? _dateAjout);
    } finally {
      _photoEnCours = false;
    }
  }

  Future<void> _ouvrirPhoto({
    SourcePhoto? source,
    required DateTime date,
  }) async {
    final t = AppLocalizations.of(context)!;
    final messager = ScaffoldMessenger.of(context);
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
      await _ajouterRepas(date: date);
      return;
    }
    final (dejaMange, cibles) = await _totauxDe(_debutDeJour(date));
    if (!mounted) return;
    final resultat = await Navigator.of(context).push<Object>(
      routeVerre(
        (_) => PhotoRepasPage(
          date: date,
          analyse: widget.analyse,
          prise: widget.prise,
          photos: widget.photosRepas,
          catalogue: widget.catalogue,
          scan: widget.scan,
          sourceInitiale: source,
          dejaMange: dejaMange,
          cibles: cibles,
          objectif: widget.enregistre.profil.objectif,
        ),
      ),
    );
    if (resultat is Repas) {
      _enregistrer(resultat, messager, t);
    } else if (resultat is SaisieManuelle && mounted) {
      await _ajouterRepas(date: date);
    }
  }

  /// Le même bilan que les anneaux de l'Accueil (calculs.dart).
  BilanJour _bilan(DateTime jour, List<Repas> repas, List<Activite> activites) {
    final profil = widget.enregistre.profil;
    return bilanDuJour(
      profil: profil,
      jours: widget.suivi.jours,
      maintienMesure: widget.suivi.maintienPour(profil),
      repas: repas,
      activites: activites,
      jour: jour,
      maintenant: widget.horloge(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    // Minuit passé pendant que l'écran était affiché : il suit le jour réel.
    if (_doitPasserAujourdhui) _revenirAujourdhui();
    // La cible des idées et du planning est celle du journal et de l'accueil.
    int kcalCible() =>
        widget.suivi.reperesDuJour(widget.enregistre.profil).kcalCible;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.tabJournal),
        actions: [
          IconButton(
            tooltip: t.menuIdees,
            onPressed: () => Navigator.of(context).push(
              routeVerre<void>(
                (_) => IdeesPage(
                  utilisateur: widget.utilisateur,
                  objectif: widget.enregistre.profil.objectif,
                  kcalCible: kcalCible(),
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
              routeVerre<void>(
                (_) => PlanningPage(
                  utilisateur: widget.utilisateur,
                  kcalCible: kcalCible(),
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
          // Clé du jour : en changeant de jour, rien de l'ancien jour ne
          // reste affiché pendant la lecture du nouveau.
          key: ValueKey(_jour),
          stream: _repas,
          builder: (context, snapRepas) => StreamBuilder<List<Activite>>(
            stream: _activites,
            builder: (context, snapActivites) => _contenu(
              context,
              snapRepas.data ?? const [],
              snapActivites.data ?? const [],
              lus: snapRepas.hasData && snapActivites.hasData,
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenu(
    BuildContext context,
    List<Repas> repas,
    List<Activite> activites, {
    required bool lus,
  }) {
    final t = AppLocalizations.of(context)!;
    final bilan = _bilan(_jour, repas, activites);
    final cibles = bilan.cibles;
    final macros = bilan.macros;
    _macrosDuJour = macros;
    _ciblesDuJour = cibles;
    _jourDesTotaux = lus ? _jour : null;

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
          depense: bilan.depenseJour,
          ecart: bilan.ecart,
          cible: cibles.kcal,
          intensite: bilan.intensite,
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
              onSupprimer: r.id == null ? null : () => _supprimer(r),
            ),
      ],
    );
  }
}
