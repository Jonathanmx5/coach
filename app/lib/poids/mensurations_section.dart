import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../l10n/app_localizations.dart';
import '../profil/saisie.dart';
import '../theme.dart';
import 'mensurations.dart';
import 'mensurations_repository.dart';

String _libelle(AppLocalizations t, TypeMensuration m) => switch (m) {
  TypeMensuration.taille => t.mesureTaille,
  TypeMensuration.poitrine => t.mesurePoitrine,
  TypeMensuration.bras => t.mesureBras,
  TypeMensuration.masseGrasse => t.mesureMasseGrasse,
};

String _unite(TypeMensuration m) =>
    m == TypeMensuration.masseGrasse ? '%' : 'cm';

/// Tour de taille, de poitrine, de bras et masse grasse : dernière valeur et
/// évolution depuis la première saisie.
class MensurationsSection extends StatelessWidget {
  const MensurationsSection({
    super.key,
    required this.depot,
    required this.uid,
    required this.horloge,
  });

  final MensurationsRepository depot;
  final String uid;
  final DateTime Function() horloge;

  Future<void> _ajouter(BuildContext context) async {
    final m = await showModalBottomSheet<Mensuration>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FeuilleMesures(maintenant: horloge()),
    );
    if (m != null) unawaited(depot.ajouter(uid, m));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return StreamBuilder<List<Mensuration>>(
      stream: depot.observer(uid),
      builder: (context, snap) {
        final liste = snap.data ?? const <Mensuration>[];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.mensurationsTitre, style: textes.titleMedium),
                const SizedBox(height: 8),
                if (liste.isEmpty)
                  Text(
                    t.aucuneMesure,
                    style: textes.bodyMedium?.copyWith(
                      color: context.palette.texteDoux,
                    ),
                  )
                else
                  for (final type in TypeMensuration.values)
                    _Ligne(type: type, mesure: derniereMesure(liste, type)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _ajouter(context),
                  icon: const Icon(Icons.straighten),
                  label: Text(t.ajouterMesures),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.type, required this.mesure});

  final TypeMensuration type;
  final ({double valeur, double? ecart})? mesure;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final e = mesure?.ecart;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(_libelle(t, type))),
          if (mesure == null)
            Text('—', style: textes.bodyMedium)
          else ...[
            if (e != null && e != 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '${e > 0 ? '+' : '−'}${formatDecimal(e.abs())}',
                  style: textes.bodySmall?.copyWith(
                    color: context.palette.texteDoux,
                  ),
                ),
              ),
            Text(
              '${formatDecimal(mesure!.valeur)} ${_unite(type)}',
              style: textes.titleSmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _FeuilleMesures extends StatefulWidget {
  const _FeuilleMesures({required this.maintenant});

  final DateTime maintenant;

  @override
  State<_FeuilleMesures> createState() => _FeuilleMesuresState();
}

class _FeuilleMesuresState extends State<_FeuilleMesures> {
  final _champs = {
    for (final m in TypeMensuration.values) m: TextEditingController(),
  };
  String? _erreur;

  @override
  void dispose() {
    for (final c in _champs.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _valider(AppLocalizations t) {
    final valeurs = <TypeMensuration, double>{};
    for (final e in _champs.entries) {
      final texte = e.value.text.trim();
      if (texte.isEmpty) continue;
      final v = lireNombre(texte);
      final plage = plagesMensuration[e.key]!;
      if (v == null || v < plage.min || v > plage.max) {
        setState(
          () => _erreur =
              '${_libelle(t, e.key)} : '
              '${t.erreurPlage(plage.min.round(), plage.max.round())}',
        );
        return;
      }
      valeurs[e.key] = (v * 10).round() / 10;
    }
    if (valeurs.isEmpty) {
      setState(() => _erreur = t.erreurMesures);
      return;
    }
    Navigator.of(context)
        .pop(Mensuration(date: widget.maintenant, valeurs: valeurs));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.mesuresAide),
          const SizedBox(height: 12),
          for (final type in TypeMensuration.values) ...[
            TextField(
              controller: _champs[type],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: '${_libelle(t, type)} (${_unite(type)})',
              ),
              onChanged: (_) {
                if (_erreur != null) setState(() => _erreur = null);
              },
            ),
            const SizedBox(height: 8),
          ],
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _erreur!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: () => _valider(t),
            child: Text(t.enregistrer),
          ),
        ],
      ),
    );
  }
}
