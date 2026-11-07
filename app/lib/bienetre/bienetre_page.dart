import 'dart:async';

import 'package:flutter/material.dart';

import '../compte/auth_service.dart';
import '../compte/donnees_compte.dart';
import '../ecriture.dart';
import '../format.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import '../journal/signalement.dart';
import '../l10n/app_localizations.dart';
import '../profil/profil_repository.dart';
import '../theme.dart';
import '../verre.dart';
import '../entrainement/entrainement_repository.dart';
import 'bienetre_repository.dart';
import 'bloc_series.dart';
import 'carte_complements.dart';
import 'complements.dart';
import 'hydratation.dart';
import 'suivi_meteo.dart';
import 'rappels.dart';

/// Onglet Bien-être : hydratation, compléments et séries.
class BienEtrePage extends StatefulWidget {
  const BienEtrePage({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.bienetre,
    required this.journal,
    required this.meteoSuivi,
    required this.rappels,
    required this.entrainement,
    required this.consentements,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final BienEtreRepository bienetre;
  final JournalRepository journal;
  final SuiviMeteo meteoSuivi;
  final Rappels rappels;
  final EntrainementRepository entrainement;
  final ConsentementsRepository consentements;
  final DateTime Function() horloge;

  @override
  State<BienEtrePage> createState() => _BienEtrePageState();
}

class _BienEtrePageState extends State<BienEtrePage> {
  String get _uid => widget.utilisateur.uid;

  Stream<Set<String>>? _prises;

  /// Une seule écoute des compléments : elle sert à l'affichage et aux
  /// rappels, qui suivent la liste (même hors-ligne, avec les identifiants).
  StreamSubscription<List<Complement>>? _complements;
  List<Complement> _listeComplements = const [];

  @override
  void initState() {
    super.initState();
    _complements = widget.bienetre.complements(_uid).listen((l) {
      if (mounted) setState(() => _listeComplements = l);
      unawaited(widget.rappels.planifier(l));
    }, onError: signalerErreur);
  }

  @override
  void dispose() {
    _complements?.cancel();
    super.dispose();
  }

  /// Écriture sans attente ; un refus des règles est signalé par [message].
  void _ecrire(
    Future<void> ecriture,
    String Function(AppLocalizations t) message,
  ) {
    final messager = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context)!;
    ecrireSansAttendre(
      ecriture,
      surRefus: () => messager
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message(t)))),
    );
  }

  void _modifier(Future<void> ecriture) =>
      _ecrire(ecriture, (t) => t.modificationNonEnregistree);

  void _ajouterComplement(String nom, int minutes) {
    unawaited(widget.rappels.autoriser());
    _modifier(
      widget.bienetre.ajouterComplement(
        _uid,
        Complement(nom: nom, minutes: minutes),
      ),
    );
  }

  DateTime _jourFlux = DateTime(0);
  Stream<List<EntreeEau>>? _eau;
  Stream<List<Activite>>? _activites;

  /// Les flux sont ceux du jour courant ; ils changent à minuit.
  void _fluxDuJour(DateTime maintenant) {
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    if (_jourFlux == jour) return;
    _jourFlux = jour;
    final demain = DateTime(jour.year, jour.month, jour.day + 1);
    _eau = widget.bienetre.eau(_uid, jour, demain);
    _prises = widget.bienetre.prises(_uid, jour);
    _activites = widget.journal.activites(_uid, jour, demain);
  }

  Future<void> _basculerMeteo(bool actif) async {
    if (actif) {
      final accord = await assurerConsentement(
        context,
        widget.consentements,
        _uid,
        Consentement.meteo,
      );
      if (!accord || !mounted) return;
    }
    _modifier(widget.bienetre.activerMeteo(_uid, actif));
  }

  void _boire(int ml) => _ecrire(
    widget.bienetre.ajouterEau(_uid, EntreeEau(date: widget.horloge(), ml: ml)),
    (t) => t.eauNonEnregistree,
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final maintenant = widget.horloge();
    _fluxDuJour(maintenant);
    return Scaffold(
      appBar: AppBar(title: Text(t.tabBienEtre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ColonnesAdaptatives(
            gauche: [
              StreamBuilder<List<Activite>>(
                stream: _activites,
                builder: (context, snapActivites) =>
                    StreamBuilder<List<EntreeEau>>(
                      stream: _eau,
                      builder: (context, snapEau) {
                        final minutes =
                            (snapActivites.data ?? const <Activite>[])
                                .fold<int>(0, (s, a) => s + a.minutes);
                        final entrees = snapEau.data ?? const <EntreeEau>[];
                        return ListenableBuilder(
                          listenable: widget.meteoSuivi,
                          builder: (context, _) => _CarteHydratation(
                            objectifMl: objectifEauMl(
                              poidsKg: widget.enregistre.profil.poidsKg,
                              minutesEffort: minutes,
                              tempMaxC: widget.meteoSuivi.temperature,
                            ),
                            bu: totalEauMl(entrees),
                            minutesEffort: minutes,
                            temperature: widget.meteoSuivi.temperature,
                            meteoActive: widget.meteoSuivi.actif,
                            onBoire: _boire,
                            onAnnuler: entrees.isEmpty
                                ? null
                                : () => _modifier(
                                    widget.bienetre.supprimerEau(
                                      _uid,
                                      entrees.last.id!,
                                    ),
                                  ),
                            onMeteo: _basculerMeteo,
                          ),
                        );
                      },
                    ),
              ),
              const SizedBox(height: 16),
            ],
            droite: [
              BlocSeries(
                key: ValueKey(_jourFlux),
                uid: _uid,
                poidsKg: widget.enregistre.profil.poidsKg,
                joursParSemaine: widget.enregistre.profil.joursParSemaine,
                maintenant: maintenant,
                journal: widget.journal,
                entrainement: widget.entrainement,
                bienetre: widget.bienetre,
              ),
              const SizedBox(height: 16),
              StreamBuilder<Set<String>>(
                stream: _prises,
                builder: (context, snapPrises) => CarteComplements(
                  complements: _listeComplements,
                  prises: snapPrises.data ?? const {},
                  onPris: (c, pris) => _modifier(
                    widget.bienetre.marquerPris(
                      _uid,
                      widget.horloge(),
                      c.id!,
                      pris,
                    ),
                  ),
                  onAjouter: _ajouterComplement,
                  onBasculer: (c) => _modifier(
                    widget.bienetre.modifierComplement(
                      _uid,
                      c.copyWith(actif: !c.actif),
                    ),
                  ),
                  onSupprimer: (c) => _modifier(
                    widget.bienetre.supprimerComplement(_uid, c.id!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarteHydratation extends StatelessWidget {
  const _CarteHydratation({
    required this.objectifMl,
    required this.bu,
    required this.minutesEffort,
    required this.temperature,
    required this.meteoActive,
    required this.onBoire,
    required this.onAnnuler,
    required this.onMeteo,
  });

  final int objectifMl;
  final int bu;
  final int minutesEffort;
  final double? temperature;
  final bool meteoActive;
  final ValueChanged<int> onBoire;
  final VoidCallback? onAnnuler;
  final ValueChanged<bool> onMeteo;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final atteint = bu >= objectifMl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.hydratationTitre, style: textes.titleMedium),
            const SizedBox(height: 8),
            Text(
              t.eauBueSur(formatLitres(bu), formatLitres(objectifMl)),
              style: textes.headlineSmall?.copyWith(
                color: atteint
                    ? CouleursCoach.vertMoyen
                    : context.palette.texte,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (bu / objectifMl).clamp(0, 1).toDouble(),
                minHeight: 10,
                color: CouleursCoach.bleu,
                backgroundColor: CouleursCoach.bleu.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                t.eauBaseProfil,
                if (minutesEffort > 0) t.eauEffort(minutesEffort),
                if (temperature != null) t.eauChaleur(temperature!.round()),
              ].join(' · '),
              style: textes.bodySmall?.copyWith(
                color: context.palette.texteDoux,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => onBoire(250),
                  child: Text(t.ajouterEau(250)),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => onBoire(500),
                  child: Text(t.ajouterEau(500)),
                ),
                if (onAnnuler != null)
                  TextButton(
                    onPressed: onAnnuler,
                    child: Text(t.annulerDernier),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.adapterMeteo),
              subtitle: Text(t.meteoAide),
              value: meteoActive,
              onChanged: onMeteo,
            ),
          ],
        ),
      ),
    );
  }
}
