import 'dart:async';

import 'package:flutter/material.dart';

import 'accueil/accueil_page.dart';
import 'bienetre/bienetre_page.dart';
import 'bienetre/suivi_meteo.dart';
import 'compte/auth_service.dart';
import 'entrainement/entrainement_page.dart';
import 'recettes/idees_page.dart';
import 'journal/analyse_photo.dart' show SourcePhoto;
import 'journal/journal_page.dart';
import 'l10n/app_localizations.dart';
import 'poids/poids_page.dart';
import 'profil/profil_repository.dart';
import 'reglages/mises_a_jour.dart';
import 'reglages/reglages_page.dart';
import 'route_verre.dart';
import 'services.dart';
import 'theme.dart';
import 'verre.dart';
import 'sante/suivi.dart';

/// Barre d'onglets de l'appli (Accueil, Repas, Sport, Poids, Bien-être).
/// Un onglet n'est construit qu'à sa première visite, puis garde son état
/// quand on change d'onglet. La coque possède le suivi Health Connect,
/// partagé entre les onglets, et le relit à la reprise de l'appli et à minuit.
class Coque extends StatefulWidget {
  const Coque({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.services,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final Services services;
  final DateTime Function() horloge;

  @override
  State<Coque> createState() => _CoqueState();
}

class _CoqueState extends State<Coque> with WidgetsBindingObserver {
  int _onglet = 0;

  /// Pages des onglets, créées à la première visite et gardées ensuite :
  /// changer d'onglet ne reconstruit ni ne réabonne les autres pages.
  final List<Widget?> _pages = List.filled(5, null);

  /// Relecture du suivi au changement de jour, appli ouverte.
  Timer? _minuit;
  late final SuiviMeteo _meteoSuivi = SuiviMeteo(
    meteo: _s.meteo,
    bienetre: _s.bienetre,
    uid: widget.utilisateur.uid,
  );
  final ValueNotifier<InfoMiseAJour?> _maj = ValueNotifier(null);

  /// Un widget de l'écran d'accueil demande la photo d'un repas.
  final ValueNotifier<DemandePhoto> _demandePhoto = ValueNotifier(
    const DemandePhoto(0),
  );
  StreamSubscription<String>? _actionsWidget;
  late final Future<String> _version = _s.versionAppli.version();

  Future<void> _verifierMaj() async {
    final info = await _s.miseAJour.verifier(await _version);
    if (mounted) _maj.value = info;
  }

  void _ouvrirReglages() => Navigator.of(context).push<void>(
    routeVerre(
      (_) => ReglagesPage(
        utilisateur: widget.utilisateur,
        services: _s,
        version: _version,
        miseAJour: _maj,
        reverifier: _verifierMaj,
      ),
    ),
  );
  Services get _s => widget.services;
  late final Stream<bool> _enLigne = _s.reseau.enLigne;
  late final Suivi _suivi = Suivi(sante: _s.sante, horloge: widget.horloge);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages[0] = _page(0);
    _suivi.charger(montre: widget.enregistre.profil.montre);
    _programmerMinuit();
    unawaited(_verifierMaj());
    _actionsWidget = _s.widgetAccueil.actions.listen(_actionWidget);
    unawaited(
      _s.widgetAccueil.actionAuLancement().then((a) {
        if (a != null && mounted) _actionWidget(a);
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat != AppLifecycleState.resumed) return;
    // Données trop anciennes ou d'un autre jour : relues, pour que les
    // calories brûlées et « Ma journée » suivent la journée réelle.
    unawaited(_suivi.rechargerSiNecessaire());
    // Le minuteur a pu être retardé pendant la mise en veille.
    _programmerMinuit();
  }

  /// Programme la relecture du suivi juste après le prochain minuit.
  void _programmerMinuit() {
    _minuit?.cancel();
    final maintenant = widget.horloge();
    final demain = DateTime(
      maintenant.year,
      maintenant.month,
      maintenant.day + 1,
    );
    final attente = demain.difference(maintenant) + const Duration(seconds: 1);
    _minuit = Timer(attente, _surMinuit);
  }

  void _surMinuit() {
    if (!mounted) return;
    unawaited(_suivi.charger(montre: widget.enregistre.profil.montre));
    setState(() {});
    _programmerMinuit();
  }

  void _choisirOnglet(int i) => setState(() {
    _onglet = i;
    _pages[i] ??= _page(i);
  });

  void _actionWidget(String action) {
    if (action != 'photo' && action != 'photo-appareil') return;
    final nouvelle = _pages[1] == null;
    _choisirOnglet(1);
    void demander() => _demandePhoto.value = DemandePhoto(
      _demandePhoto.value.numero + 1,
      action == 'photo-appareil' ? SourcePhoto.appareil : null,
    );
    // Le Journal tout juste créé n'écoute la demande qu'une fois construit.
    if (nouvelle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) demander();
      });
    } else {
      demander();
    }
  }

  @override
  void didUpdateWidget(Coque ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.enregistre.profil.montre != widget.enregistre.profil.montre) {
      _suivi.charger(montre: widget.enregistre.profil.montre);
    }
    // Nouveau profil : les pages déjà visitées sont recréées avec lui.
    if (!identical(ancien.enregistre, widget.enregistre)) {
      for (var i = 0; i < _pages.length; i++) {
        if (_pages[i] != null) _pages[i] = _page(i);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuit?.cancel();
    _suivi.dispose();
    unawaited(_actionsWidget?.cancel());
    _demandePhoto.dispose();
    _maj.dispose();
    _meteoSuivi.dispose();
    super.dispose();
  }

  /// Page de l'onglet [i], construite avec le profil courant.
  Widget _page(int i) => switch (i) {
    0 => AccueilPage(
      utilisateur: widget.utilisateur,
      enregistre: widget.enregistre,
      auth: _s.auth,
      depot: _s.depot,
      sante: _s.sante,
      suivi: _suivi,
      horloge: widget.horloge,
      onOnglet: _choisirOnglet,
      journal: _s.journal,
      pesees: _s.pesees,
      bienetre: _s.bienetre,
      meteoSuivi: _meteoSuivi,
      miseAJour: _maj,
      onReglages: _ouvrirReglages,
      majWidget: _s.widgetAccueil,
      onIdees: () => Navigator.of(context).push<void>(
        routeVerre(
          (_) => IdeesPage(
            utilisateur: widget.utilisateur,
            objectif: widget.enregistre.profil.objectif,
            // La cible du jour, avec le maintien mesuré : celle du journal.
            kcalCible: _suivi.reperesDuJour(widget.enregistre.profil).kcalCible,
            avis: _s.avis,
            horloge: widget.horloge,
          ),
        ),
      ),
    ),
    1 => JournalPage(
      utilisateur: widget.utilisateur,
      enregistre: widget.enregistre,
      journal: _s.journal,
      analyse: _s.analyse,
      planning: _s.planning,
      avis: _s.avis,
      consentements: _s.consentements,
      photosRepas: _s.photosRepas,
      catalogue: _s.catalogue,
      preferencesAnalyse: _s.preferencesAnalyse,
      demandePhoto: _demandePhoto,
      suivi: _suivi,
      horloge: widget.horloge,
    ),
    2 => EntrainementPage(
      utilisateur: widget.utilisateur,
      enregistre: widget.enregistre,
      entrainement: _s.entrainement,
      journal: _s.journal,
      voix: _s.voix,
      suivi: _suivi,
      horloge: widget.horloge,
    ),
    3 => PoidsPage(
      utilisateur: widget.utilisateur,
      enregistre: widget.enregistre,
      depot: _s.depot,
      pesees: _s.pesees,
      journal: _s.journal,
      mensurations: _s.mensurations,
      photos: _s.photos,
      sante: _s.sante,
      suivi: _suivi,
      horloge: widget.horloge,
    ),
    _ => BienEtrePage(
      utilisateur: widget.utilisateur,
      enregistre: widget.enregistre,
      bienetre: _s.bienetre,
      journal: _s.journal,
      meteoSuivi: _meteoSuivi,
      rappels: _s.rappels,
      entrainement: _s.entrainement,
      consentements: _s.consentements,
      horloge: widget.horloge,
    ),
  };

  Widget _bandeauHorsLigne(AppLocalizations t) => StreamBuilder<bool>(
    stream: _enLigne,
    initialData: true,
    builder: (context, snap) => snap.data == false
        ? Material(
            color: CouleursCoach.orange,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  t.horsLigne,
                  // Texte foncé fixe : sur l'orange, le texte clair du thème
                  // sombre serait illisible.
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: CouleursCoach.texte),
                ),
              ),
            ),
          )
        : const SizedBox.shrink(),
  );

  Widget _corps() => Theme(
    // Les onglets laissent voir le fond de verre.
    data: Theme.of(context)
        .copyWith(scaffoldBackgroundColor: Colors.transparent),
    child: IndexedStack(
      index: _onglet,
      children: [for (final page in _pages) page ?? const SizedBox.shrink()],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final onglets = [
      (Icons.home_outlined, Icons.home, t.tabAccueil),
      (Icons.restaurant_outlined, Icons.restaurant, t.tabJournal),
      (Icons.fitness_center_outlined, Icons.fitness_center, t.tabSport),
      (Icons.monitor_weight_outlined, Icons.monitor_weight, t.tabPoids),
      (Icons.spa_outlined, Icons.spa, t.tabBienEtre),
    ];
    // Tablette ou téléphone à plat : barre latérale à gauche, contenu centré.
    if (largeEcran(context)) {
      return FondVerre(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                  child: VerreFlou(
                    rayon: 34,
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: _onglet,
                      onDestinationSelected: _choisirOnglet,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final (icone, plein, libelle) in onglets)
                          NavigationRailDestination(
                            icon: Icon(icone),
                            selectedIcon: Icon(plein),
                            label: Text(libelle),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _bandeauHorsLigne(t),
                    Expanded(child: ColonneCentree(child: _corps())),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return FondVerre(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _corps(),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bandeauHorsLigne(t),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: VerreFlou(
                rayon: 34,
                child: NavigationBar(
                  selectedIndex: _onglet,
                  onDestinationSelected: _choisirOnglet,
                  destinations: [
                    for (final (icone, plein, libelle) in onglets)
                      NavigationDestination(
                        icon: Icon(icone),
                        selectedIcon: Icon(plein),
                        label: libelle,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
