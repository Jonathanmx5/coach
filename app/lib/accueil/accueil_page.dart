import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../compte/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../profil/besoins.dart';
import '../profil/modele.dart';
import '../profil/profil_repository.dart';
import '../profil/questionnaire/controleur.dart';
import '../profil/questionnaire/etapes.dart';
import '../profil/questionnaire/questionnaire_page.dart';
import '../sante/ajustements.dart';
import '../sante/carte_journee.dart';
import '../sante/mes_donnees_page.dart';
import '../sante/sante_service.dart';
import '../sante/suivi.dart';
import '../theme.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.auth,
    required this.depot,
    required this.sante,
    required this.suivi,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final AuthService auth;
  final ProfilRepository depot;
  final SanteService sante;
  final Suivi suivi;
  final DateTime Function() horloge;

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  Suivi get _suivi => widget.suivi;

  Profil get _profil => widget.enregistre.profil;

  @override
  void initState() {
    super.initState();
    _suivi.addListener(_importerPoids);
  }

  @override
  void dispose() {
    _suivi.removeListener(_importerPoids);
    super.dispose();
  }

  Future<void> _charger() => _suivi.charger(montre: _profil.montre);

  Future<void> _autoriser() async {
    await widget.sante.demanderAutorisations();
    await _charger();
  }

  /// Spec santé connectée §4 : la pesée la plus récente met le profil à jour.
  void _importerPoids() {
    final pesee = poidsAImporter(_suivi.pesees, _profil.poidsDate);
    if (pesee == null) return;
    final profil = _profil.copyWith(
      poidsKg: (pesee.valeur * 10).round() / 10,
      poidsDate: pesee.date,
    );
    // Hors-ligne, l'écriture ne se termine qu'à la synchronisation.
    unawaited(
      widget.depot.enregistrer(
        widget.utilisateur.uid,
        profil,
        calculerReperes(profil, maintenant: widget.horloge()),
      ),
    );
  }

  void _modifierProfil() {
    // Créé hors du builder : la route peut être reconstruite sans perdre
    // les réponses.
    final controleur = QuestionnaireControleur.depuis(
      _profil,
      maintenant: widget.horloge(),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => QuestionnairePage(
          controleur: controleur,
          auth: widget.auth,
          depot: widget.depot,
          sante: widget.sante,
          horloge: widget.horloge,
          quandTermine: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final prenom = widget.utilisateur.prenom;
    final doux = textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: _suivi,
          builder: (context, _) {
            // Repères recalculés en direct avec le maintien mesuré.
            final reperes = calculerReperes(
              _profil,
              maintenant: widget.horloge(),
              maintienMesure: _suivi.maintien,
            );
            return RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _EnTete(
                    salutation: prenom == null
                        ? t.accueilBonjourSansNom
                        : t.accueilBonjour(prenom),
                    objectif: t.objectifPastille(
                      libelleObjectif(t, _profil.objectif).toLowerCase(),
                    ),
                    initiale: prenom?.substring(0, 1).toUpperCase(),
                    tooltipDeconnexion: t.boutonDeconnexion,
                    onDeconnexion: widget.auth.deconnecter,
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
                                  note: reperes.source == SourceMaintien.mesure
                                      ? t.sourceMesure
                                      : t.sourceEstime,
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
                        CarteJournee(
                          suivi: _suivi,
                          montre: _profil.montre,
                          onConnecter: _modifierProfil,
                          onAutoriser: _autoriser,
                          onDetail: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MesDonneesPage(suivi: _suivi),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          onPressed: _modifierProfil,
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
            );
          },
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
    this.note,
    required this.fond,
    required this.couleur,
  });

  final IconData icone;
  final String valeur;
  final String libelle;
  final String? note;
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
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note!, style: textes.labelSmall?.copyWith(color: couleur)),
          ],
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
