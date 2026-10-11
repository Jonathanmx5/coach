import 'package:flutter/material.dart';

import '../journal/formulaires.dart';
import '../journal/modele.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'modele.dart';
import 'planning.dart';

String kcalTexte(int kcal) => '$kcal kcal';

enum ActionRecette { ajouterAuJournal, changer }

String libelleRayon(AppLocalizations t, Rayon r) => switch (r) {
  Rayon.fruitsLegumes => t.rayonFruitsLegumes,
  Rayon.boulangerie => t.rayonBoulangerie,
  Rayon.viandePoisson => t.rayonViandePoisson,
  Rayon.cremerieOeufs => t.rayonCremerie,
  Rayon.epicerie => t.rayonEpicerie,
};

/// Quantité d'un ingrédient pour [portions] portions, lisible en cuisine
/// (pas d'arrondi aux 5 g des courses : 0,5 avocat reste 0,5).
String quantiteIngredient(Ingredient i, double portions) {
  final q = i.quantite * portions;
  String nombre(double v) => (v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(1).replaceAll('.', ','));
  return switch (i.unite) {
    Unite.piece => nombre(q),
    Unite.g => '${q.round()} g',
    Unite.ml => '${q.round()} ml',
  };
}

/// Détail d'une recette. Pop avec une [ActionRecette] si l'utilisateur en
/// choisit une.
class RecettePage extends StatelessWidget {
  const RecettePage({
    super.key,
    required this.recette,
    required this.portions,
    this.actions = true,
  });

  final Recette recette;
  final double portions;

  /// Faux pour la simple consultation (pas d'ajout ni de changement).
  final bool actions;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final m = recette.macros.multiplie(portions);
    return Scaffold(
      appBar: AppBar(title: Text(recette.nom)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            '${libelleMoment(t, recette.moment)} · '
            '${t.minutesValeur(recette.minutes)}',
            style: textes.bodyMedium?.copyWith(color: CouleursCoach.texteDoux),
          ),
          const SizedBox(height: 8),
          Text(
            '${kcalTexte(m.kcal.round())} · '
            'P ${m.proteines.round()} g · G ${m.glucides.round()} g · '
            'L ${m.lipides.round()} g',
            style: textes.titleMedium,
          ),
          const SizedBox(height: 20),
          Text(t.ingredientsTitre, style: textes.titleLarge),
          for (final i in recette.ingredients)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(i.nom),
              trailing: Text(quantiteIngredient(i, portions)),
            ),
          const SizedBox(height: 16),
          Text(t.preparationTitre, style: textes.titleLarge),
          const SizedBox(height: 8),
          for (var n = 0; n < recette.etapes.length; n++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${n + 1}. ${recette.etapes[n]}'),
            ),
          if (actions) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(ActionRecette.ajouterAuJournal),
              icon: const Icon(Icons.add),
              label: Text(t.ajouterAuJournal),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(ActionRecette.changer),
              icon: const Icon(Icons.swap_horiz),
              label: Text(t.changerRecette),
            ),
          ],
        ],
      ),
    );
  }
}

/// Choix d'une autre recette pour un repas. Pop avec la [Recette] choisie.
class ChoixRecettePage extends StatelessWidget {
  const ChoixRecettePage({
    super.key,
    required this.moment,
    required this.vegetarien,
  });

  final Moment moment;
  final bool vegetarien;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final liste = recettesPour(moment, vegetarien: vegetarien);
    return Scaffold(
      appBar: AppBar(title: Text(libelleMoment(t, moment))),
      body: ListView(
        children: [
          for (final r in liste)
            ListTile(
              title: Text(r.nom),
              subtitle: Text(
                '${kcalTexte(r.macros.kcal.round())} · '
                '${t.minutesValeur(r.minutes)}',
              ),
              onTap: () => Navigator.of(context).pop(r),
            ),
        ],
      ),
    );
  }
}
