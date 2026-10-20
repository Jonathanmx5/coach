import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'formulaires.dart';
import 'modele.dart';
import 'verdict.dart';

/// Les repas proposés de nouveau sont ceux des [joursRecents] derniers jours ;
/// au plus [maxRecents] sont montrés.
const joursRecents = 7, maxRecents = 8;

/// Les repas à proposer de nouveau, du plus récent au plus ancien : un même
/// repas (même nom, mêmes calories) n'apparaît qu'une fois, et un repas sans
/// nom n'est pas proposé.
List<Repas> repasRecents(Iterable<Repas> repas, {int max = maxRecents}) {
  final tries = [
    for (final r in repas)
      if (r.nom.trim().isNotEmpty) r,
  ]..sort((a, b) => b.date.compareTo(a.date));
  final vus = <String>{};
  return [
    for (final r in tries)
      if (vus.add('${r.nom.trim().toLowerCase()}|${r.macros.kcal.round()}')) r,
  ].take(max).toList();
}

/// Le même repas, remis au journal à [date] : mêmes aliments et apports,
/// sans la photo (elle reste attachée au repas d'origine) ni l'identifiant.
/// Le [verdict] est celui de la nouvelle journée.
Repas repasRepris(Repas r, {required DateTime date, Verdict? verdict}) => Repas(
  date: date,
  moment: r.moment,
  nom: r.nom,
  macros: r.macros,
  source: r.source,
  description: r.description,
  aliments: r.aliments,
  verdict: verdict,
);

/// « Repas récents » : un appui remet le repas au journal.
class ListeRepasRecents extends StatelessWidget {
  const ListeRepasRecents({
    super.key,
    required this.repas,
    required this.onChoisir,
  });

  final List<Repas> repas;
  final ValueChanged<Repas> onChoisir;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.repasRecentsTitre, style: textes.titleMedium),
        const SizedBox(height: 2),
        Text(t.repasRecentsAide, style: textes.bodySmall),
        for (final r in repas)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(r.nom, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                t.repasRecentLigne(
                  libelleMoment(t, r.moment),
                  DateFormat.MMMEd('fr').format(r.date),
                  r.macros.kcal.round(),
                ),
              ),
              trailing: Tooltip(
                message: t.repasRecentAjouter(r.nom),
                child: const Icon(Icons.add_circle_outline),
              ),
              onTap: () => onChoisir(r),
            ),
          ),
      ],
    );
  }
}
