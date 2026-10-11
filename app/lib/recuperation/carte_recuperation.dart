import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'recuperation.dart';

const _couleurs = {
  NiveauRecuperation.bon: CouleursCoach.vertMoyen,
  NiveauRecuperation.moyen: CouleursCoach.orange,
  NiveauRecuperation.faible: Color(0xFFE24B4A),
};

/// Score de récupération du matin, conseil pour la journée et ressenti.
class CarteRecuperation extends StatelessWidget {
  const CarteRecuperation({
    super.key,
    required this.recuperation,
    required this.ressenti,
    required this.onRessenti,
  });

  final Recuperation? recuperation;
  final int? ressenti;
  final ValueChanged<int> onRessenti;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final r = recuperation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.recuperationTitre, style: textes.titleMedium),
            const SizedBox(height: 8),
            if (r == null)
              Text(
                t.recuperationVide,
                style: textes.bodyMedium?.copyWith(
                  color: CouleursCoach.texteDoux,
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${r.score}',
                    style: textes.displaySmall?.copyWith(
                      color: _couleurs[r.niveau],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(' / 100', style: textes.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: r.score / 100,
                  minHeight: 8,
                  color: _couleurs[r.niveau],
                  backgroundColor: _couleurs[r.niveau]!.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 8),
              Text(switch (r.niveau) {
                NiveauRecuperation.bon => t.recuperationBon,
                NiveauRecuperation.moyen => t.recuperationMoyen,
                NiveauRecuperation.faible => t.recuperationFaible,
              }, style: textes.bodyMedium),
            ],
            const SizedBox(height: 12),
            Text(t.ressentiQuestion, style: textes.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<int>(
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              segments: [
                ButtonSegment(
                  value: ressentiFatigue,
                  label: Text(t.ressentiFatigue),
                ),
                ButtonSegment(
                  value: ressentiMoyen,
                  label: Text(t.ressentiMoyen),
                ),
                ButtonSegment(
                  value: ressentiForme,
                  label: Text(t.ressentiForme),
                ),
              ],
              selected: {?ressenti},
              onSelectionChanged: (s) {
                if (s.isNotEmpty) onRessenti(s.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
