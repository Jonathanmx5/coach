import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../profil/saisie.dart';
import '../theme.dart';
import 'analyse_photo.dart';
import 'calculs.dart';
import 'catalogue.dart';
import 'scanner_page.dart';
import 'formulaires.dart';
import '../profil/modele.dart';
import 'modele.dart';
import 'photos_repas.dart';
import 'verdict.dart';

/// Résultat de [PhotoRepasPage] quand l'utilisateur préfère tout saisir à la
/// main (ou que l'analyse est impossible).
class SaisieManuelle {
  const SaisieManuelle();
}

/// Photo du repas : l'IA estime les aliments, l'utilisateur ajuste, ajoute ou
/// retire des aliments, voit l'effet sur sa journée et valide.
/// Rend un [Repas], une [SaisieManuelle], ou null si abandon.
class PhotoRepasPage extends StatefulWidget {
  const PhotoRepasPage({
    super.key,
    required this.date,
    required this.analyse,
    required this.prise,
    required this.photos,
    required this.catalogue,
    this.scan = lireCodeBarres,
    this.dejaMange = Macros.zero,
    this.cibles,
    this.objectif = Objectif.forme,
  });

  final DateTime date;
  final AnalysePhoto analyse;
  final PrisePhoto prise;
  final PhotosRepas photos;
  final CatalogueProduits catalogue;
  final ScanCode scan;

  /// Ce qui est déjà noté aujourd'hui et les objectifs du jour, pour montrer
  /// l'effet du repas ; sans [cibles], cette ligne n'est pas affichée.
  final Macros dejaMange;
  final CiblesJour? cibles;
  final Objectif objectif;

  @override
  State<PhotoRepasPage> createState() => _PhotoRepasPageState();
}

enum _Phase { choix, apercu, analyse, resultat, erreur }

class _PhotoRepasPageState extends State<PhotoRepasPage> {
  _Phase _phase = _Phase.choix;
  Uint8List? _image;
  CauseAnalyse? _cause;
  List<AlimentEstime> _aliments = const [];
  String _description = '';
  final _gardes = <int>{};

  /// Vrai quand l'aliment vient d'un code-barres plutôt que d'une photo.
  bool _viaCode = false;
  final _precision = TextEditingController();
  late Moment _moment = momentPourHeure(widget.date);

  @override
  void dispose() {
    _precision.dispose();
    super.dispose();
  }

  Future<void> _choisir(SourcePhoto source) async {
    final image = await widget.prise(source);
    if (image == null || !mounted) return;
    setState(() {
      _image = image;
      _phase = _Phase.apercu;
    });
  }

  void _signaler(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  /// Produit emballé : le code-barres donne des valeurs exactes pour 100 g,
  /// l'utilisateur dit combien il en a mangé.
  Future<void> _scanner() async {
    final t = AppLocalizations.of(context)!;
    final code = await widget.scan(context);
    if (code == null || !mounted) return;
    setState(() => _phase = _Phase.analyse);
    final ProduitOff? produit;
    try {
      produit = await widget.catalogue.chercher(code);
    } on ErreurCatalogue {
      if (!mounted) return;
      setState(() => _phase = _Phase.choix);
      _signaler(t.catalogueErreur);
      return;
    }
    if (!mounted) return;
    if (produit == null) {
      setState(() => _phase = _Phase.choix);
      _signaler(t.produitInconnu);
      return;
    }
    // Le sablier est retiré avant la question : rien ne tourne derrière.
    setState(() => _phase = _Phase.choix);
    final grammes = await showDialog<double>(
      context: context,
      builder: (_) => _DialoguePortion(nom: produit!.nom),
    );
    if (!mounted) return;
    if (grammes == null) {
      setState(() => _phase = _Phase.choix);
      return;
    }
    final f = grammes / 100;
    setState(() {
      _viaCode = true;
      _image = null;
      _description = produit!.nom;
      _aliments = [
        AlimentEstime(
          nom: produit.nom,
          grammes: grammes,
          macros: produit.pour100g.multiplie(f),
          sucres: produit.sucres100g == null ? null : produit.sucres100g! * f,
          satures: produit.satures100g == null
              ? null
              : produit.satures100g! * f,
        ),
      ];
      _gardes
        ..clear()
        ..add(0);
      _phase = _Phase.resultat;
    });
  }

  Future<void> _analyser() async {
    setState(() => _phase = _Phase.analyse);
    try {
      final analyse = await widget.analyse.analyser(
        _image!,
        indice: _precision.text,
      );
      if (!mounted) return;
      final liste = analyse.aliments;
      setState(() {
        _description = analyse.description;
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

  void _manuel() => Navigator.of(context).pop(const SaisieManuelle());

  List<AlimentEstime> get _retenus => [
    for (final i in _gardes.toList()..sort()) _aliments[i],
  ];

  static double? _somme(
    List<AlimentEstime> l,
    double? Function(AlimentEstime) f,
  ) {
    final valeurs = [for (final a in l) f(a)].whereType<double>();
    return valeurs.isEmpty ? null : valeurs.fold<double>(0, (s, v) => s + v);
  }

  /// ±10 % de la portion, arrondi à 5 g.
  void _ajuster(int i, double facteur) {
    final g = _aliments[i].grammes;
    final nouveau = ((g * facteur) / 5).round() * 5.0;
    setState(
      () =>
          _aliments = [..._aliments]
            ..[i] = _aliments[i].avecGrammes(nouveau < 5 ? 5 : nouveau),
    );
  }

  Future<void> _modifier(int i) async {
    final a = await showDialog<AlimentEstime>(
      context: context,
      builder: (_) => _DialogueAliment(modele: _aliments[i]),
    );
    if (a != null) setState(() => _aliments = [..._aliments]..[i] = a);
  }

  Future<void> _ajouter() async {
    final a = await showDialog<AlimentEstime>(
      context: context,
      builder: (_) => const _DialogueAliment(),
    );
    if (a == null) return;
    setState(() {
      _aliments = [..._aliments, a];
      _gardes.add(_aliments.length - 1);
    });
  }

  Future<void> _valider() async {
    final gardes = _retenus;
    // La photo reste sur le téléphone ; si elle ne peut pas être gardée, le
    // repas est enregistré quand même.
    final cibles = widget.cibles;
    final verdictFige = cibles == null || gardes.isEmpty
        ? null
        : verdictRepas(
            repas: totalAliments(gardes),
            sucres: _somme(gardes, (a) => a.sucres),
            satures: _somme(gardes, (a) => a.satures),
            dejaMange: widget.dejaMange,
            cibles: cibles,
            objectif: widget.objectif,
          );
    String? photoId;
    try {
      if (_image != null) photoId = await widget.photos.enregistrer(_image!);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(
      Repas(
        date: widget.date,
        moment: _moment,
        nom: gardes.map((a) => a.nom).join(', '),
        macros: totalAliments(gardes),
        source: _viaCode ? SourceRepas.codeBarres : SourceRepas.photo,
        description: _description,
        aliments: gardes,
        photoId: photoId,
        verdict: verdictFige,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.menuPhoto)),
      body: switch (_phase) {
        _Phase.choix => _choix(t),
        _Phase.apercu => _apercu(t),
        _Phase.analyse => _attente(t),
        _Phase.erreur => _erreur(t),
        _Phase.resultat => _resultat(t),
      },
    );
  }

  Widget _vignette({double hauteur = 220}) => _image == null
      ? const SizedBox.shrink()
      : ClipRRect(
          borderRadius: BorderRadius.circular(rayonCarte),
          child: SizedBox(
            height: hauteur,
            width: double.infinity,
            child: Image.memory(
              _image!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: CouleursCoach.vertPale,
                child: Icon(Icons.restaurant),
              ),
            ),
          ),
        );

  Widget _choix(AppLocalizations t) {
    final textes = Theme.of(context).textTheme;
    Widget carte(IconData icone, String texte, SourcePhoto? source) => Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => source == null ? _scanner() : _choisir(source),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Column(
            children: [
              Icon(icone, size: 40, color: CouleursCoach.vert),
              const SizedBox(height: 10),
              Text(texte, style: textes.titleMedium),
            ],
          ),
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(t.photoConseil, style: textes.bodyMedium),
        const SizedBox(height: 16),
        carte(
          Icons.photo_camera_outlined,
          t.prendrePhotoRepas,
          SourcePhoto.appareil,
        ),
        carte(
          Icons.photo_library_outlined,
          t.galerieChoix,
          SourcePhoto.galerie,
        ),
        carte(Icons.qr_code_scanner, t.scanTitre, null),
        const SizedBox(height: 8),
        TextButton(onPressed: _manuel, child: Text(t.saisirALaMain)),
      ],
    );
  }

  Widget _apercu(AppLocalizations t) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _vignette(hauteur: 260),
      const SizedBox(height: 16),
      TextField(
        controller: _precision,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: t.precisionLabel,
          hintText: t.precisionAide,
        ),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _analyser,
        icon: const Icon(Icons.auto_awesome),
        label: Text(t.analyserRepas),
      ),
      TextButton(
        onPressed: () => setState(() => _phase = _Phase.choix),
        child: Text(t.changerPhoto),
      ),
    ],
  );

  Widget _attente(AppLocalizations t) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 220, child: _vignette(hauteur: 160)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(t.analyseEnCours),
        ],
      ),
    ),
  );

  Widget _erreur(AppLocalizations t) => Center(
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
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (_cause != CauseAnalyse.quota)
            FilledButton(onPressed: _analyser, child: Text(t.reessayer)),
          if (_cause == CauseAnalyse.illisible)
            TextButton(
              onPressed: () => setState(() => _phase = _Phase.choix),
              child: Text(t.changerPhoto),
            ),
          TextButton(onPressed: _manuel, child: Text(t.saisirALaMain)),
        ],
      ),
    ),
  );

  Widget _resultat(AppLocalizations t) {
    final textes = Theme.of(context).textTheme;
    final retenus = _retenus;
    final cibles = widget.cibles;
    double? somme(double? Function(AlimentEstime) f) {
      final valeurs = [for (final a in retenus) f(a)].whereType<double>();
      return valeurs.isEmpty ? null : valeurs.fold<double>(0, (s, v) => s + v);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _vignette(hauteur: 170),
        const SizedBox(height: 12),
        if (_aliments.isEmpty)
          Text(t.aucunAliment, style: textes.bodyLarge)
        else if (retenus.isNotEmpty && cibles != null)
          CarteVerdict(
            description: _description,
            repas: totalAliments(retenus),
            sucres: somme((a) => a.sucres),
            satures: somme((a) => a.satures),
            verdict: verdictRepas(
              repas: totalAliments(retenus),
              sucres: somme((a) => a.sucres),
              satures: somme((a) => a.satures),
              dejaMange: widget.dejaMange,
              cibles: cibles,
              objectif: widget.objectif,
            ),
          ),
        if (_image != null &&
            (_aliments.isEmpty || _aliments.any((a) => a.aVerifier))) ...[
          const SizedBox(height: 12),
          _CartePrecision(controleur: _precision, onReanalyser: _analyser),
        ],
        if (_aliments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            t.estimationAVerifier,
            style: textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux),
          ),
        ],
        for (var i = 0; i < _aliments.length; i++) _ligne(t, i),
        OutlinedButton.icon(
          onPressed: _ajouter,
          icon: const Icon(Icons.add),
          label: Text(t.ajouterAliment),
        ),
        const SizedBox(height: 12),
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
        FilledButton(
          onPressed: _gardes.isEmpty ? null : _valider,
          child: Text(t.enregistrer),
        ),
        TextButton(onPressed: _manuel, child: Text(t.saisirALaMain)),
      ],
    );
  }

  Widget _ligne(AppLocalizations t, int i) {
    final a = _aliments[i];
    final textes = Theme.of(context).textTheme;
    final garde = _gardes.contains(i);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          children: [
            Checkbox(
              value: garde,
              onChanged: (v) => setState(
                () => v == true ? _gardes.add(i) : _gardes.remove(i),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _modifier(i),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nom,
                      style: textes.titleSmall?.copyWith(
                        decoration: garde ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      '${a.grammes.round()} g · ${a.macros.kcal.round()} kcal',
                      style: textes.bodySmall,
                    ),
                    if (a.aVerifier)
                      Text(
                        t.aVerifier,
                        style: textes.labelSmall?.copyWith(
                          color: CouleursCoach.orangeFonce,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: t.moinsPortion,
              onPressed: () => _ajuster(i, 1 / 1.1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              tooltip: t.plusPortion,
              onPressed: () => _ajuster(i, 1.1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carton du coach : couleur, ce que c'est, les apports et le verdict détaillé.
class CarteVerdict extends StatelessWidget {
  const CarteVerdict({
    super.key,
    required this.description,
    required this.repas,
    required this.sucres,
    required this.satures,
    required this.verdict,
  });

  final String description;
  final Macros repas;
  final double? sucres;
  final double? satures;
  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final (couleur, fond, titre) = switch (verdict.feu) {
      Feu.vert => (
        CouleursCoach.vertMoyen,
        CouleursCoach.vertClair,
        t.cartonVert,
      ),
      Feu.orange => (
        CouleursCoach.orange,
        CouleursCoach.orangeClair,
        t.cartonOrange,
      ),
      Feu.rouge => (
        const Color(0xFFE24B4A),
        const Color(0xFFFCE8E8),
        t.cartonRouge,
      ),
    };
    Widget tuile(String libelle, String valeur, String? detail) => Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(libelle, style: textes.labelSmall),
            Text(valeur, style: textes.titleMedium),
            if (detail != null)
              Text(
                detail,
                style: textes.labelSmall?.copyWith(
                  color: CouleursCoach.texteDoux,
                ),
              ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(rayonCarte),
        border: Border.all(color: couleur, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: couleur, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(titre, style: textes.titleLarge)),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.ilSagit(description), style: textes.bodyMedium),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              tuile(t.tuileCalories, '${repas.kcal.round()} kcal', null),
              tuile(t.tuileProteines, '${repas.proteines.round()} g', null),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              tuile(
                t.tuileGlucides,
                '${repas.glucides.round()} g',
                sucres == null ? null : t.dontSucres(sucres!.round()),
              ),
              tuile(
                t.tuileLipides,
                '${repas.lipides.round()} g',
                satures == null ? null : t.dontSatures(satures!.round()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(t.verdictCoach, style: textes.titleMedium),
          const SizedBox(height: 4),
          for (final p in verdict.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $p', style: textes.bodyMedium),
            ),
          const SizedBox(height: 6),
          Text(
            verdict.conclusion,
            style: textes.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Quand l'IA doute : l'utilisateur dit ce que c'est et relance l'analyse.
class _CartePrecision extends StatelessWidget {
  const _CartePrecision({required this.controleur, required this.onReanalyser});

  final TextEditingController controleur;
  final VoidCallback onReanalyser;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      color: CouleursCoach.orangeClair,
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
class _DialoguePortion extends StatefulWidget {
  const _DialoguePortion({required this.nom});

  final String nom;

  @override
  State<_DialoguePortion> createState() => _DialoguePortionState();
}

class _DialoguePortionState extends State<_DialoguePortion> {
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

/// Modifie le nom et la portion d'un aliment estimé, ou en crée un nouveau
/// (avec ses calories et macros) quand [modele] est null.
class _DialogueAliment extends StatefulWidget {
  const _DialogueAliment({this.modele});

  final AlimentEstime? modele;

  @override
  State<_DialogueAliment> createState() => _DialogueAlimentState();
}

class _DialogueAlimentState extends State<_DialogueAliment> {
  late final _nom = TextEditingController(text: widget.modele?.nom ?? '');
  late final _grammes = TextEditingController(
    text: widget.modele?.grammes.round().toString() ?? '',
  );
  final _kcal = TextEditingController();
  final _prot = TextEditingController();
  final _gluc = TextEditingController();
  final _lip = TextEditingController();
  String? _erreur;

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
    if (!_creation) {
      final base = widget.modele!;
      Navigator.of(context).pop(base.avecGrammes(g).avecNom(nom));
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

  Widget _champ(TextEditingController c, String label, {bool texte = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(_creation ? t.ajouterAliment : t.modifierAliment),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _champ(_nom, t.nomAliment, texte: true),
            _champ(_grammes, t.champQuantite),
            if (_creation) ...[
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
