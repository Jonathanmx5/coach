import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bienetre/bienetre_repository.dart';
import '../bienetre/hydratation.dart';
import '../bienetre/suivi_meteo.dart';
import '../format.dart';
import '../journal/calculs.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import '../l10n/app_localizations.dart';
import '../profil/modele.dart';
import '../sante/modele.dart';
import '../sante/sources.dart';
import '../sante/suivi.dart';
import '../theme.dart';
import '../widget/donnees_widget.dart';
import '../widget/synchro_widget.dart';

/// Couleurs des anneaux, celles de l'application, sur un fond vert très clair :
/// vert pour le sport (vert profond pour les calories brûlées, vert moyen pour
/// les protéines, qui font le muscle), orange pour l'assiette, bleu pour l'eau.
const _cBrule = CouleursCoach.vert;

/// Le vert profond des calories brûlées serait presque invisible sur fond
/// sombre : on prend un vert plus clair.
const _cBruleSombre = Color(0xFF6FD9B0);
const _cMange = CouleursCoach.orange;
const _cProteines = CouleursCoach.vertMoyen;
const _cEau = CouleursCoach.bleu;

/// Quatre anneaux concentriques : de l'extérieur vers l'intérieur, calories
/// brûlées, calories mangées, protéines, eau. Chaque valeur va de 0 à 1 ;
/// au-delà de 1 l'anneau reste fermé.
class Anneaux extends StatelessWidget {
  const Anneaux({
    super.key,
    required this.progres,
    this.taille = 230,
    this.centre,
    this.semantique,
    this.animer = true,
  });

  /// Dans l'ordre : brûlées, mangées, protéines, eau.
  final List<double> progres;
  final double taille;

  /// Affiché au milieu des anneaux.
  final Widget? centre;

  /// Faux pour dessiner d'un coup (image du widget de l'écran d'accueil).
  final bool animer;

  /// Description lue par le lecteur d'écran (les anneaux sont un dessin).
  final String? semantique;

  static List<Color> couleursPour(Brightness luminosite) => [
    luminosite == Brightness.dark ? _cBruleSombre : _cBrule,
    _cMange,
    _cProteines,
    _cEau,
  ];

  @override
  Widget build(BuildContext context) => Semantics(
    label: semantique,
    image: true,
    excludeSemantics: semantique != null,
    child: SizedBox.square(
      dimension: taille,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: animer
                ? const Duration(milliseconds: 900)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              size: Size.square(taille),
              painter: _AnneauxPainter([
                for (final p in progres) p.clamp(0.0, 1.0) * t,
              ], couleursPour(Theme.of(context).brightness)),
            ),
          ),
          ?centre,
        ],
      ),
    ),
  );
}

class _AnneauxPainter extends CustomPainter {
  _AnneauxPainter(this.valeurs, this.couleurs);

  final List<double> valeurs;
  final List<Color> couleurs;

  @override
  void paint(Canvas canvas, Size size) {
    const epaisseur = 16.0;
    const ecart = 3.0;
    final centre = size.center(Offset.zero);
    for (var i = 0; i < valeurs.length; i++) {
      final rayon = size.width / 2 - epaisseur / 2 - i * (epaisseur + ecart);
      final rect = Rect.fromCircle(center: centre, radius: rayon);
      final piste = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..color = couleurs[i].withValues(alpha: 0.22);
      canvas.drawCircle(centre, rayon, piste);
      if (valeurs[i] <= 0) continue;
      final trait = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..strokeCap = StrokeCap.round
        ..color = couleurs[i];
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * valeurs[i],
        false,
        trait,
      );
    }
  }

  @override
  bool shouldRepaint(_AnneauxPainter ancien) =>
      !listEquals(ancien.valeurs, valeurs);
}

/// « Aujourd'hui » à la Apple : anneaux et quatre lignes de chiffres.
class CarteAujourdhui extends StatefulWidget {
  const CarteAujourdhui({
    super.key,
    required this.uid,
    required this.profil,
    required this.suivi,
    required this.journal,
    required this.bienetre,
    required this.meteoSuivi,
    required this.horloge,
    required this.onOnglet,
    this.majWidget,
    this.delaiWidget = const Duration(seconds: 3),
  });

  final String uid;
  final Profil profil;
  final Suivi suivi;
  final JournalRepository journal;
  final BienEtreRepository bienetre;
  final SuiviMeteo meteoSuivi;
  final DateTime Function() horloge;

  /// Ouvre un onglet de la barre du bas (1 Repas, 2 Sport, 3 Poids, 4 Bien-être).
  final ValueChanged<int> onOnglet;

  /// Widget de l'écran d'accueil à tenir à jour avec ces chiffres.
  final MiseAJourWidget? majWidget;

  /// Attente avant d'envoyer des chiffres changés au widget de l'écran
  /// d'accueil (tout de suite si l'appli passe en arrière-plan).
  final Duration delaiWidget;

  @override
  State<CarteAujourdhui> createState() => _CarteAujourdhuiState();
}

/// Ce qu'affiche la carte, calculé de la même façon pour l'écran et pour le
/// widget de l'écran d'accueil.
class _Chiffres {
  _Chiffres({
    required this.bilan,
    required this.jourSante,
    required this.objectifEau,
    required this.bu,
  });

  final BilanJour bilan;
  final JourSante? jourSante;
  final int objectifEau;
  final int bu;

  double get brulees => bilan.brulees;
  double get objectifBrule => bilan.reperes.maintien.toDouble();

  /// Mangé moins brûlé jusqu'à maintenant, au centre des anneaux.
  double get net => bilan.mangees - bilan.brulees;

  static double _part(double v, double objectif) =>
      objectif <= 0 ? 0 : v / objectif;

  List<double> get progres => [
    _part(brulees, objectifBrule),
    _part(bilan.mangees, bilan.cibles.kcal),
    _part(bilan.macros.proteines, bilan.cibles.proteines),
    _part(bu.toDouble(), objectifEau.toDouble()),
  ];
}

class _CarteAujourdhuiState extends State<CarteAujourdhui>
    with WidgetsBindingObserver {
  /// Le jour affiché : suit le jour réel (minuit passé, appli reprise).
  late DateTime _jour;

  /// Null tant que le flux n'a rien donné.
  List<Repas>? _repas;
  List<Activite>? _activites;
  List<EntreeEau>? _eau;
  final _abonnements = <StreamSubscription<Object?>>[];

  SynchroWidget? _synchro;
  AppLocalizations? _t;

  static DateTime _jourDe(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _jour = _jourDe(widget.horloge());
    _ecouter();
    widget.suivi.addListener(_auChangement);
    widget.meteoSuivi.addListener(_auChangement);
    WidgetsBinding.instance.addObserver(this);
    _synchro = _nouvelleSynchro();
  }

  SynchroWidget? _nouvelleSynchro() {
    final maj = widget.majWidget;
    return maj == null ? null : SynchroWidget(maj, delai: widget.delaiWidget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppLocalizations.of(context);
    _synchroniser();
  }

  @override
  void didUpdateWidget(CarteAujourdhui ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.suivi != widget.suivi) {
      ancien.suivi.removeListener(_auChangement);
      widget.suivi.addListener(_auChangement);
    }
    if (ancien.meteoSuivi != widget.meteoSuivi) {
      ancien.meteoSuivi.removeListener(_auChangement);
      widget.meteoSuivi.addListener(_auChangement);
    }
    if (ancien.majWidget != widget.majWidget) {
      _synchro?.fermer();
      _synchro = _nouvelleSynchro();
    }
    final jour = _jourDe(widget.horloge());
    if (ancien.uid != widget.uid ||
        ancien.journal != widget.journal ||
        ancien.bienetre != widget.bienetre ||
        jour != _jour) {
      _jour = jour;
      _ecouter();
    }
    _synchroniser();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _suivreLeJour();
  }

  @override
  void dispose() {
    for (final a in _abonnements) {
      unawaited(a.cancel());
    }
    widget.suivi.removeListener(_auChangement);
    widget.meteoSuivi.removeListener(_auChangement);
    WidgetsBinding.instance.removeObserver(this);
    _synchro?.fermer();
    super.dispose();
  }

  /// (Ré)ouvre les flux du jour affiché.
  void _ecouter() {
    for (final a in _abonnements) {
      unawaited(a.cancel());
    }
    _abonnements.clear();
    _repas = null;
    _activites = null;
    _eau = null;
    final demain = DateTime(_jour.year, _jour.month, _jour.day + 1);
    void recu(VoidCallback garder) {
      if (!mounted) return;
      setState(garder);
      _synchroniser();
    }

    _abonnements.addAll([
      widget.journal
          .repas(widget.uid, _jour, demain)
          .listen((v) => recu(() => _repas = v), onError: (Object _) {}),
      widget.journal
          .activites(widget.uid, _jour, demain)
          .listen((v) => recu(() => _activites = v), onError: (Object _) {}),
      widget.bienetre
          .eau(widget.uid, _jour, demain)
          .listen((v) => recu(() => _eau = v), onError: (Object _) {}),
    ]);
  }

  /// Minuit passé : la carte passe au nouveau jour.
  void _suivreLeJour() {
    final jour = _jourDe(widget.horloge());
    if (jour == _jour || !mounted) return;
    setState(() {
      _jour = jour;
      _ecouter();
    });
  }

  void _auChangement() {
    if (!mounted) return;
    setState(() {});
    _suivreLeJour();
    _synchroniser();
  }

  /// Le bilan commun à l'Accueil, au Journal et au widget (calculs.dart).
  _Chiffres _calculer() {
    final activites = _activites ?? const <Activite>[];
    final bilan = bilanDuJour(
      profil: widget.profil,
      jours: widget.suivi.jours,
      maintienMesure: widget.suivi.maintienPour(widget.profil),
      repas: _repas ?? const [],
      activites: activites,
      jour: _jour,
      maintenant: widget.horloge(),
    );
    return _Chiffres(
      bilan: bilan,
      jourSante: widget.suivi.jours.where((j) => j.jour == _jour).firstOrNull,
      objectifEau: objectifEauMl(
        poidsKg: widget.profil.poidsKg,
        minutesEffort: activites.fold<int>(0, (s, a) => s + a.minutes),
        tempMaxC: widget.meteoSuivi.temperature,
      ),
      bu: totalEauMl(_eau ?? const []),
    );
  }

  /// Propose les chiffres au widget de l'écran d'accueil, une fois toutes les
  /// données arrivées (pas des zéros de chargement). Jamais depuis build :
  /// [SynchroWidget] décide quand écrire.
  void _synchroniser() {
    final synchro = _synchro;
    final t = _t;
    if (synchro == null || t == null || !mounted) return;
    if (_repas == null || _activites == null || _eau == null) return;
    final c = _calculer();
    final b = c.bilan;
    synchro.proposer(
      DonneesWidget(
        brulees: c.brulees,
        objectifBrule: c.objectifBrule,
        mangees: b.mangees,
        objectifMange: b.cibles.kcal,
        proteines: b.macros.proteines,
        objectifProteines: b.cibles.proteines,
        eauMl: c.bu,
        objectifEauMl: c.objectifEau,
        description: t.widgetAnneauxSemantique(
          c.brulees.round(),
          c.objectifBrule.round(),
          b.mangees.round(),
          b.cibles.kcal.round(),
          b.macros.proteines.round(),
          b.cibles.proteines.round(),
          bilanTexte(c.net),
        ),
      ),
      // Datés du jour de la carte, pas de l'heure de l'envoi : envoyés après
      // minuit, ils ne sont pas attribués au lendemain.
      jour: _jour,
      uid: widget.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final p = context.palette;
    final c = _calculer();
    final b = c.bilan;
    final jourSante = c.jourSante;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: p.verre,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.verreBord),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F2A24),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              t.anneauxTitre,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: p.texte, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Anneaux(
            semantique: t.anneauxSemantique(
              c.brulees.round(),
              c.objectifBrule.round(),
              b.mangees.round(),
              b.cibles.kcal.round(),
              b.macros.proteines.round(),
              b.cibles.proteines.round(),
              c.bu,
              c.objectifEau,
              bilanTexte(c.net),
            ),
            centre: _Bilan(net: c.net),
            progres: c.progres,
          ),
          const SizedBox(height: 12),
          _Ligne(
            couleur: Anneaux.couleursPour(Theme.of(context).brightness).first,
            couleurTexte: p.texteVert,
            libelle: t.libBrule,
            sous: b.estime
                ? t.sourceEstimeJusqua
                : (jourSante?.sourceKcal == null ||
                          nomDeSource(jourSante!.sourceKcal).isEmpty
                      ? t.sourceMesure
                      : t.sourceMesureDe(
                          nomDeSource(jourSante.sourceKcal),
                          jourSante.derniereMesureKcal == null
                              ? ''
                              : DateFormat('HH:mm')
                                    .format(jourSante.derniereMesureKcal!),
                        )),
            valeur: '${c.brulees.round()}',
            objectif: '${c.objectifBrule.round()}',
            unite: 'kcal',
            onTap: () => widget.onOnglet(2),
          ),
          _Ligne(
            couleur: _cMange,
            couleurTexte: p.texteOrange,
            libelle: t.libMange,
            sous: t.objectifDuJour,
            valeur: '${b.mangees.round()}',
            objectif: '${b.cibles.kcal.round()}',
            unite: 'kcal',
            onTap: () => widget.onOnglet(1),
          ),
          _Ligne(
            couleur: _cProteines,
            couleurTexte: p.texteVert,
            libelle: t.libProteines,
            sous: t.objectifDuJour,
            valeur: '${b.macros.proteines.round()}',
            objectif: '${b.cibles.proteines.round()}',
            unite: 'g',
            onTap: () => widget.onOnglet(1),
          ),
          _Ligne(
            couleur: _cEau,
            couleurTexte: p.texteBleu,
            libelle: t.libEau,
            sous: widget.meteoSuivi.temperature == null
                ? t.objectifDuJour
                : t.eauChaleur(widget.meteoSuivi.temperature!.round()),
            valeur: formatLitres(c.bu),
            objectif: formatLitres(c.objectifEau),
            unite: 'L',
            onTap: () => widget.onOnglet(4),
          ),
        ],
      ),
    );
  }
}

/// Calories mangées moins calories brûlées : négatif = déficit.
String bilanTexte(double net) {
  final n = net.round();
  if (n == 0) return '0';
  return n > 0 ? '+$n' : '\u2212${-n}';
}

class _Bilan extends StatelessWidget {
  const _Bilan({required this.net});

  final double net;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          bilanTexte(net),
          style: textes.titleLarge?.copyWith(
            color: context.palette.texte,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          t.bilanCentre,
          style: textes.labelSmall?.copyWith(color: context.palette.texteDoux),
        ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.couleur,
    required this.couleurTexte,
    required this.libelle,
    required this.sous,
    required this.valeur,
    required this.objectif,
    required this.unite,
    required this.onTap,
  });

  /// Couleur vive de la barre, celle de l'anneau.
  final Color couleur;

  /// Couleur du chiffre : la même teinte, lisible sur le verre.
  final Color couleurTexte;
  final String libelle;
  final String sous;
  final String valeur;
  final String objectif;
  final String unite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: BoxDecoration(
                color: couleur,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libelle,
                    style: textes.titleSmall?.copyWith(
                      color: context.palette.texte,
                    ),
                  ),
                  Text(
                    sous,
                    style: textes.bodySmall?.copyWith(
                      color: context.palette.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
            // Flexible : avec une police agrandie, la valeur passe à la ligne
            // au lieu de déborder.
            Flexible(
              flex: 2,
              child: Text.rich(
                textAlign: TextAlign.end,
                TextSpan(
                  children: [
                    TextSpan(
                      text: valeur,
                      style: textes.headlineSmall?.copyWith(
                        color: couleurTexte,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' / $objectif $unite',
                      style: textes.bodyMedium?.copyWith(
                        color: context.palette.texteDoux,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
