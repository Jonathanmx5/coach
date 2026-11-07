import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'planning.dart';
import 'planning_repository.dart';
import 'recette_page.dart';

/// Liste de courses de la semaine, par rayon, avec cases à cocher.
class CoursesPage extends StatefulWidget {
  const CoursesPage({
    super.key,
    required this.uid,
    required this.lundi,
    required this.planning,
  });

  final String uid;
  final DateTime lundi;
  final PlanningRepository planning;

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  late final Stream<Planning?> _flux = widget.planning.planning(
    widget.uid,
    widget.lundi,
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.coursesTitre)),
      body: StreamBuilder<Planning?>(
        stream: _flux,
        builder: (context, snap) {
          final p = snap.data;
          if (p == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final lignes = listeCourses(p);
          final rayons = {for (final l in lignes) l.rayon};
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                t.coursesAide,
                style: textes.bodySmall?.copyWith(
                  color: context.palette.texteDoux,
                ),
              ),
              for (final r in rayons) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Text(libelleRayon(t, r), style: textes.titleMedium),
                ),
                for (final l in lignes.where((l) => l.rayon == r))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: p.coches.contains(l.cle),
                    title: Text(
                      l.nom,
                      style: p.coches.contains(l.cle)
                          ? TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: context.palette.texteDoux,
                            )
                          : null,
                    ),
                    secondary: Text(l.quantiteTexte),
                    onChanged: (v) => unawaited(
                      widget.planning.enregistrer(
                        widget.uid,
                        p.avecCoche(l.cle, v ?? false),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
