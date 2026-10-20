import 'dart:async';

import 'package:flutter/material.dart';

import 'accueil/bienvenue_page.dart';
import 'compte/auth_service.dart';
import 'coque.dart';
import 'profil/profil_repository.dart';
import 'profil/questionnaire/controleur.dart';
import 'profil/questionnaire/questionnaire_page.dart';
import 'services.dart';
import 'route_verre.dart';

/// Aiguillage : bienvenue, questionnaire ou accueil selon la connexion et le
/// profil enregistré.
class Racine extends StatefulWidget {
  const Racine({super.key, required this.services, required this.horloge});

  final Services services;
  final DateTime Function() horloge;

  @override
  State<Racine> createState() => _RacineState();
}

class _RacineState extends State<Racine> {
  Services get _s => widget.services;
  late final Stream<Utilisateur?> _utilisateur = _s.auth.changements;

  /// Vrai une fois le widget de l'écran d'accueil vidé pour l'absence de
  /// compte en cours : une seule fois par déconnexion.
  bool _widgetVide = false;

  /// Déconnexion ou compte supprimé : le widget de l'écran d'accueil, visible
  /// de tous, ne garde ni les chiffres ni l'eau du compte.
  void _viderWidget(Utilisateur? u) {
    if (u != null) {
      _widgetVide = false;
      return;
    }
    if (_widgetVide) return;
    _widgetVide = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_s.widgetAccueil.effacer()),
    );
  }

  void _commencer() {
    // Créé hors du builder : la route peut être reconstruite sans perdre
    // les réponses.
    final controleur = QuestionnaireControleur(
      maintenant: widget.horloge(),
      avecConnexion: true,
    );
    Navigator.of(context).push(
      routeVerre<void>(
        (routeContext) => QuestionnairePage(
          controleur: controleur,
          auth: _s.auth,
          depot: _s.depot,
          sante: _s.sante,
          horloge: widget.horloge,
          quandTermine: () =>
              Navigator.of(routeContext).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Utilisateur?>(
    stream: _utilisateur,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const _Chargement();
      }
      final u = snap.data;
      _viderWidget(u);
      if (u == null) {
        return BienvenuePage(auth: _s.auth, onCommencer: _commencer);
      }
      return _ProfilUtilisateur(
        key: ValueKey(u.uid),
        utilisateur: u,
        services: _s,
        horloge: widget.horloge,
      );
    },
  );
}

class _ProfilUtilisateur extends StatefulWidget {
  const _ProfilUtilisateur({
    super.key,
    required this.utilisateur,
    required this.services,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final Services services;
  final DateTime Function() horloge;

  @override
  State<_ProfilUtilisateur> createState() => _ProfilUtilisateurState();
}

class _ProfilUtilisateurState extends State<_ProfilUtilisateur> {
  Services get _s => widget.services;
  late final Stream<ProfilEnregistre?> _profil = _s.depot.observer(
    widget.utilisateur.uid,
  );

  // Connecté sans profil : questionnaire sans étape de connexion.
  late final _controleur = QuestionnaireControleur(
    maintenant: widget.horloge(),
    avecConnexion: false,
  );

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ProfilEnregistre?>(
    stream: _profil,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const _Chargement();
      }
      final enregistre = snap.data;
      if (enregistre == null) {
        return QuestionnairePage(
          controleur: _controleur,
          auth: _s.auth,
          depot: _s.depot,
          sante: _s.sante,
          horloge: widget.horloge,
          // Le flux du profil fait basculer vers l'accueil.
          quandTermine: () {},
        );
      }
      return Coque(
        utilisateur: widget.utilisateur,
        enregistre: enregistre,
        services: _s,
        horloge: widget.horloge,
      );
    },
  );
}

class _Chargement extends StatelessWidget {
  const _Chargement();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
