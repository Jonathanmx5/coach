import 'package:flutter/material.dart';

import 'accueil/accueil_page.dart';
import 'compte/auth_service.dart';
import 'journal/journal_page.dart';
import 'l10n/app_localizations.dart';
import 'poids/poids_page.dart';
import 'profil/profil_repository.dart';
import 'services.dart';
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
  Services get _s => widget.services;
  late final Suivi _suivi = Suivi(sante: _s.sante, horloge: widget.horloge);

  @override
  void initState() {
    super.initState();
    _suivi.charger(montre: widget.enregistre.profil.montre);
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
          ),
          JournalPage(
            utilisateur: widget.utilisateur,
            enregistre: widget.enregistre,
            journal: _s.journal,
            catalogue: _s.catalogue,
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
            sante: _s.sante,
            horloge: widget.horloge,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
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
            icon: const Icon(Icons.monitor_weight_outlined),
            selectedIcon: const Icon(Icons.monitor_weight),
            label: t.tabPoids,
          ),
        ],
      ),
    );
  }
}
