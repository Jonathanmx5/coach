import 'dart:async';

import 'package:flutter/material.dart';

import '../../compte/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../besoins.dart';
import '../profil_repository.dart';
import 'controleur.dart';
import 'etapes.dart';

class QuestionnairePage extends StatefulWidget {
  const QuestionnairePage({
    super.key,
    required this.controleur,
    required this.auth,
    required this.depot,
    required this.horloge,
    required this.quandTermine,
  });

  final QuestionnaireControleur controleur;
  final AuthService auth;
  final ProfilRepository depot;
  final DateTime Function() horloge;
  final VoidCallback quandTermine;

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  bool _connexionEnCours = false;
  bool _connexionEchouee = false;

  QuestionnaireControleur get _c => widget.controleur;

  void _terminer(String uid) {
    final profil = _c.construireProfil();
    final reperes = calculerReperes(profil, maintenant: widget.horloge());
    // Hors-ligne, l'écriture ne se termine qu'à la synchronisation :
    // le cache local suffit pour avancer.
    unawaited(widget.depot.enregistrer(uid, profil, reperes));
    widget.quandTermine();
  }

  Future<void> _connecter() async {
    setState(() {
      _connexionEnCours = true;
      _connexionEchouee = false;
    });
    try {
      final u = await widget.auth.connecterGoogle();
      if (!mounted) return;
      setState(() => _connexionEnCours = false);
      if (u != null) _terminer(u.uid);
    } on ConnexionEchouee {
      if (!mounted) return;
      setState(() {
        _connexionEnCours = false;
        _connexionEchouee = true;
      });
    }
  }

  void _avancer() {
    if (_c.estDerniereEtape) {
      final uid = widget.auth.actuel?.uid;
      if (uid != null) _terminer(uid);
    } else {
      _c.suivant();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final alerte = _c.alerte;
        final enConnexion = _c.etape == Etape.connexion;
        final numero = _c.etapes.indexOf(_c.etape) + 1;
        final premiere = numero == 1;
        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      if (premiere)
                        const SizedBox(width: 12, height: 48)
                      else
                        IconButton(
                          tooltip: t.boutonRetour,
                          onPressed: _connexionEnCours ? null : _c.precedent,
                          icon: const Icon(Icons.arrow_back),
                        ),
                      Text(
                        t.etapeSur(numero, _c.etapes.length),
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: CouleursCoach.texteDoux),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _BarreEtapes(total: _c.etapes.length, faites: numero),
                ),
                Expanded(
                  child: ListView(
                    key: ValueKey(_c.etape),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    children: [
                      Text(
                        titreEtape(t, _c.etape),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      ...contenuEtape(context, _c),
                      if (enConnexion) ..._contenuConnexion(t),
                      if (alerte != null) ...[
                        const SizedBox(height: 16),
                        EncadreAlerte(texteAlerte(t, alerte)),
                      ],
                    ],
                  ),
                ),
                if (!enConnexion)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: FilledButton(
                      onPressed: _c.peutContinuer ? _avancer : null,
                      child: Text(t.boutonSuivant),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _contenuConnexion(AppLocalizations t) => [
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Icon(
        Icons.cloud_done_outlined,
        size: 88,
        color: CouleursCoach.vert,
      ),
    ),
    if (_connexionEnCours)
      const Center(child: CircularProgressIndicator())
    else
      FilledButton.icon(
        onPressed: _connecter,
        icon: const Icon(Icons.login),
        label: Text(t.boutonGoogle),
      ),
    if (_connexionEchouee) ...[
      const SizedBox(height: 16),
      EncadreAlerte(t.erreurConnexion),
    ],
  ];
}

class _BarreEtapes extends StatelessWidget {
  const _BarreEtapes({required this.total, required this.faites});

  final int total;
  final int faites;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 6,
            decoration: BoxDecoration(
              color: i < faites ? CouleursCoach.vert : CouleursCoach.bordure,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ],
  );
}
