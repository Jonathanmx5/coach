import 'package:flutter/material.dart';

import 'accueil/accueil_page.dart';
import 'compte/auth_service.dart';
import 'l10n/app_localizations.dart';
import 'poids/pesees_repository.dart';
import 'poids/poids_page.dart';
import 'profil/profil_repository.dart';
import 'sante/sante_service.dart';

/// Barre d'onglets de l'appli (Accueil, Poids ; d'autres viendront).
/// Chaque onglet garde son état quand on change d'onglet.
class Coque extends StatefulWidget {
  const Coque({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.auth,
    required this.depot,
    required this.pesees,
    required this.sante,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final AuthService auth;
  final ProfilRepository depot;
  final PeseesRepository pesees;
  final SanteService sante;
  final DateTime Function() horloge;

  @override
  State<Coque> createState() => _CoqueState();
}

class _CoqueState extends State<Coque> {
  int _onglet = 0;

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
            auth: widget.auth,
            depot: widget.depot,
            sante: widget.sante,
            horloge: widget.horloge,
          ),
          PoidsPage(
            utilisateur: widget.utilisateur,
            enregistre: widget.enregistre,
            depot: widget.depot,
            pesees: widget.pesees,
            sante: widget.sante,
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
            icon: const Icon(Icons.monitor_weight_outlined),
            selectedIcon: const Icon(Icons.monitor_weight),
            label: t.tabPoids,
          ),
        ],
      ),
    );
  }
}
