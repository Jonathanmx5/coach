import 'package:flutter/material.dart';

import '../compte/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../profil/profil_repository.dart';
import '../profil/questionnaire/controleur.dart';
import '../profil/questionnaire/etapes.dart';
import '../profil/questionnaire/questionnaire_page.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.auth,
    required this.depot,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final AuthService auth;
  final ProfilRepository depot;
  final DateTime Function() horloge;

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  bool _reperesVisibles = false;

  void _modifierProfil() {
    final controleur = QuestionnaireControleur.depuis(widget.enregistre.profil,
        maintenant: widget.horloge());
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => QuestionnairePage(
        controleur: controleur,
        auth: widget.auth,
        depot: widget.depot,
        horloge: widget.horloge,
        quandTermine: () => Navigator.of(routeContext).pop(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final prenom = widget.utilisateur.prenom;
    final reperes = widget.enregistre.reperes;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitre),
        actions: [
          TextButton(
            onPressed: widget.auth.deconnecter,
            child: Text(t.boutonDeconnexion),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(prenom == null ? t.accueilBonjourSansNom : t.accueilBonjour(prenom),
              style: textes.headlineMedium),
          const SizedBox(height: 4),
          Text(libelleObjectif(t, widget.enregistre.profil.objectif),
              style: textes.titleMedium),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(t.accueilProgrammeBientot),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () =>
                setState(() => _reperesVisibles = !_reperesVisibles),
            child: Text(t.boutonVoirReperes),
          ),
          if (_reperesVisibles)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.reperesKcal(reperes.kcalCible),
                        style: textes.titleMedium),
                    const SizedBox(height: 8),
                    Text(t.reperesProteines(reperes.proteinesG),
                        style: textes.titleMedium),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _modifierProfil,
            child: Text(t.boutonModifierProfil),
          ),
          const SizedBox(height: 24),
          Text(t.mentionMedicale,
              textAlign: TextAlign.center, style: textes.bodySmall),
        ],
      ),
    );
  }
}
