import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../compte/auth_service.dart';
import '../bienetre/bienetre_repository.dart';
import '../bienetre/suivi_meteo.dart';
import '../journal/journal_repository.dart';
import '../l10n/app_localizations.dart';
import '../widget/donnees_widget.dart';
import 'anneaux.dart';
import '../profil/besoins.dart';
import '../profil/modele.dart';
import '../profil/profil_repository.dart';
import '../profil/questionnaire/controleur.dart';
import '../profil/questionnaire/etapes.dart';
import '../profil/questionnaire/questionnaire_page.dart';
import '../reglages/mises_a_jour.dart';
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
    required this.onOnglet,
    required this.journal,
    required this.bienetre,
    required this.meteoSuivi,
    required this.onIdees,
    required this.miseAJour,
    required this.onReglages,
    this.majWidget,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final AuthService auth;
  final ProfilRepository depot;
  final SanteService sante;
  final Suivi suivi;
  final DateTime Function() horloge;

  /// Ouvre un onglet de la barre du bas (1 Repas, 2 Sport, 3 Poids, 4 Bien-être).
  final ValueChanged<int> onOnglet;
  final JournalRepository journal;
  final BienEtreRepository bienetre;
  final SuiviMeteo meteoSuivi;

  /// Ouvre les idées de repas.
  final VoidCallback onIdees;

  /// Mise à jour proposée : un point orange s'affiche sur l'engrenage.
  final ValueListenable<InfoMiseAJour?> miseAJour;

  /// Ouvre les réglages.
  final VoidCallback onReglages;

  /// Widget de l'écran d'accueil tenu à jour avec les chiffres du jour.
  final MiseAJourWidget? majWidget;

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
    final prenom = widget.utilisateur.prenom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: _suivi,
          builder: (context, _) {
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
                    tooltipReglages: t.reglagesInfobulle,
                    miseAJour: widget.miseAJour,
                    onReglages: widget.onReglages,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CarteAujourdhui(
                          key: ValueKey(widget.horloge().day),
                          uid: widget.utilisateur.uid,
                          profil: _profil,
                          suivi: _suivi,
                          journal: widget.journal,
                          bienetre: widget.bienetre,
                          meteoSuivi: widget.meteoSuivi,
                          horloge: widget.horloge,
                          onOnglet: widget.onOnglet,
                          majWidget: widget.majWidget,
                        ),
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
                        _CarteAction(
                          icone: Icons.fitness_center,
                          titre: t.carteProgramme,
                          sousTitre: t.carteProgrammeSous,
                          fond: context.palette.vertClair,
                          couleur: CouleursCoach.vert,
                          onTap: () => widget.onOnglet(2),
                        ),
                        const SizedBox(height: 12),
                        _CarteAction(
                          icone: Icons.swipe_outlined,
                          titre: t.carteIdees,
                          sousTitre: t.carteIdeesSous,
                          fond: context.palette.orangeClair,
                          couleur: context.palette.orangeFonce,
                          onTap: widget.onIdees,
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.palette.texteDoux),
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
    required this.tooltipReglages,
    required this.miseAJour,
    required this.onReglages,
  });

  final String salutation;
  final String objectif;
  final String? initiale;
  final String tooltipReglages;
  final ValueListenable<InfoMiseAJour?> miseAJour;
  final VoidCallback onReglages;

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
              ValueListenableBuilder<InfoMiseAJour?>(
                valueListenable: miseAJour,
                builder: (context, maj, _) => IconButton(
                  tooltip: tooltipReglages,
                  onPressed: onReglages,
                  color: Colors.white,
                  icon: Badge(
                    smallSize: 10,
                    backgroundColor: CouleursCoach.orange,
                    isLabelVisible: maj != null,
                    child: const Icon(Icons.settings_outlined),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteAction extends StatelessWidget {
  const _CarteAction({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.fond,
    required this.couleur,
    required this.onTap,
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final Color fond;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                        color: context.palette.texteDoux,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.palette.texteDoux),
            ],
          ),
        ),
      ),
    );
  }
}
