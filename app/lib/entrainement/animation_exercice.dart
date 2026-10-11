import 'dart:async';

import 'package:flutter/material.dart';

/// Exercices pour lesquels on a deux photos (début et fin du mouvement) dans
/// assets/exercices/ : {id}_0.jpg et {id}_1.jpg. Photos du jeu libre de droits
/// « free-exercise-db » (licence Unlicense, domaine public).
const exercicesAnimes = {
  'squat',
  'squat_halteres',
  'presse_cuisses',
  'fentes',
  'fentes_halteres',
  'pont_fessier',
  'souleve_terre_halteres',
  'swing_kettlebell',
  'pompes_genoux',
  'pompes',
  'developpe_halteres',
  'developpe_couche',
  'dips_chaise',
  'superman',
  'tirage_elastique',
  'rowing_halteres',
  'tractions',
  'tirage_vertical',
  'planche',
  'gainage_lateral',
  'crunch',
  'dead_bug',
  'corde',
  'montees_genoux',
};

/// Montre le mouvement d'un exercice : les deux positions se fondent l'une
/// dans l'autre en boucle. Ne dessine rien si on n'a pas de photos.
class AnimationExercice extends StatefulWidget {
  const AnimationExercice({
    super.key,
    required this.exerciceId,
    this.hauteur,
    this.arrondi = 16,
  });

  final String exerciceId;

  /// Hauteur imposée ; sinon les photos gardent leur rapport 3:2.
  final double? hauteur;
  final double arrondi;

  @override
  State<AnimationExercice> createState() => _AnimationExerciceState();
}

class _AnimationExerciceState extends State<AnimationExercice> {
  Timer? _minuteur;
  bool _fin = false;

  bool get _disponible => exercicesAnimes.contains(widget.exerciceId);

  @override
  void initState() {
    super.initState();
    if (_disponible) {
      _minuteur = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (mounted) setState(() => _fin = !_fin);
      });
    }
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Widget _image(int i) => Image.asset(
    'assets/exercices/${widget.exerciceId}_$i.jpg',
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) =>
        const ColoredBox(color: Color(0xFFE1F5EE), child: SizedBox.expand()),
  );

  @override
  Widget build(BuildContext context) {
    if (!_disponible) return const SizedBox.shrink();
    final contenu = ClipRRect(
      borderRadius: BorderRadius.circular(widget.arrondi),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 600),
        sizeCurve: Curves.linear,
        crossFadeState: _fin
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        layoutBuilder: (haut, cleHaut, bas, cleBas) => Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(key: cleBas, child: bas),
            Positioned.fill(key: cleHaut, child: haut),
          ],
        ),
        firstChild: _image(0),
        secondChild: _image(1),
      ),
    );
    return Semantics(
      image: true,
      label: 'Démonstration de l\'exercice',
      child: widget.hauteur != null
          ? SizedBox(height: widget.hauteur, child: contenu)
          : AspectRatio(aspectRatio: 3 / 2, child: contenu),
    );
  }
}
