import 'dart:async';

import 'package:flutter/material.dart';

import '../compte/auth_service.dart';
import '../journal/formulaires.dart';
import '../journal/modele.dart';
import '../l10n/app_localizations.dart';
import '../profil/modele.dart';
import '../theme.dart';
import 'avis.dart';
import 'avis_repository.dart';
import 'modele.dart';
import 'planning.dart';
import 'recette_page.dart';
import '../route_verre.dart';

/// Idées de repas à balayer : à droite « j'aime, pour plus tard », à gauche
/// « je n'aime pas » (la recette ne revient presque plus). Toucher la carte
/// ouvre la recette complète.
class IdeesPage extends StatefulWidget {
  const IdeesPage({
    super.key,
    required this.utilisateur,
    required this.objectif,
    required this.kcalCible,
    required this.avis,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final Objectif objectif;
  final int kcalCible;
  final AvisRepository avis;
  final DateTime Function() horloge;

  @override
  State<IdeesPage> createState() => _IdeesPageState();
}

class _IdeesPageState extends State<IdeesPage> {
  String get _uid => widget.utilisateur.uid;
  late final Stream<Map<String, Avis>> _flux = widget.avis.avis(_uid);

  Moment? _moment;
  int _melange = 0;
  List<Recette>? _deck;
  int _i = 0;
  Map<String, Avis> _avis = const {};

  int get _graine =>
      widget.horloge().difference(DateTime(2024)).inDays * 31 + _melange;

  void _reconstruire() {
    _deck = construireDeck(
      avis: _avis,
      objectif: widget.objectif,
      graine: _graine,
      moment: _moment,
    );
    _i = 0;
  }

  void _donnerAvis(Recette r, Avis avis) {
    unawaited(widget.avis.noter(_uid, r.id, avis));
    setState(() {
      _avis = {..._avis, r.id: avis};
      _i++;
    });
  }

  Future<void> _ouvrir(Recette r) => Navigator.of(context).push<void>(
    routeVerre(
      (_) => RecettePage(recette: r, portions: _portions(r), actions: false),
    ),
  );

  double _portions(Recette r) =>
      portionsPour(r, widget.kcalCible * (partsDuJour[r.moment] ?? 0.3));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.ideesTitre),
        actions: [
          IconButton(
            tooltip: t.mesEnvies,
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.of(context).push<void>(
              routeVerre(
                (_) => EnviesPage(
                  uid: _uid,
                  avis: widget.avis,
                  portions: _portions,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, Avis>>(
        stream: _flux,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_deck == null) {
            _avis = snap.data!;
            _reconstruire();
          }
          final deck = _deck!;
          final fini = _i >= deck.length;
          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final m in <Moment?>[null, ...Moment.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            m == null ? t.tousLesRepas : libelleMoment(t, m),
                          ),
                          selected: _moment == m,
                          onSelected: (_) => setState(() {
                            _moment = m;
                            _melange++;
                            _reconstruire();
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: fini
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.restaurant_menu,
                                size: 56,
                                color: CouleursCoach.vertMoyen,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                t.ideesTerminees,
                                textAlign: TextAlign.center,
                                style: textes.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => Navigator.of(context)
                                    .push<void>(
                                      routeVerre(
                                        (_) => EnviesPage(
                                          uid: _uid,
                                          avis: widget.avis,
                                          portions: _portions,
                                        ),
                                      ),
                                    ),
                                child: Text(t.mesEnvies),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Stack(
                          children: [
                            if (_i + 1 < deck.length)
                              Positioned.fill(
                                child: Transform.scale(
                                  scale: 0.94,
                                  child: _CarteIdee(
                                    recette: deck[_i + 1],
                                    portions: _portions(deck[_i + 1]),
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: _Balayable(
                                key: ValueKey(deck[_i].id),
                                onAvis: (a) => _donnerAvis(deck[_i], a),
                                onTap: () => _ouvrir(deck[_i]),
                                carte: _CarteIdee(
                                  recette: deck[_i],
                                  portions: _portions(deck[_i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (!fini)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        tooltip: t.jeNaimePas,
                        iconSize: 32,
                        color: const Color(0xFFE24B4A),
                        onPressed: () => _bouton(false),
                        icon: const Icon(Icons.close),
                      ),
                      const SizedBox(width: 32),
                      IconButton.filledTonal(
                        tooltip: t.jAimePlusTard,
                        iconSize: 32,
                        color: CouleursCoach.vertMoyen,
                        onPressed: () => _bouton(true),
                        icon: const Icon(Icons.favorite),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    t.photosIllustratives,
                    style: textes.labelSmall?.copyWith(
                      color: context.palette.texteDoux,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _bouton(bool aime) {
    final etat = _balayableCourant;
    etat?.lancer(aime ? Avis.aime : Avis.refuse);
  }

  _BalayableState? get _balayableCourant => _BalayableState.courant;
}

/// Carte déplaçable au doigt. Prévient quand elle est lâchée assez loin.
class _Balayable extends StatefulWidget {
  const _Balayable({
    super.key,
    required this.carte,
    required this.onAvis,
    required this.onTap,
  });

  final Widget carte;
  final ValueChanged<Avis> onAvis;
  final VoidCallback onTap;

  @override
  State<_Balayable> createState() => _BalayableState();
}

class _BalayableState extends State<_Balayable>
    with SingleTickerProviderStateMixin {
  /// La carte du dessus, pour les boutons « non » et « j'aime ».
  static _BalayableState? courant;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  double _dx = 0;
  double _debut = 0;
  double _largeur = 360;
  bool _parti = false;

  @override
  void initState() {
    super.initState();
    courant = this;
    _anim.addListener(
      () => setState(
        () => _dx =
            _debut + (_cible - _debut) * Curves.easeOut.transform(_anim.value),
      ),
    );
  }

  double _cible = 0;

  @override
  void dispose() {
    if (courant == this) courant = null;
    _anim.dispose();
    super.dispose();
  }

  void _animerVers(double cible, {VoidCallback? fin}) {
    _debut = _dx;
    _cible = cible;
    _anim.forward(from: 0).whenComplete(() => fin?.call());
  }

  void lancer(Avis avis) {
    if (_parti) return;
    _parti = true;
    _animerVers(
      avis == Avis.aime ? _largeur * 1.4 : -_largeur * 1.4,
      fin: () => widget.onAvis(avis),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      _largeur = c.maxWidth;
      final progres = (_dx / (_largeur * 0.4)).clamp(-1.0, 1.0);
      return GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (d) {
          if (!_parti) setState(() => _dx += d.delta.dx);
        },
        onPanEnd: (d) {
          if (_parti) return;
          final v = d.velocity.pixelsPerSecond.dx;
          if (_dx > _largeur * 0.3 || v > 800) {
            lancer(Avis.aime);
          } else if (_dx < -_largeur * 0.3 || v < -800) {
            lancer(Avis.refuse);
          } else {
            _animerVers(0);
          }
        },
        child: Transform.translate(
          offset: Offset(_dx, 0),
          child: Transform.rotate(
            angle: _dx / _largeur * 0.25,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.carte,
                if (progres.abs() > 0.05)
                  Positioned(
                    top: 24,
                    left: progres > 0 ? 24 : null,
                    right: progres < 0 ? 24 : null,
                    child: Opacity(
                      opacity: progres.abs(),
                      child: _Etiquette(aime: progres > 0),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Etiquette extends StatelessWidget {
  const _Etiquette({required this.aime});

  final bool aime;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final couleur = aime ? CouleursCoach.vertMoyen : const Color(0xFFE24B4A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: couleur, width: 3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        aime ? t.etiquetteEnvie : t.etiquetteNon,
        style: TextStyle(
          color: couleur,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Photo, titre et repères d'une recette.
class _CarteIdee extends StatelessWidget {
  const _CarteIdee({required this.recette, required this.portions});

  final Recette recette;
  final double portions;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final kcal = (recette.macros.kcal * portions).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayonCarte),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/recettes/${recette.id}.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: context.palette.vertPale,
              child: Center(child: Icon(Icons.restaurant, size: 64)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recette.nom,
                    style: textes.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t.minutesValeur(recette.minutes)} · '
                    '${t.pourToiKcal(kcal)}'
                    '${recette.vegetarien ? ' · ${t.vegetarienCourt}' : ''}',
                    style: textes.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Les recettes aimées, gardées « pour une prochaine fois ».
class EnviesPage extends StatelessWidget {
  const EnviesPage({
    super.key,
    required this.uid,
    required this.avis,
    required this.portions,
  });

  final String uid;
  final AvisRepository avis;
  final double Function(Recette) portions;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.mesEnvies)),
      body: StreamBuilder<Map<String, Avis>>(
        stream: avis.avis(uid),
        builder: (context, snap) {
          final liste = recettesAimees(snap.data ?? const {});
          if (liste.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.aucuneEnvie, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            children: [
              for (final r in liste)
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Image.asset(
                        'assets/recettes/${r.id}.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: context.palette.vertPale,
                          child: Icon(Icons.restaurant),
                        ),
                      ),
                    ),
                  ),
                  title: Text(r.nom),
                  subtitle: Text(
                    '${libelleMoment(t, r.moment)} · '
                    '${t.minutesValeur(r.minutes)}',
                  ),
                  trailing: IconButton(
                    tooltip: t.retirerEnvie,
                    icon: const Icon(Icons.favorite),
                    color: CouleursCoach.vertMoyen,
                    onPressed: () => unawaited(avis.noter(uid, r.id, null)),
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    routeVerre(
                      (_) => RecettePage(
                        recette: r,
                        portions: portions(r),
                        actions: false,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
