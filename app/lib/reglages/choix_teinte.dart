import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Couleurs montrées dans l'aperçu d'une teinte : on ne peut pas lire
/// [CouleursCoach], qui suit la teinte active, pour montrer l'autre.
({Color principale, Color repas, List<Color> fond}) _couleursApercu(Teinte t) =>
    switch (t) {
      Teinte.foret => (
        principale: const Color(0xFF0F6E56),
        repas: const Color(0xFFEF9F27),
        fond: const [Color(0xFFBFDDCF), Color(0xFFCCDDEA), Color(0xFFDDD8CB)],
      ),
      Teinte.aurore => (
        principale: const Color(0xFF6A3FB5),
        repas: const Color(0xFFF287B8),
        fond: const [Color(0xFFD8C8EC), Color(0xFFCFD3F0), Color(0xFFEDD3E2)],
      ),
    };

String nomTeinte(AppLocalizations t, Teinte teinte) => switch (teinte) {
  Teinte.foret => t.teinteForet,
  Teinte.aurore => t.teinteAurore,
};

/// Petite maquette de l'écran d'accueil dans une teinte : fond, anneaux et
/// bouton. Touchable pour la choisir.
class ApercuTeinte extends StatelessWidget {
  const ApercuTeinte({
    super.key,
    required this.teinte,
    required this.choisie,
    required this.onTap,
  });

  final Teinte teinte;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = _couleursApercu(teinte);
    final t = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      selected: choisie,
      label: nomTeinte(t, teinte),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: choisie ? c.principale : Colors.transparent,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 0.62,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: c.fond,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _barre(Colors.black.withValues(alpha: 0.55), 0.6),
                          const SizedBox(height: 10),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: FractionallySizedBox(
                                  widthFactor: 0.7,
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: CustomPaint(
                                      painter: _Anneaux([
                                        c.principale,
                                        c.repas,
                                        CouleursCoach.bleu,
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _barre(c.repas, 0.8),
                          const SizedBox(height: 6),
                          _barre(c.principale.withValues(alpha: 0.6), 0.5),
                          const SizedBox(height: 10),
                          Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: c.principale,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (choisie) ...[
                    Icon(Icons.check_circle, size: 18, color: c.principale),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      nomTeinte(t, teinte),
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barre(Color couleur, double largeur) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: largeur,
    child: Container(
      height: 8,
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

class _Anneaux extends CustomPainter {
  _Anneaux(this.couleurs);

  final List<Color> couleurs;

  @override
  void paint(Canvas canvas, Size size) {
    final epaisseur = size.width * 0.09;
    for (var i = 0; i < couleurs.length; i++) {
      final rayon = size.width / 2 - epaisseur / 2 - i * epaisseur * 1.35;
      final centre = size.center(Offset.zero);
      final rect = Rect.fromCircle(center: centre, radius: rayon);
      canvas.drawArc(
        rect,
        0,
        6.283,
        false,
        Paint()
          ..color = couleurs[i].withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = epaisseur,
      );
      canvas.drawArc(
        rect,
        -1.57,
        6.283 * (0.75 - i * 0.18),
        false,
        Paint()
          ..color = couleurs[i]
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = epaisseur,
      );
    }
  }

  @override
  bool shouldRepaint(_Anneaux o) => o.couleurs != couleurs;
}

/// Les deux aperçus côte à côte.
class ChoixTeintes extends StatelessWidget {
  const ChoixTeintes({super.key, required this.choisie, required this.onChoix});

  final Teinte? choisie;
  final ValueChanged<Teinte> onChoix;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, teinte) in Teinte.values.indexed) ...[
        if (i > 0) const SizedBox(width: 16),
        Expanded(
          child: ApercuTeinte(
            teinte: teinte,
            choisie: teinte == choisie,
            onTap: () => onChoix(teinte),
          ),
        ),
      ],
    ],
  );
}

/// Premier lancement : choisir sa teinte avant tout le reste. Toucher un
/// aperçu applique déjà la teinte à l'écran ; « Continuer » l'enregistre.
class ChoixTeintePage extends StatefulWidget {
  const ChoixTeintePage({
    super.key,
    required this.onApercu,
    required this.onChoisie,
  });

  /// Montre la teinte touchée, sans l'enregistrer.
  final ValueChanged<Teinte> onApercu;
  final ValueChanged<Teinte> onChoisie;

  @override
  State<ChoixTeintePage> createState() => _ChoixTeintePageState();
}

class _ChoixTeintePageState extends State<ChoixTeintePage> {
  Teinte _choisie = teinteActive;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Text(
                  t.teinteTitre,
                  textAlign: TextAlign.center,
                  style: textes.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  t.teinteAide,
                  textAlign: TextAlign.center,
                  style: textes.bodyMedium,
                ),
                const SizedBox(height: 24),
                ChoixTeintes(
                  choisie: _choisie,
                  onChoix: (teinte) {
                    setState(() => _choisie = teinte);
                    widget.onApercu(teinte);
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => widget.onChoisie(_choisie),
                  child: Text(t.teinteContinuer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
