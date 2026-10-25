import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'ajustement.dart';
import 'analyse_photo.dart';
import 'calculs.dart';
import 'carte_verdict.dart';
import 'dialogues_aliment.dart';
import 'catalogue.dart';
import 'scanner_page.dart';
import 'formulaires.dart';
import '../profil/modele.dart';
import 'modele.dart';
import 'photos_repas.dart';
import 'preferences_analyse.dart';
import 'repas_recents.dart';
import 'signalement.dart';
import 'verdict.dart';

// Réexportés : d'autres écrans s'en servent.
export 'carte_verdict.dart';
export 'dialogues_aliment.dart'
    show totalAliments, portionSuivante, nomDuRepas, maxAliments;

/// Résultat de [PhotoRepasPage] quand l'utilisateur préfère tout saisir à la
/// main (ou que l'analyse est impossible).
class SaisieManuelle {
  const SaisieManuelle();
}

/// Demande (ou retrouve) l'accord pour envoyer la photo à l'analyse par IA ;
/// vrai si l'utilisateur est d'accord.
typedef AccordPhoto = Future<bool> Function(BuildContext context);

/// Photo du repas : l'IA estime les aliments, l'utilisateur ajuste, ajoute ou
/// retire des aliments, voit l'effet sur sa journée et valide. Le code-barres,
/// les repas récents et la saisie à la main n'envoient rien à l'IA : seul le
/// choix d'une photo demande l'accord.
/// Rend un [Repas], une [SaisieManuelle], ou null si abandon.
class PhotoRepasPage extends StatefulWidget {
  const PhotoRepasPage({
    super.key,
    required this.date,
    required this.analyse,
    required this.prise,
    required this.photos,
    required this.catalogue,
    required this.accordPhoto,
    this.recents,
    this.scan = lireCodeBarres,
    this.sourceInitiale,
    this.dejaMange = Macros.zero,
    this.cibles,
    this.objectif = Objectif.forme,
    this.preferences = const PreferencesAnalyseNeutres(),
  });

  final DateTime date;
  final AnalysePhoto analyse;
  final PrisePhoto prise;
  final PhotosRepas photos;
  final CatalogueProduits catalogue;
  final ScanCode scan;

  /// Demandé avant de prendre ou de choisir une photo, jamais pour le
  /// code-barres ni la saisie à la main.
  final AccordPhoto accordPhoto;

  /// Repas des derniers jours, à remettre au journal en un appui (voir
  /// [repasRecents]) ; null : la liste n'est pas proposée.
  final Future<List<Repas>>? recents;

  /// Ouvre tout de suite l'appareil (ou la bibliothèque) au lieu du choix.
  final SourcePhoto? sourceInitiale;

  /// Ce qui est déjà noté aujourd'hui et les objectifs du jour, pour montrer
  /// l'effet du repas ; sans [cibles], cette ligne n'est pas affichée.
  final Macros dejaMange;
  final CiblesJour? cibles;
  final Objectif objectif;

  /// Taille des assiettes et portions apprises des corrections passées.
  final PreferencesAnalyse preferences;

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

  /// Aliments ajoutés à la main : gardés quand on relance l'analyse.
  final _manuels = <int>{};

  /// Corrections à la main du total (boutons + et − des tuiles).
  Ajustement _ajustement = const Ajustement();

  /// Vrai quand l'aliment vient d'un code-barres plutôt que d'une photo.
  bool _viaCode = false;

  /// Huile de cuisson et sauce que la photo montre mal, ajoutées au repas.
  QuantiteGras _huile = QuantiteGras.aucune;
  QuantiteGras _sauce = QuantiteGras.aucune;

  /// Ce que l'IA avait estimé pour chacun des premiers aliments (même ordre),
  /// pour apprendre des corrections ; vide pour un code-barres.
  List<({String nom, double grammes})> _ia = const [];

  /// Aliments dont la portion a été ajustée d'après les corrections passées,
  /// avec le facteur appliqué.
  final _calibres = <int, double>{};

  /// Vrai pendant l'enregistrement : un second appui ne fait rien.
  bool _enregistrement = false;

  /// Analyses photo encore possibles aujourd'hui, d'après la dernière réponse
  /// du relais ; null s'il n'en a rien dit.
  int? _restantes;

  /// Sans relais configuré, pas de photo : restent le code-barres, les repas
  /// récents et la saisie à la main.
  bool get _photoPossible => widget.analyse.disponible;
  final _precision = TextEditingController();
  late Moment _moment = momentPourHeure(widget.date);

  @override
  void initState() {
    super.initState();
    final source = widget.sourceInitiale;
    if (source != null && _photoPossible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_choisir(source));
      });
    }
  }

  @override
  void dispose() {
    _precision.dispose();
    super.dispose();
  }

  Future<void> _choisir(SourcePhoto source) async {
    final t = AppLocalizations.of(context)!;
    if (!_photoPossible) return;
    // La photo n'est prise que pour être analysée : l'accord est demandé
    // avant, et un refus laisse les autres façons de noter le repas.
    final bool accord;
    try {
      accord = await widget.accordPhoto(context);
    } catch (e, s) {
      signalerErreur(e, s);
      if (mounted) _signaler(t.photoIndisponible);
      return;
    }
    if (!mounted) return;
    if (!accord) {
      _signaler(t.photoSansAccord);
      return;
    }
    final Uint8List? image;
    try {
      image = await widget.prise(source);
    } on PlatformException catch (e, s) {
      if (!mounted) return;
      if (source == SourcePhoto.appareil && e.code.contains('access_denied')) {
        // Accès à l'appareil photo refusé : la galerie reste possible.
        _signaler(
          t.cameraRefusee,
          action: SnackBarAction(
            label: t.galerieCourt,
            onPressed: () => unawaited(_choisir(SourcePhoto.galerie)),
          ),
        );
      } else {
        signalerErreur(e, s);
        _signaler(t.photoIndisponible);
      }
      return;
    } catch (e, s) {
      signalerErreur(e, s);
      if (mounted) _signaler(t.photoIndisponible);
      return;
    }
    if (image == null || !mounted) return;
    setState(() {
      _image = image;
      _phase = _Phase.apercu;
    });
  }

  void _signaler(String texte, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte), action: action));
  }

  /// Remplace le résultat par [liste] (nouvelle analyse ou produit scanné) :
  /// les aliments ajoutés à la main restent, et la correction des tuiles,
  /// faite pour l'ancien résultat, est oubliée.
  void _remplacer(List<AlimentEstime> liste) {
    final manuels = [
      for (final i in _manuels.toList()..sort())
        if (i < _aliments.length)
          (aliment: _aliments[i], garde: _gardes.contains(i)),
    ];
    _aliments = [...liste, for (final m in manuels) m.aliment];
    _ajustement = const Ajustement();
    _ia = const [];
    _calibres.clear();
    _gardes
      ..clear()
      ..addAll([for (var i = 0; i < liste.length; i++) i]);
    _manuels.clear();
    for (var j = 0; j < manuels.length; j++) {
      _manuels.add(liste.length + j);
      if (manuels[j].garde) _gardes.add(liste.length + j);
    }
  }

  /// Produit emballé : le code-barres donne des valeurs exactes pour 100 g,
  /// l'utilisateur dit combien il en a mangé.
  Future<void> _scanner() async {
    final t = AppLocalizations.of(context)!;
    final code = await widget.scan(context);
    if (code == null || !mounted) return;
    setState(() {
      _ajustement = const Ajustement();
      _phase = _Phase.analyse;
    });
    final ProduitOff? produit;
    try {
      produit = await widget.catalogue.chercher(code);
    } on ErreurCatalogue {
      if (!mounted) return;
      setState(() => _phase = _Phase.choix);
      _signaler(t.catalogueErreur);
      return;
    } catch (e, s) {
      // Réponse inattendue (une donnée d'un autre type…) : pas de sablier
      // infini, retour au choix.
      signalerErreur(e, s);
      if (!mounted) return;
      setState(() => _phase = _Phase.choix);
      _signaler(t.produitIllisible);
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
      builder: (_) => DialoguePortion(nom: produit!.nom),
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
      _remplacer([
        AlimentEstime(
          nom: produit.nom,
          grammes: grammes,
          macros: produit.pour100g.multiplie(f),
          sucres: produit.sucres100g == null ? null : produit.sucres100g! * f,
          satures: produit.satures100g == null
              ? null
              : produit.satures100g! * f,
        ),
      ]);
      _phase = _Phase.resultat;
    });
  }

  Future<void> _analyser() async {
    setState(() {
      _ajustement = const Ajustement();
      _phase = _Phase.analyse;
    });
    try {
      final analyse = await widget.analyse.analyser(
        _image!,
        indice: indiceAvecAssiette(
          _precision.text,
          widget.preferences.assietteCm,
        ),
      );
      if (!mounted) return;
      setState(() {
        _restantes = analyse.restantes;
        _description = analyse.description;
        final calibres = <int, double>{};
        _remplacer([
          for (var i = 0; i < analyse.aliments.length; i++)
            _calibrer(analyse.aliments[i], i, calibres),
        ]);
        _ia = [
          for (final a in analyse.aliments) (nom: a.nom, grammes: a.grammes),
        ];
        _calibres.addAll(calibres);
        _phase = _Phase.resultat;
      });
    } on AnalyseEchouee catch (e) {
      if (!mounted) return;
      setState(() {
        _cause = e.cause;
        _phase = _Phase.erreur;
      });
    } catch (e, s) {
      // Erreur imprévue : on propose de réessayer plutôt qu'un sablier infini.
      signalerErreur(e, s);
      if (!mounted) return;
      setState(() {
        _cause = CauseAnalyse.indisponible;
        _phase = _Phase.erreur;
      });
    }
  }

  void _manuel() => Navigator.of(context).pop(const SaisieManuelle());

  /// Remet au journal un repas récent, daté du jour affiché, sans photo ; son
  /// verdict est celui de la journée en cours.
  void _reprendre(Repas r) {
    if (_enregistrement) return;
    _enregistrement = true;
    final cibles = widget.cibles;
    Navigator.of(context).pop(
      repasRepris(
        r,
        date: widget.date,
        verdict: cibles == null
            ? null
            : verdictRepas(
                repas: r.macros,
                sucres: _somme(r.aliments, (a) => a.sucres),
                satures: _somme(r.aliments, (a) => a.satures),
                dejaMange: widget.dejaMange,
                cibles: cibles,
                objectif: widget.objectif,
              ),
      ),
    );
  }

  List<AlimentEstime> get _retenus {
    final t = AppLocalizations.of(context)!;
    return [
      for (final i in _gardes.toList()..sort()) _aliments[i],
      if (_aliments.isNotEmpty)
        ...grasAjoutes(
          huile: _huile,
          sauce: _sauce,
          nomHuile: t.grasHuile,
          nomSauce: t.grasSauce,
        ),
    ];
  }

  /// Portion de l'IA corrigée d'après les corrections passées de la personne
  /// pour cet aliment (arrondie à 5 g).
  AlimentEstime _calibrer(AlimentEstime a, int i, Map<int, double> calibres) {
    final f = widget.preferences.facteurPour(a.nom);
    if (f == 1 || a.grammes <= 0) return a;
    calibres[i] = f;
    return a.avecGrammes(math.max(5, ((a.grammes * f) / 5).round() * 5.0));
  }

  /// Retient l'écart entre la portion estimée par l'IA et celle gardée.
  void _apprendre() {
    if (_viaCode) return;
    for (final i in _gardes) {
      if (i >= _ia.length || i >= _aliments.length) continue;
      unawaited(
        widget.preferences.apprendre(
          _ia[i].nom,
          estime: _ia[i].grammes,
          retenu: _aliments[i].grammes,
        ),
      );
    }
  }

  static double? _somme(
    List<AlimentEstime> l,
    double? Function(AlimentEstime) f,
  ) {
    final valeurs = [for (final a in l) f(a)].whereType<double>();
    return valeurs.isEmpty ? null : valeurs.fold<double>(0, (s, v) => s + v);
  }

  /// Change les aliments retenus ou leurs portions : la correction des tuiles
  /// est ramenée dans les bornes du nouveau total.
  void _changerBase(VoidCallback changement) => setState(() {
    changement();
    _ajustement = _ajustement.reborne(totalAliments(_retenus));
  });

  /// ±10 % de la portion, arrondi à 5 g (au moins 5 g d'écart).
  void _ajuster(int i, int sens) {
    final g = _aliments[i].grammes;
    final nouveau = portionSuivante(g, sens);
    if (nouveau == g) return;
    _changerBase(
      () => _aliments = [..._aliments]..[i] = _aliments[i].avecGrammes(nouveau),
    );
  }

  Future<void> _modifier(int i) async {
    final a = await showDialog<AlimentEstime>(
      context: context,
      builder: (_) => DialogueAliment(modele: _aliments[i]),
    );
    if (a != null && mounted) {
      _changerBase(() => _aliments = [..._aliments]..[i] = a);
    }
  }

  Future<void> _ajouter() async {
    if (_aliments.length >= maxAliments) {
      _signaler(AppLocalizations.of(context)!.tropDAliments(maxAliments));
      return;
    }
    final a = await showDialog<AlimentEstime>(
      context: context,
      builder: (_) => const DialogueAliment(),
    );
    if (a == null || !mounted || _aliments.length >= maxAliments) return;
    _changerBase(() {
      _aliments = [..._aliments, a];
      _gardes.add(_aliments.length - 1);
      _manuels.add(_aliments.length - 1);
    });
  }

  /// Total des aliments gardés, avec les corrections faites à la main.
  Macros get _total => _ajustement.appliquer(totalAliments(_retenus));

  /// Sucres et saturés des aliments retenus, mis à l'échelle des glucides et
  /// lipides corrigés à la main.
  ({double? sucres, double? satures}) _parts(List<AlimentEstime> retenus) {
    final base = totalAliments(retenus);
    final total = _ajustement.appliquer(base);
    return (
      sucres: partCorrigee(
        _somme(retenus, (a) => a.sucres),
        avant: base.glucides,
        apres: total.glucides,
      ),
      satures: partCorrigee(
        _somme(retenus, (a) => a.satures),
        avant: base.lipides,
        apres: total.lipides,
      ),
    );
  }

  Future<void> _valider() async {
    if (_enregistrement) return;
    setState(() => _enregistrement = true);
    final gardes = _retenus;
    final total = _total;
    final parts = _parts(gardes);
    // La photo reste sur le téléphone ; si elle ne peut pas être gardée, le
    // repas est enregistré quand même.
    final cibles = widget.cibles;
    final verdictFige = cibles == null || gardes.isEmpty
        ? null
        : verdictRepas(
            repas: total,
            sucres: parts.sucres,
            satures: parts.satures,
            dejaMange: widget.dejaMange,
            cibles: cibles,
            objectif: widget.objectif,
          );
    String? photoId;
    try {
      if (_image != null) photoId = await widget.photos.enregistrer(_image!);
    } catch (_) {}
    // Page déjà quittée pendant l'écriture (retour arrière) : la photo n'est
    // rattachée à aucun repas, elle n'est pas gardée.
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
      if (photoId != null) unawaited(widget.photos.supprimer(photoId));
      return;
    }
    _apprendre();
    Navigator.of(context).pop(
      Repas(
        date: widget.date,
        moment: _moment,
        nom: nomDuRepas(gardes),
        macros: total,
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
              errorBuilder: (_, _, _) => ColoredBox(
                color: context.palette.vertPale,
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
              Icon(
                icone,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
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
        if (_photoPossible) ...[
          Text(t.photoConseil, style: textes.bodyMedium),
          const SizedBox(height: 16),
          carte(
            Icons.photo_camera_outlined,
            t.prendrePhotoRepas,
            SourcePhoto.appareil,
          ),
          const SizedBox(height: 12),
          carte(
            Icons.photo_library_outlined,
            t.galerieChoix,
            SourcePhoto.galerie,
          ),
        ] else
          Text(t.sansAnalyse, style: textes.bodyMedium),
        const SizedBox(height: 12),
        carte(Icons.qr_code_scanner, t.scanTitre, null),
        const SizedBox(height: 8),
        TextButton(onPressed: _manuel, child: Text(t.saisirALaMain)),
        if (widget.recents case final recents?)
          FutureBuilder<List<Repas>>(
            future: recents,
            builder: (context, snap) {
              final liste = snap.data ?? const <Repas>[];
              if (liste.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ListeRepasRecents(repas: liste, onChoisir: _reprendre),
              );
            },
          ),
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
      ..._analysesRestantes(t),
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
              CauseAnalyse.tropGros => t.analyseTropGros,
              CauseAnalyse.indisponible => t.analyseIndisponible,
            },
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          // Renvoyer la même photo trop lourde ne servirait à rien.
          if (_cause != CauseAnalyse.quota && _cause != CauseAnalyse.tropGros)
            FilledButton(onPressed: _analyser, child: Text(t.reessayer)),
          if (_cause == CauseAnalyse.illisible ||
              _cause == CauseAnalyse.tropGros)
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
    final total = _total;
    final parts = _parts(retenus);
    // La fourchette suit la correction faite à la main sur les calories.
    final ecartKcal = total.kcal - totalAliments(retenus).kcal;

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
            repas: total,
            onAjuster: (champ, sens) => setState(
              () => _ajustement = _ajustement.avec(
                champ,
                sens,
                totalAliments(retenus),
              ),
            ),
            sucres: parts.sucres,
            satures: parts.satures,
            verdict: verdictRepas(
              repas: total,
              sucres: parts.sucres,
              satures: parts.satures,
              dejaMange: widget.dejaMange,
              cibles: cibles,
              objectif: widget.objectif,
            ),
          ),
        if (_image != null &&
            (_aliments.isEmpty || _aliments.any((a) => a.aVerifier))) ...[
          const SizedBox(height: 12),
          CartePrecision(controleur: _precision, onReanalyser: _analyser),
        ],
        if (_image != null) ..._analysesRestantes(t),
        if (fourchetteKcal(retenus) case final f?) ...[
          const SizedBox(height: 8),
          Text(
            t.fourchetteKcal(
              math.max(0, (f.min + ecartKcal).round()),
              math.max(0, (f.max + ecartKcal).round()),
            ),
            style: textes.titleSmall,
          ),
        ],
        if (_aliments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            t.estimationAVerifier,
            style: textes.bodySmall?.copyWith(color: context.palette.texteDoux),
          ),
        ],
        for (var i = 0; i < _aliments.length; i++) _ligne(t, i),
        if (_aliments.isNotEmpty && !_viaCode) _carteGras(t),
        OutlinedButton.icon(
          onPressed: _aliments.length >= maxAliments ? null : _ajouter,
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
          onPressed: _gardes.isEmpty || _enregistrement ? null : _valider,
          child: _enregistrement
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.enregistrer),
        ),
        TextButton(onPressed: _manuel, child: Text(t.saisirALaMain)),
      ],
    );
  }

  /// Huile et sauce peu visibles : l'erreur la plus fréquente sur les calories.
  Widget _carteGras(AppLocalizations t) {
    final textes = Theme.of(context).textTheme;
    Widget ligne(
      String libelle,
      QuantiteGras valeur,
      void Function(QuantiteGras) choisir,
    ) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 120, child: Text(libelle, style: textes.bodyMedium)),
          for (final (q, nom) in [
            (QuantiteGras.aucune, t.grasAucune),
            (QuantiteGras.unPeu, t.grasUnPeu),
            (QuantiteGras.beaucoup, t.grasBeaucoup),
          ])
            ChoiceChip(
              label: Text(nom),
              selected: valeur == q,
              onSelected: (_) => _changerBase(() => choisir(q)),
            ),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.grasTitre, style: textes.titleSmall),
            Text(
              t.grasAide,
              style: textes.bodySmall?.copyWith(
                color: context.palette.texteDoux,
              ),
            ),
            ligne(t.grasHuile, _huile, (q) => _huile = q),
            ligne(t.grasSauce, _sauce, (q) => _sauce = q),
          ],
        ),
      ),
    );
  }

  /// Le nombre d'analyses photo restantes du jour, si le relais l'a donné.
  List<Widget> _analysesRestantes(AppLocalizations t) => [
    if (_restantes case final n?) ...[
      const SizedBox(height: 8),
      Text(
        t.analysesRestantes(n),
        key: const ValueKey('analyses-restantes'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: context.palette.texteDoux),
      ),
    ],
  ];

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
              semanticLabel: a.nom,
              onChanged: (v) => _changerBase(
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
                      t.portionGrammes(
                        a.grammes.round(),
                        a.macros.kcal.round(),
                      ),
                      style: textes.bodySmall,
                    ),
                    if (a.aFourchette)
                      Text(
                        t.fourchetteGrammes(
                          a.grammesMin!.round(),
                          a.grammesMax!.round(),
                        ),
                        style: textes.labelSmall?.copyWith(
                          color: context.palette.texteDoux,
                        ),
                      ),
                    if (_calibres[i] case final f?)
                      Text(
                        t.ajusteHabitudes(
                          '${f > 1 ? '+' : '−'}${((f - 1).abs() * 100).round()} %',
                        ),
                        style: textes.labelSmall?.copyWith(
                          color: context.palette.texteDoux,
                        ),
                      ),
                    if (a.reference case final ref?)
                      Text(
                        t.valeursCiqual(ref),
                        style: textes.labelSmall?.copyWith(
                          color: context.palette.texteDoux,
                        ),
                      ),
                    if (a.aVerifier)
                      Text(
                        t.aVerifier,
                        style: textes.labelSmall?.copyWith(
                          color: context.palette.orangeFonce,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: t.ajusterMoins(a.nom),
              onPressed: () => _ajuster(i, -1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              tooltip: t.ajusterPlus(a.nom),
              onPressed: () => _ajuster(i, 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
