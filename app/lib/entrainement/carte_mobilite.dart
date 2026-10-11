import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'mobilite.dart';

String _titre(AppLocalizations t, Routine r) => switch (r) {
  Routine.apresEffort => t.routineApresEffort,
  Routine.reveil => t.routineReveil,
  Routine.recuperation => t.routineRecuperation,
};

/// Routines d'étirements et de mobilité ; la plus utile du moment est en tête.
class CarteMobilite extends StatelessWidget {
  const CarteMobilite({
    super.key,
    required this.conseillee,
    required this.onLancer,
  });

  final Routine conseillee;
  final ValueChanged<Routine> onLancer;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final ordre = [
      conseillee,
      for (final r in Routine.values)
        if (r != conseillee) r,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.mobiliteTitre, style: textes.titleMedium),
            const SizedBox(height: 4),
            for (final r in ordre)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.self_improvement),
                title: Text(_titre(t, r)),
                subtitle: r == conseillee
                    ? Text(
                        t.conseilleMaintenant,
                        style: textes.labelMedium?.copyWith(
                          color: CouleursCoach.vert,
                        ),
                      )
                    : null,
                trailing: const Icon(Icons.play_circle_outline),
                onTap: () => onLancer(r),
              ),
          ],
        ),
      ),
    );
  }
}
