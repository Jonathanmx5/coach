import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Séries de jours consécutifs : journal tenu, séances faites, eau bue.
class CarteSeries extends StatelessWidget {
  const CarteSeries({
    super.key,
    required this.journal,
    required this.entrainement,
    required this.eau,
  });

  final int journal;
  final int entrainement;
  final int eau;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    Widget ligne(IconData icone, String titre, int n) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icone, color: n > 0 ? CouleursCoach.orange : Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(titre)),
          Text(
            t.nbJours(n),
            style: textes.titleSmall?.copyWith(
              color: n > 0 ? CouleursCoach.orange : context.palette.texteDoux,
            ),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.seriesTitre, style: textes.titleMedium),
            const SizedBox(height: 4),
            ligne(Icons.restaurant, t.serieJournal, journal),
            ligne(Icons.fitness_center, t.serieEntrainement, entrainement),
            ligne(Icons.water_drop_outlined, t.serieEau, eau),
          ],
        ),
      ),
    );
  }
}
