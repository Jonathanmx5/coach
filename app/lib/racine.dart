import 'package:flutter/material.dart';

import 'accueil/accueil_page.dart';
import 'accueil/bienvenue_page.dart';
import 'compte/auth_service.dart';
import 'profil/profil_repository.dart';
import 'profil/questionnaire/controleur.dart';
import 'profil/questionnaire/questionnaire_page.dart';
import 'sante/sante_service.dart';

/// Aiguillage : bienvenue, questionnaire ou accueil selon la connexion et le
/// profil enregistré.
class Racine extends StatefulWidget {
  const Racine({
    super.key,
    required this.auth,
    required this.depot,
    required this.sante,
    required this.horloge,
  });

  final AuthService auth;
  final ProfilRepository depot;
  final SanteService sante;
  final DateTime Function() horloge;

  @override
  State<Racine> createState() => _RacineState();
}

class _RacineState extends State<Racine> {
  late final Stream<Utilisateur?> _utilisateur = widget.auth.changements;

  void _commencer() {
    // Créé hors du builder : la route peut être reconstruite sans perdre
    // les réponses.
    final controleur = QuestionnaireControleur(
      maintenant: widget.horloge(),
      avecConnexion: true,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => QuestionnairePage(
          controleur: controleur,
          auth: widget.auth,
          depot: widget.depot,
          sante: widget.sante,
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
      if (u == null) {
        return BienvenuePage(auth: widget.auth, onCommencer: _commencer);
      }
      return _ProfilUtilisateur(
        key: ValueKey(u.uid),
        utilisateur: u,
        auth: widget.auth,
        depot: widget.depot,
        sante: widget.sante,
        horloge: widget.horloge,
      );
    },
  );
}

class _ProfilUtilisateur extends StatefulWidget {
  const _ProfilUtilisateur({
    super.key,
    required this.utilisateur,
    required this.auth,
    required this.depot,
    required this.sante,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final AuthService auth;
  final ProfilRepository depot;
  final SanteService sante;
  final DateTime Function() horloge;

  @override
  State<_ProfilUtilisateur> createState() => _ProfilUtilisateurState();
}

class _ProfilUtilisateurState extends State<_ProfilUtilisateur> {
  late final Stream<ProfilEnregistre?> _profil = widget.depot.observer(
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
          auth: widget.auth,
          depot: widget.depot,
          sante: widget.sante,
          horloge: widget.horloge,
          // Le flux du profil fait basculer vers l'accueil.
          quandTermine: () {},
        );
      }
      return AccueilPage(
        utilisateur: widget.utilisateur,
        enregistre: enregistre,
        auth: widget.auth,
        depot: widget.depot,
        sante: widget.sante,
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
