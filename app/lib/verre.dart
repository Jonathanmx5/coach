import 'package:flutter/material.dart';

import 'theme.dart';

/// Opacité maximale d'une tache de couleur du fond (au centre de la tache).
/// Les tests de contraste partent de cette valeur, la pire pour la lisibilité.
double alphaTache(Color couleur, {required bool sombre}) {
  if (couleur == CouleursCoach.orange) return sombre ? 0.30 : 0.46;
  if (couleur == CouleursCoach.bleu) return sombre ? 0.38 : 0.42;
  return sombre ? 0.42 : 0.55;
}

/// Fond ambiant du « verre givré » : la couleur de fond du thème, avec de
/// grandes taches douces de vert, d'orange et de bleu (les couleurs de la
/// marque) qui se devinent à travers les cartes.
class FondVerre extends StatelessWidget {
  const FondVerre({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.fond,
        // En clair, un dégradé vert d'eau vers bleu givre, pour ne pas être un aplat blanc.
        gradient: sombre
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFBFDDCF),
                  Color(0xFFCCDDEA),
                  Color(0xFFDDD8CB),
                ],
              ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Tache(
                    couleur: CouleursCoach.vertVif,
                    alpha: alphaTache(CouleursCoach.vertVif, sombre: sombre),
                    place: const Alignment(-1.1, -0.75),
                    largeur: 1.05,
                  ),
                  _Tache(
                    couleur: CouleursCoach.orange,
                    alpha: alphaTache(CouleursCoach.orange, sombre: sombre),
                    place: const Alignment(1.2, 0.3),
                    largeur: 0.9,
                  ),
                  _Tache(
                    couleur: CouleursCoach.bleu,
                    alpha: alphaTache(CouleursCoach.bleu, sombre: sombre),
                    place: const Alignment(-0.9, 1.0),
                    largeur: 0.95,
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Tache extends StatelessWidget {
  const _Tache({
    required this.couleur,
    required this.alpha,
    required this.place,
    required this.largeur,
  });

  final Color couleur;
  final double alpha;
  final Alignment place;
  final double largeur;

  @override
  Widget build(BuildContext context) => Align(
    alignment: place,
    child: FractionallySizedBox(
      widthFactor: largeur,
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                couleur.withValues(alpha: alpha),
                couleur.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Plaque de verre : un voile translucide, un bord qui capte la lumière et un
/// reflet diagonal. Sans flou d'arrière-plan : le Scaffold des onglets ne
/// passe jamais sous la barre, le flou ne traiterait que les taches déjà
/// douces du fond, pour un effet invisible payé à chaque image.
class VerreFlou extends StatelessWidget {
  const VerreFlou({super.key, required this.child, this.rayon = 32});

  final Widget child;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final forme = BorderRadius.circular(rayon);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: forme,
        boxShadow: const [
          BoxShadow(
            color: Color(0x290F2A24),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: forme,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.verre,
            borderRadius: forme,
            border: Border.all(color: p.verreBord),
          ),
          position: DecorationPosition.background,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: forme,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.30),
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.10),
                ],
                stops: const [0, 0.36, 0.64, 1],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Largeur à partir de laquelle l'appli passe en mise en page de tablette.
const largeurTablette = 840.0;

/// Largeur maximale du contenu : au-delà, les listes pensées pour un
/// téléphone s'étirent trop.
const largeurContenuMax = 880.0;

/// Vrai sur une tablette ou un téléphone tenu à plat.
bool largeEcran(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= largeurTablette;

/// Centre le contenu et limite sa largeur sur grand écran ; sur téléphone,
/// il occupe toute la largeur comme avant.
class ColonneCentree extends StatelessWidget {
  const ColonneCentree({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth <= largeurContenuMax
        ? child
        : Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: largeurContenuMax,
              height: c.hasBoundedHeight ? c.maxHeight : null,
              child: child,
            ),
          ),
  );
}
