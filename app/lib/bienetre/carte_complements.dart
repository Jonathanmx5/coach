import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'complements.dart';

/// Compléments du jour : rappel à heure fixe, case « pris » quotidienne.
class CarteComplements extends StatelessWidget {
  const CarteComplements({
    super.key,
    required this.complements,
    required this.prises,
    required this.onPris,
    required this.onAjouter,
    required this.onBasculer,
    required this.onSupprimer,
  });

  final List<Complement> complements;
  final Set<String> prises;
  final void Function(Complement c, bool pris) onPris;
  final void Function(String nom, int minutes) onAjouter;
  final ValueChanged<Complement> onBasculer;
  final ValueChanged<Complement> onSupprimer;

  Future<void> _ajouter(BuildContext context) async {
    final resultat = await showDialog<({String nom, int minutes})>(
      context: context,
      builder: (_) => const _DialogueComplement(),
    );
    if (resultat != null) onAjouter(resultat.nom, resultat.minutes);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.complementsTitre, style: textes.titleMedium),
            const SizedBox(height: 4),
            Text(
              t.complementsAide,
              style: textes.bodySmall?.copyWith(
                color: context.palette.texteDoux,
              ),
            ),
            for (final c in complements)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: prises.contains(c.id),
                onChanged: c.actif ? (v) => onPris(c, v ?? false) : null,
                title: Text(
                  c.nom,
                  style: c.actif
                      ? null
                      : TextStyle(color: context.palette.texteDoux),
                ),
                subtitle: Text(
                  c.actif
                      ? t.rappelA(heureTexte(c.minutes))
                      : t.rappelDesactive,
                ),
                secondary: PopupMenuButton<String>(
                  tooltip: t.optionsComplement,
                  onSelected: (v) =>
                      v == 'basculer' ? onBasculer(c) : onSupprimer(c),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'basculer',
                      child: Text(
                        c.actif ? t.desactiverRappel : t.activerRappel,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'supprimer',
                      child: Text(t.supprimerComplement),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _ajouter(context),
              icon: const Icon(Icons.add_alarm),
              label: Text(t.ajouterComplement),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogueComplement extends StatefulWidget {
  const _DialogueComplement();

  @override
  State<_DialogueComplement> createState() => _DialogueComplementState();
}

class _DialogueComplementState extends State<_DialogueComplement> {
  final _nom = TextEditingController();
  int _minutes = 8 * 60;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Future<void> _choisirHeure() async {
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60),
    );
    if (h != null) setState(() => _minutes = h.hour * 60 + h.minute);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(t.ajouterComplement),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nom,
            autofocus: true,
            maxLength: Complement.nomMax,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: t.nomComplement),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _choisirHeure,
            icon: const Icon(Icons.schedule),
            label: Text(t.rappelA(heureTexte(_minutes))),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.annuler),
        ),
        FilledButton(
          onPressed: _nom.text.trim().isEmpty
              ? null
              : () =>
                    Navigator.of(context)
                        .pop((nom: _nom.text.trim(), minutes: _minutes)),
          child: Text(t.enregistrer),
        ),
      ],
    );
  }
}
