import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../profil/saisie.dart';
import '../theme.dart';
import 'analyse_photo.dart';
import 'modele.dart';
import 'table_ciqual.dart';

/// Quand l'IA doute : l'utilisateur dit ce que c'est et relance l'analyse.
class CartePrecision extends StatelessWidget {
  const CartePrecision({
    super.key,
    required this.controleur,
    required this.onReanalyser,
  });

  final TextEditingController controleur;
  final VoidCallback onReanalyser;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      color: context.palette.orangeClair,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.analyseIncertaine,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controleur,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: t.precisionLabel,
                hintText: t.precisionAide,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onReanalyser,
                icon: const Icon(Icons.refresh),
                label: Text(t.reanalyser),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Combien de grammes du produit scanné ont été mangés.
class DialoguePortion extends StatefulWidget {
  const DialoguePortion({super.key, required this.nom});

  final String nom;

  @override
  State<DialoguePortion> createState() => DialoguePortionState();
}

class DialoguePortionState extends State<DialoguePortion> {
  final _grammes = TextEditingController(text: '100');

  @override
  void dispose() {
    _grammes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final valeur = double.tryParse(_grammes.text.replaceAll(',', '.'));
    return AlertDialog(
      title: Text(widget.nom),
      content: TextField(
        controller: _grammes,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: t.scanPortionLabel),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.annuler),
        ),
        FilledButton(
          onPressed: valeur == null || valeur <= 0 || valeur > 5000
              ? null
              : () => Navigator.of(context).pop(valeur),
          child: Text(t.ajouter),
        ),
      ],
    );
  }
}

Macros totalAliments(Iterable<AlimentEstime> aliments) =>
    aliments.fold(Macros.zero, (s, a) => s + a.macros);

/// Au plus 40 aliments par repas (borne des règles Firestore).
const maxAliments = 40;

/// Longueur maximale du nom d'un repas construit à partir de ses aliments.
const maxNomRepas = 200;

/// Nom d'un repas analysé : ses aliments, coupés à [maxNomRepas] caractères.
String nomDuRepas(Iterable<AlimentEstime> aliments) {
  final nom = aliments.map((a) => a.nom).join(', ');
  return nom.length <= maxNomRepas
      ? nom
      : '${nom.substring(0, maxNomRepas - 1)}…';
}

/// Portion après un appui sur + ([sens] = 1) ou − (−1) : environ 10 %, arrondi
/// à 5 g, mais toujours au moins 5 g d'écart (une petite portion d'huile ou
/// de sauce bouge aussi), et jamais moins de 5 g.
double portionSuivante(double grammes, int sens) {
  final pas = math.max(5.0, (grammes * 0.1 / 5).round() * 5.0);
  return math.max(5.0, grammes + sens * pas);
}

/// Modifie le nom et la portion d'un aliment estimé, ou en crée un nouveau
/// (avec ses calories et macros) quand [modele] est null.
class DialogueAliment extends StatefulWidget {
  const DialogueAliment({super.key, this.modele});

  final AlimentEstime? modele;

  @override
  State<DialogueAliment> createState() => DialogueAlimentState();
}

class DialogueAlimentState extends State<DialogueAliment> {
  late final _nom = TextEditingController(text: widget.modele?.nom ?? '');
  late final _grammes = TextEditingController(
    text: widget.modele?.grammes.round().toString() ?? '',
  );
  final _kcal = TextEditingController();
  final _prot = TextEditingController();
  final _gluc = TextEditingController();
  final _lip = TextEditingController();
  String? _erreur;

  /// Aliment choisi dans la table Ciqual : ses valeurs pour 100 g servent.
  AlimentCiqual? _ciqual;

  bool get _creation => widget.modele == null;

  @override
  void dispose() {
    for (final c in [_nom, _grammes, _kcal, _prot, _gluc, _lip]) {
      c.dispose();
    }
    super.dispose();
  }

  void _valider(AppLocalizations t) {
    final nom = _nom.text.trim();
    final g = lireNombre(_grammes.text);
    if (nom.isEmpty) {
      setState(() => _erreur = t.erreurNomAliment);
      return;
    }
    if (g == null || g <= 0 || g > 5000) {
      setState(() => _erreur = t.erreurPlage(1, 5000));
      return;
    }
    final choisi = _ciqual;
    if (choisi != null) {
      Navigator.of(context)
          .pop(choisi.pour(g, nomAffiche: nom).valideParUtilisateur());
      return;
    }
    if (!_creation) {
      final base = widget.modele!;
      // Corrigé par l'utilisateur : il n'est plus « à vérifier ».
      Navigator.of(context)
          .pop(base.avecGrammes(g).avecNom(nom).valideParUtilisateur());
      return;
    }
    final kcal = lireNombre(_kcal.text);
    if (kcal == null || kcal < 0 || kcal > 5000) {
      setState(() => _erreur = t.erreurPlage(0, 5000));
      return;
    }
    double facultatif(TextEditingController c) =>
        c.text.trim().isEmpty ? 0 : (lireNombre(c.text) ?? 0);
    Navigator.of(context).pop(
      AlimentEstime(
        nom: nom,
        grammes: g,
        macros: Macros(
          kcal: kcal,
          proteines: facultatif(_prot),
          glucides: facultatif(_gluc),
          lipides: facultatif(_lip),
        ),
      ),
    );
  }

  Widget _champ(
    TextEditingController c,
    String label, {
    bool texte = false,
    int? longueurMax,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: c,
      maxLength: longueurMax,
      keyboardType: texte
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      textCapitalization: texte
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) {
        if (_erreur != null) setState(() => _erreur = null);
      },
    ),
  );

  Future<void> _chercher([String cuisson = '']) async {
    final a = await showDialog<AlimentCiqual>(
      context: context,
      builder: (_) =>
          DialogueRechercheCiqual(depart: '${_nom.text} $cuisson'.trim()),
    );
    if (a == null || !mounted) return;
    setState(() {
      _ciqual = a;
      _erreur = null;
      final court = a.nom.split(',').first.trim();
      _nom.text = court.length <= 60 ? court : court.substring(0, 60);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(_creation ? t.ajouterAliment : t.modifierAliment),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _champ(_nom, t.nomAliment, texte: true, longueurMax: 60),
            _champ(_grammes, t.champQuantite),
            TextButton.icon(
              onPressed: _chercher,
              icon: const Icon(Icons.search),
              label: Text(t.ciqualChercher),
            ),
            if (!_creation) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.cuissonTitre,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final (libelle, mot) in [
                    (t.cuissonVapeur, 'vapeur'),
                    (t.cuissonPoele, 'poêlé'),
                    (t.cuissonFrit, 'frit'),
                    (t.cuissonFour, 'four'),
                    (t.cuissonBouilli, 'bouilli'),
                  ])
                    ActionChip(
                      label: Text(libelle),
                      onPressed: () => _chercher(mot),
                    ),
                ],
              ),
            ],
            if (_ciqual != null)
              Text(
                t.valeursCiqual(_ciqual!.nom),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            if (_creation && _ciqual == null) ...[
              _champ(_kcal, t.champKcal),
              _champ(_prot, t.champProteines),
              _champ(_gluc, t.champGlucides),
              _champ(_lip, t.champLipides),
            ],
            if (_erreur != null)
              Text(
                _erreur!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.annuler),
        ),
        FilledButton(onPressed: () => _valider(t), child: Text(t.enregistrer)),
      ],
    );
  }
}
