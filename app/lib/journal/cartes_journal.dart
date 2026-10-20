import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'calculs.dart';
import 'formulaires.dart';
import 'modele.dart';

/// Les repas de la journée additionnés : un total par moment (petit-déjeuner,
/// midi, soir, collation) puis le total de la journée.
class CarteRecap extends StatelessWidget {
  const CarteRecap({super.key, required this.repas});

  final List<Repas> repas;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final parMoment = {
      for (final m in Moment.values)
        m: totalMacros(repas.where((r) => r.moment == m)),
    };
    final total = totalMacros(repas);
    String valeur(Macros m) =>
        t.recapValeur(m.kcal.round(), m.proteines.round());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.recapTitre, style: textes.titleMedium),
            const SizedBox(height: 8),
            for (final m in Moment.values)
              if (repas.any((r) => r.moment == m))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(libelleMoment(t, m)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          valeur(parMoment[m]!),
                          textAlign: TextAlign.end,
                          style: textes.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            const Divider(),
            Row(
              children: [
                Text(t.recapTotal, style: textes.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    valeur(total),
                    key: const Key('recap-total'),
                    textAlign: TextAlign.end,
                    style: textes.titleSmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SelecteurJour extends StatelessWidget {
  const SelecteurJour({
    super.key,
    required this.jour,
    required this.estAujourdhui,
    required this.onChanger,
  });

  final DateTime jour;
  final bool estAujourdhui;
  final ValueChanged<int> onChanger;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Row(
      children: [
        IconButton(
          tooltip: t.jourPrecedent,
          onPressed: () => onChanger(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            estAujourdhui
                ? t.jourAujourdhui
                : DateFormat.MMMEd('fr').format(jour),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: t.jourSuivant,
          onPressed: estAujourdhui ? null : () => onChanger(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class CarteBilan extends StatelessWidget {
  const CarteBilan({
    super.key,
    required this.mange,
    required this.depense,
    required this.ecart,
    required this.cible,
    required this.intensite,
  });

  final double mange;
  final double depense;
  final double ecart;
  final double cible;
  final IntensiteJour intensite;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final deficit = ecart <= 0;
    final libelleIntensite = switch (intensite) {
      IntensiteJour.repos => t.jourRepos,
      IntensiteJour.modere => t.jourModere,
      IntensiteJour.intense => t.jourIntense,
    };
    final signe = ecart < 0 ? '−' : (ecart > 0 ? '+' : '');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.bilanTitre, style: textes.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: intensite == IntensiteJour.intense
                        ? context.palette.orangeClair
                        : context.palette.vertClair,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(libelleIntensite, style: textes.labelMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: cible <= 0 ? 0 : (mange / cible).clamp(0, 1),
                minHeight: 10,
                color: CouleursCoach.orange,
                backgroundColor: context.palette.orangeClair,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.cibleJour(cible.round()),
              style: textes.bodySmall?.copyWith(
                color: context.palette.texteDoux,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Valeur(
                  cle: 'valeur-mange',
                  libelle: t.bilanMange,
                  valeur: t.kcalValeur(mange.round().toString()),
                ),
                _Valeur(
                  cle: 'valeur-depense',
                  libelle: t.bilanDepense,
                  valeur: t.kcalValeur(depense.round().toString()),
                ),
                _Valeur(
                  cle: 'valeur-solde',
                  libelle: deficit ? t.soldeDeficit : t.soldeExcedent,
                  valeur: t.kcalValeur('$signe${ecart.abs().round()}'),
                  // Vert vif en thème sombre : le vert profond y serait
                  // illisible.
                  couleur: deficit
                      ? Theme.of(context).colorScheme.primary
                      : context.palette.orangeFonce,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Valeur extends StatelessWidget {
  const _Valeur({
    required this.cle,
    required this.libelle,
    required this.valeur,
    this.couleur,
  });

  final String cle;
  final String libelle;
  final String valeur;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: textes.bodySmall?.copyWith(color: context.palette.texteDoux),
          ),
          Text(
            valeur,
            key: ValueKey(cle),
            style: textes.titleMedium?.copyWith(color: couleur),
          ),
        ],
      ),
    );
  }
}

class CarteMacros extends StatelessWidget {
  const CarteMacros({super.key, required this.macros, required this.cibles});

  final Macros macros;
  final CiblesJour cibles;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.macrosTitre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _BarreMacro(
              t.macroProteines,
              macros.proteines,
              cibles.proteines,
              Theme.of(context).colorScheme.primary,
            ),
            _BarreMacro(
              t.macroGlucides,
              macros.glucides,
              cibles.glucides,
              CouleursCoach.orange,
            ),
            _BarreMacro(
              t.macroLipides,
              macros.lipides,
              cibles.lipides,
              const Color(0xFF378ADD),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarreMacro extends StatelessWidget {
  const _BarreMacro(this.nom, this.mange, this.cible, this.couleur);

  final String nom;
  final double mange;
  final double cible;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(nom, style: textes.bodyMedium)),
              Text(
                t.macroProgression(mange.round(), cible.round()),
                style: textes.bodySmall?.copyWith(
                  color: context.palette.texteDoux,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cible <= 0 ? 0 : (mange / cible).clamp(0, 1),
              minHeight: 8,
              color: couleur,
              backgroundColor: couleur.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class Vide extends StatelessWidget {
  const Vide(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      texte,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: context.palette.texteDoux),
    ),
  );
}

class Ligne extends StatelessWidget {
  const Ligne({
    super.key,
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.onSupprimer,
    this.onTap,
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback? onSupprimer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icone, color: Theme.of(context).colorScheme.primary),
        title: Text(titre),
        subtitle: Text(sousTitre),
        onTap: onTap,
        trailing: onSupprimer == null
            ? null
            : IconButton(
                tooltip: t.supprimer,
                onPressed: onSupprimer,
                icon: const Icon(Icons.delete_outline),
              ),
      ),
    );
  }
}
