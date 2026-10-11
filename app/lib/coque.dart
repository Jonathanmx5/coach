import 'dart:async';

import 'package:flutter/material.dart';

import 'accueil/accueil_page.dart';
import 'bienetre/bienetre_page.dart';
import 'bienetre/suivi_meteo.dart';
import 'compte/auth_service.dart';
import 'entrainement/entrainement_page.dart';
import 'recettes/idees_page.dart';
import 'journal/journal_page.dart';
import 'l10n/app_localizations.dart';
import 'poids/poids_page.dart';
import 'profil/profil_repository.dart';
import 'reglages/mises_a_jour.dart';
import 'reglages/reglages_page.dart';
import 'services.dart';
import 'theme.dart';
import 'sante/suivi.dart';

/// Barre d'onglets de l'appli (Accueil, Journal, Poids ; d'autres viendront).
/// Chaque onglet garde son état quand on change d'onglet. La coque possède le
/// suivi Health Connect, partagé entre les onglets.
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

class _CoqueState extends State<Coque> {
  int _onglet = 0;
  late final SuiviMeteo _meteoSuivi = SuiviMeteo(
    meteo: _s.meteo,
    bienetre: _s.bienetre,
    uid: widget.utilisateur.uid,
  );
  final ValueNotifier<InfoMiseAJour?> _maj = ValueNotifier(null);
  late final Future<String> _version = _s.versionAppli.version();

  Future<void> _verifierMaj() async {
    final info = await _s.miseAJour.verifier(await _version);
    if (mounted) _maj.value = info;
  }

  void _ouvrirReglages() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ReglagesPage(
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
    _suivi.charger(montre: widget.enregistre.profil.montre);
    unawaited(_verifierMaj());
  }

  @override
  void didUpdateWidget(Coque ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.enregistre.profil.montre != widget.enregistre.profil.montre) {
      _suivi.charger(montre: widget.enregistre.profil.montre);
    }
  }

  @override
  void dispose() {
    _suivi.dispose();
    _maj.dispose();
    _meteoSuivi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: [
          AccueilPage(
            utilisateur: widget.utilisateur,
            enregistre: widget.enregistre,
            auth: _s.auth,
            depot: _s.depot,
            sante: _s.sante,
            suivi: _suivi,
            horloge: widget.horloge,
            onOnglet: (i) => setState(() => _onglet = i),
            journal: _s.journal,
            bienetre: _s.bienetre,
            meteoSuivi: _meteoSuivi,
            miseAJour: _maj,
            onReglages: _ouvrirReglages,
            onIdees: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => IdeesPage(
                  utilisateur: widget.utilisateur,
                  objectif: widget.enregistre.profil.objectif,
                  kcalCible: widget.enregistre.reperes.kcalCible,
                  avis: _s.avis,
                  horloge: widget.horloge,
                ),
              ),
            ),
          ),
          JournalPage(
            utilisateur: widget.utilisateur,
            enregistre: widget.enregistre,
            journal: _s.journal,
            analyse: _s.analyse,
            planning: _s.planning,
            avis: _s.avis,
            consentements: _s.consentements,
            suivi: _suivi,
            horloge: widget.horloge,
          ),
          EntrainementPage(
            utilisateur: widget.utilisateur,
            enregistre: widget.enregistre,
            entrainement: _s.entrainement,
            journal: _s.journal,
            voix: _s.voix,
            suivi: _suivi,
            horloge: widget.horloge,
          ),
          PoidsPage(
            utilisateur: widget.utilisateur,
            enregistre: widget.enregistre,
            depot: _s.depot,
            pesees: _s.pesees,
            journal: _s.journal,
            mensurations: _s.mensurations,
            photos: _s.photos,
            sante: _s.sante,
            horloge: widget.horloge,
          ),
          BienEtrePage(
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
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<bool>(
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
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          NavigationBar(
            selectedIndex: _onglet,
            onDestinationSelected: (i) => setState(() => _onglet = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: t.tabAccueil,
              ),
              NavigationDestination(
                icon: const Icon(Icons.restaurant_outlined),
                selectedIcon: const Icon(Icons.restaurant),
                label: t.tabJournal,
              ),
              NavigationDestination(
                icon: const Icon(Icons.fitness_center_outlined),
                selectedIcon: const Icon(Icons.fitness_center),
                label: t.tabSport,
              ),
              NavigationDestination(
                icon: const Icon(Icons.monitor_weight_outlined),
                selectedIcon: const Icon(Icons.monitor_weight),
                label: t.tabPoids,
              ),
              NavigationDestination(
                icon: const Icon(Icons.spa_outlined),
                selectedIcon: const Icon(Icons.spa),
                label: t.tabBienEtre,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
