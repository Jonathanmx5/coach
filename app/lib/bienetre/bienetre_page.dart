import 'dart:async';

import 'package:flutter/material.dart';

import '../compte/auth_service.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import '../l10n/app_localizations.dart';
import '../profil/profil_repository.dart';
import '../theme.dart';
import 'bienetre_repository.dart';
import 'hydratation.dart';
import 'meteo.dart';

/// Onglet Bien-être : hydratation, compléments et séries.
class BienEtrePage extends StatefulWidget {
  const BienEtrePage({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.bienetre,
    required this.journal,
    required this.meteo,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final BienEtreRepository bienetre;
  final JournalRepository journal;
  final Meteo meteo;
  final DateTime Function() horloge;

  @override
  State<BienEtrePage> createState() => _BienEtrePageState();
}

class _BienEtrePageState extends State<BienEtrePage> {
  double? _temp;
  bool _meteoDemandee = false;

  String get _uid => widget.utilisateur.uid;

  late final Stream<bool> _meteoActive = widget.bienetre.meteoActive(_uid);

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
    _activites = widget.journal.activites(_uid, jour, demain);
  }

  Future<void> _chargerMeteo() async {
    final t = await widget.meteo.temperatureMax();
    if (mounted) setState(() => _temp = t);
  }

  void _basculerMeteo(bool actif) {
    unawaited(widget.bienetre.activerMeteo(_uid, actif));
    if (!actif) setState(() => _temp = null);
  }

  void _boire(int ml) => unawaited(
    widget.bienetre.ajouterEau(_uid, EntreeEau(date: widget.horloge(), ml: ml)),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final maintenant = widget.horloge();
    _fluxDuJour(maintenant);
    return Scaffold(
      appBar: AppBar(title: Text(t.tabBienEtre)),
      body: StreamBuilder<bool>(
        stream: _meteoActive,
        builder: (context, snapMeteo) {
          final meteoActive = snapMeteo.data ?? false;
          if (meteoActive && !_meteoDemandee) {
            _meteoDemandee = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _chargerMeteo(),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
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
                        return _CarteHydratation(
                          objectifMl: objectifEauMl(
                            poidsKg: widget.enregistre.profil.poidsKg,
                            minutesEffort: minutes,
                            tempMaxC: meteoActive ? _temp : null,
                          ),
                          bu: totalEauMl(entrees),
                          minutesEffort: minutes,
                          temperature: meteoActive ? _temp : null,
                          meteoActive: meteoActive,
                          onBoire: _boire,
                          onAnnuler: entrees.isEmpty
                              ? null
                              : () => unawaited(
                                  widget.bienetre.supprimerEau(
                                    _uid,
                                    entrees.last.id!,
                                  ),
                                ),
                          onMeteo: _basculerMeteo,
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _litres(int ml) => (ml / 1000).toStringAsFixed(2).replaceAll('.', ',');

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
              t.eauBueSur(_litres(bu), _litres(objectifMl)),
              style: textes.headlineSmall?.copyWith(
                color: atteint ? CouleursCoach.vertMoyen : CouleursCoach.texte,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (bu / objectifMl).clamp(0, 1).toDouble(),
                minHeight: 10,
                color: const Color(0xFF378ADD),
                backgroundColor: const Color(0xFF378ADD).withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                t.eauBaseProfil,
                if (minutesEffort > 0) t.eauEffort(minutesEffort),
                if (temperature != null) t.eauChaleur(temperature!.round()),
              ].join(' · '),
              style: textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => onBoire(250),
                  child: Text(t.ajouterEau(250)),
                ),
                FilledButton.tonal(
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
