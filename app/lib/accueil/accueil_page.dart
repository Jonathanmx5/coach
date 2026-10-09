import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../compte/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../profil/profil_repository.dart';
import '../profil/questionnaire/controleur.dart';
import '../profil/questionnaire/etapes.dart';
import '../profil/questionnaire/questionnaire_page.dart';
import '../sante/sante_service.dart';
import '../theme.dart';

class AccueilPage extends StatelessWidget {
  const AccueilPage({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.auth,
    required this.depot,
    required this.sante,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final AuthService auth;
  final ProfilRepository depot;
  final SanteService sante;
  final DateTime Function() horloge;

  void _modifierProfil(BuildContext context) {
    // Créé hors du builder : la route peut être reconstruite sans perdre
    // les réponses.
    final controleur = QuestionnaireControleur.depuis(
      enregistre.profil,
      maintenant: horloge(),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => QuestionnairePage(
          controleur: controleur,
          auth: auth,
          depot: depot,
          sante: sante,
          horloge: horloge,
          quandTermine: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final reperes = enregistre.reperes;
    final prenom = utilisateur.prenom;
    final doux = textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _EnTete(
              salutation: prenom == null
                  ? t.accueilBonjourSansNom
                  : t.accueilBonjour(prenom),
              objectif: t.objectifPastille(
                libelleObjectif(t, enregistre.profil.objectif).toLowerCase(),
              ),
              initiale: prenom?.substring(0, 1).toUpperCase(),
              tooltipDeconnexion: t.boutonDeconnexion,
              onDeconnexion: auth.deconnecter,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.reperesTitre, style: textes.titleLarge),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _TuileRepere(
                            icone: Icons.local_fire_department_outlined,
                            valeur: '${reperes.kcalCible}',
                            libelle: t.reperesKcalLabel,
                            fond: CouleursCoach.orangeClair,
                            couleur: CouleursCoach.orangeFonce,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TuileRepere(
                            icone: Icons.egg_outlined,
                            valeur: t.reperesProteinesValeur(
                              reperes.proteinesG,
                            ),
                            libelle: t.reperesProteinesLabel,
                            fond: CouleursCoach.vertClair,
                            couleur: CouleursCoach.vertFonce,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(t.reperesEstimation, style: doux),
                  const SizedBox(height: 24),
                  _CarteBientot(
                    icone: Icons.fitness_center,
                    titre: t.carteProgramme,
                    sousTitre: t.bientot,
                    fond: CouleursCoach.vertClair,
                    couleur: CouleursCoach.vert,
                  ),
                  const SizedBox(height: 12),
                  _CarteBientot(
                    icone: Icons.photo_camera_outlined,
                    titre: t.cartePhoto,
                    sousTitre: t.bientot,
                    fond: CouleursCoach.orangeClair,
                    couleur: CouleursCoach.orangeFonce,
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => _modifierProfil(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(t.boutonModifierProfil),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.mentionMedicale,
                    textAlign: TextAlign.center,
                    style: doux,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.salutation,
    required this.objectif,
    required this.initiale,
    required this.tooltipDeconnexion,
    required this.onDeconnexion,
  });

  final String salutation;
  final String objectif;
  final String? initiale;
  final String tooltipDeconnexion;
  final VoidCallback onDeconnexion;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: CouleursCoach.vert,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 28),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: CouleursCoach.vertMoyen,
                foregroundColor: Colors.white,
                child: initiale == null
                    ? const Icon(Icons.person_outline)
                    : Text(
                        initiale!,
                        style: textes.titleLarge?.copyWith(color: Colors.white),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salutation,
                      style: textes.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: CouleursCoach.vertFonce,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        objectif,
                        style: textes.labelMedium?.copyWith(
                          color: CouleursCoach.vertPale,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tooltipDeconnexion,
                onPressed: onDeconnexion,
                color: Colors.white,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TuileRepere extends StatelessWidget {
  const _TuileRepere({
    required this.icone,
    required this.valeur,
    required this.libelle,
    required this.fond,
    required this.couleur,
  });

  final IconData icone;
  final String valeur;
  final String libelle;
  final Color fond;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(rayonCarte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur),
          const SizedBox(height: 10),
          Text(valeur, style: textes.headlineMedium?.copyWith(color: couleur)),
          Text(libelle, style: textes.bodyMedium?.copyWith(color: couleur)),
        ],
      ),
    );
  }
}

class _CarteBientot extends StatelessWidget {
  const _CarteBientot({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.fond,
    required this.couleur,
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final Color fond;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: fond,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icone, color: couleur),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, style: textes.titleMedium),
                  Text(
                    sousTitre,
                    style: textes.bodyMedium?.copyWith(
                      color: CouleursCoach.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.schedule, color: CouleursCoach.texteDoux),
          ],
        ),
      ),
    );
  }
}
