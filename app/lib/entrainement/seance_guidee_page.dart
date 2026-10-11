import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'modele.dart';
import 'voix.dart';

/// Séance pas à pas : minuteur, annonces vocales, bouton « Fait » pour les
/// efforts en répétitions. Rend `true` si la séance est menée jusqu'au bout.
class SeanceGuideePage extends StatefulWidget {
  const SeanceGuideePage({super.key, required this.seance, required this.voix});

  final Seance seance;
  final Voix voix;

  @override
  State<SeanceGuideePage> createState() => _SeanceGuideePageState();
}

class _SeanceGuideePageState extends State<SeanceGuideePage> {
  int _index = 0;
  int _restant = 0;
  bool _pause = false;
  bool _voixActive = true;
  bool _fini = false;
  Timer? _minuteur;

  Etape get _etape => widget.seance.etapes[_index];

  @override
  void initState() {
    super.initState();
    _ecranAllume(true);
    _commencerEtape();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    widget.voix.arreter();
    _ecranAllume(false);
    super.dispose();
  }

  Future<void> _ecranAllume(bool actif) async {
    try {
      await (actif ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {
      // Sans verrou d'écran, le minuteur continue tant que l'appli est ouverte.
    }
  }

  void _dire(String texte) {
    if (_voixActive) unawaited(widget.voix.dire(texte));
  }

  void _commencerEtape() {
    _minuteur?.cancel();
    final e = _etape;
    _restant = e.secondes;
    final duree = e.secondes > 0
        ? (e.secondes >= 60
              ? ' ${e.secondes ~/ 60} minute${e.secondes >= 120 ? 's' : ''}.'
              : ' ${e.secondes} secondes.')
        : (e.reps > 0 ? ' ${e.reps} répétitions.' : '');
    _dire('${e.titre}.$duree ${e.repos ? '' : e.consigne}');
    if (e.secondes > 0) {
      _minuteur = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
    }
  }

  void _tic() {
    if (_pause || !mounted) return;
    setState(() => _restant--);
    if (_restant > 0 && _restant <= 3) _dire('$_restant');
    if (_restant <= 0) _suivante();
  }

  void _suivante() {
    _minuteur?.cancel();
    if (_index >= widget.seance.etapes.length - 1) {
      setState(() => _fini = true);
      _dire('Séance terminée. Bravo !');
      return;
    }
    setState(() => _index++);
    _commencerEtape();
  }

  String _horloge(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    if (_fini) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.seance.titre)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 72,
                  color: CouleursCoach.orange,
                ),
                const SizedBox(height: 16),
                Text(t.seanceTerminee, style: textes.headlineSmall),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(t.terminer),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final e = _etape;
    final total = widget.seance.etapes.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.seance.titre),
        actions: [
          IconButton(
            tooltip: _voixActive ? t.couperVoix : t.activerVoix,
            onPressed: () => setState(() => _voixActive = !_voixActive),
            icon: Icon(_voixActive ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: (_index + 1) / total),
            const SizedBox(height: 4),
            Text(
              t.etapeSur(_index + 1, total),
              style: textes.labelMedium?.copyWith(
                color: CouleursCoach.texteDoux,
              ),
            ),
            const Spacer(),
            Text(
              e.titre,
              textAlign: TextAlign.center,
              style: textes.headlineSmall?.copyWith(
                color: e.repos ? CouleursCoach.orange : CouleursCoach.vert,
              ),
            ),
            const SizedBox(height: 16),
            if (e.secondes > 0)
              Text(
                _horloge(_restant < 0 ? 0 : _restant),
                textAlign: TextAlign.center,
                style: textes.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(
                t.repetitions(e.reps),
                textAlign: TextAlign.center,
                style: textes.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              e.consigne,
              textAlign: TextAlign.center,
              style: textes.bodyLarge,
            ),
            const Spacer(),
            if (e.secondes > 0)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _pause = !_pause),
                      icon: Icon(_pause ? Icons.play_arrow : Icons.pause),
                      label: Text(_pause ? t.reprendre : t.pause),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _suivante,
                      icon: const Icon(Icons.skip_next),
                      label: Text(t.passer),
                    ),
                  ),
                ],
              )
            else
              FilledButton(onPressed: _suivante, child: Text(t.fait)),
          ],
        ),
      ),
    );
  }
}
