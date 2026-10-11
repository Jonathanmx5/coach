import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'modele.dart';
import 'verdict.dart';

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
