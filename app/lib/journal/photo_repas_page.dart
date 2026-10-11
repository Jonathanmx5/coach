import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../profil/saisie.dart';
import '../theme.dart';
import 'analyse_photo.dart';
import 'formulaires.dart';
import 'modele.dart';

/// Photo du repas : l'IA estime les aliments, l'utilisateur corrige les
/// portions et valide. Rend un [Repas], ou null si abandon.
class PhotoRepasPage extends StatefulWidget {
  const PhotoRepasPage({
    super.key,
    required this.date,
    required this.analyse,
    required this.prise,
  });

  final DateTime date;
  final AnalysePhoto analyse;
  final PrisePhoto prise;

  @override
  State<PhotoRepasPage> createState() => _PhotoRepasPageState();
}

enum _Phase { photo, analyse, resultat, erreur }

class _PhotoRepasPageState extends State<PhotoRepasPage> {
  _Phase _phase = _Phase.photo;
  Uint8List? _image;
  CauseAnalyse? _cause;
  List<AlimentEstime> _aliments = const [];
  final _gardes = <int>{};
  late Moment _moment = momentPourHeure(widget.date);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prendre());
  }

  Future<void> _prendre() async {
    final image = await widget.prise();
    if (!mounted) return;
    if (image == null) {
      Navigator.of(context).pop();
      return;
    }
    _image = image;
    await _analyser();
  }

  Future<void> _analyser() async {
    setState(() => _phase = _Phase.analyse);
    try {
      final liste = await widget.analyse.analyser(_image!);
      if (!mounted) return;
      setState(() {
        _aliments = liste;
        _gardes
          ..clear()
          ..addAll([for (var i = 0; i < liste.length; i++) i]);
        _phase = _Phase.resultat;
      });
    } on AnalyseEchouee catch (e) {
      if (!mounted) return;
      setState(() {
        _cause = e.cause;
        _phase = _Phase.erreur;
      });
    }
  }

  Macros get _total => totalAliments([for (final i in _gardes) _aliments[i]]);

  Future<void> _changerPortion(int i) async {
    final nouveau = await showDialog<double>(
      context: context,
      builder: (_) => _DialoguePortion(aliment: _aliments[i]),
    );
    if (nouveau != null) {
      setState(
        () =>
            _aliments = [..._aliments]..[i] = _aliments[i].avecGrammes(nouveau),
      );
    }
  }

  void _valider(AppLocalizations t) {
    final gardes = [for (final i in _gardes.toList()..sort()) _aliments[i]];
    Navigator.of(context).pop(
      Repas(
        date: widget.date,
        moment: _moment,
        nom: gardes.map((a) => a.nom).join(', '),
        macros: totalAliments(gardes),
        source: SourceRepas.photo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.menuPhoto)),
      body: switch (_phase) {
        _Phase.photo || _Phase.analyse => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_phase == _Phase.analyse ? t.analyseEnCours : ''),
            ],
          ),
        ),
        _Phase.erreur => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  switch (_cause!) {
                    CauseAnalyse.reseau => t.analyseReseau,
                    CauseAnalyse.auth => t.analyseAuth,
                    CauseAnalyse.quota => t.analyseQuota,
                    CauseAnalyse.illisible => t.analyseIllisible,
                    CauseAnalyse.indisponible => t.analyseIndisponible,
                  },
                  textAlign: TextAlign.center,
                  style: textes.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (_cause != CauseAnalyse.quota)
                  FilledButton(onPressed: _analyser, child: Text(t.reessayer)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.saisirALaMain),
                ),
              ],
            ),
          ),
        ),
        _Phase.resultat => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_aliments.isEmpty)
              Text(t.aucunAliment, style: textes.bodyLarge)
            else ...[
              Text(
                t.estimationAVerifier,
                style: textes.bodySmall?.copyWith(
                  color: CouleursCoach.texteDoux,
                ),
              ),
              for (var i = 0; i < _aliments.length; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _gardes.contains(i),
                  onChanged: (v) => setState(
                    () => v == true ? _gardes.add(i) : _gardes.remove(i),
                  ),
                  title: Text(_aliments[i].nom),
                  subtitle: Text(
                    '${_aliments[i].grammes.round()} g · '
                    '${_aliments[i].macros.kcal.round()} kcal',
                  ),
                  secondary: IconButton(
                    tooltip: t.changerPortion,
                    onPressed: () => _changerPortion(i),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in Moment.values)
                    ChoiceChip(
                      label: Text(libelleMoment(t, m)),
                      selected: m == _moment,
                      onSelected: (_) => setState(() => _moment = m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_total.kcal.round()} kcal · '
                '${_total.proteines.round()} g · '
                '${_total.glucides.round()} g · '
                '${_total.lipides.round()} g',
                style: textes.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _gardes.isEmpty ? null : () => _valider(t),
                child: Text(t.enregistrer),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.saisirALaMain),
            ),
          ],
        ),
      },
    );
  }
}

Macros totalAliments(Iterable<AlimentEstime> aliments) =>
    aliments.fold(Macros.zero, (s, a) => s + a.macros);

class _DialoguePortion extends StatefulWidget {
  const _DialoguePortion({required this.aliment});

  final AlimentEstime aliment;

  @override
  State<_DialoguePortion> createState() => _DialoguePortionState();
}

class _DialoguePortionState extends State<_DialoguePortion> {
  late final _texte = TextEditingController(
    text: widget.aliment.grammes.round().toString(),
  );
  String? _erreur;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.aliment.nom),
      content: TextField(
        controller: _texte,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: t.champQuantite,
          errorText: _erreur,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.annuler),
        ),
        FilledButton(
          onPressed: () {
            final g = lireNombre(_texte.text);
            if (g == null || g <= 0 || g > 5000) {
              setState(() => _erreur = t.erreurPlage(1, 5000));
              return;
            }
            Navigator.of(context).pop(g);
          },
          child: Text(t.enregistrer),
        ),
      ],
    );
  }
}
