import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'analyse_photo.dart';
import 'modele.dart';

/// Un aliment de la table Ciqual (ANSES, 2020, licence CC BY 4.0), valeurs
/// pour 100 g.
@immutable
class AlimentCiqual {
  const AlimentCiqual({
    required this.nom,
    required this.kcal,
    required this.proteines,
    required this.glucides,
    required this.sucres,
    required this.lipides,
    required this.satures,
  });

  final String nom;
  final double kcal;
  final double proteines;
  final double glucides;
  final double sucres;
  final double lipides;
  final double satures;

  /// L'aliment pour [grammes], sous [nomAffiche] (le libellé Ciqual par
  /// défaut, coupé à 60 caractères).
  AlimentEstime pour(double grammes, {String? nomAffiche}) {
    final f = grammes / 100;
    final n = (nomAffiche ?? nom).trim();
    return AlimentEstime(
      nom: n.length <= 60 ? n : n.substring(0, 60),
      grammes: grammes,
      macros: Macros(
        kcal: kcal * f,
        proteines: proteines * f,
        glucides: glucides * f,
        lipides: lipides * f,
      ),
      sucres: sucres * f,
      satures: satures * f,
      reference: nom,
    );
  }
}

String _simple(String s) {
  const de = 'àâäçéèêëîïôöùûüÿ';
  const vers = 'aaaceeeeiioouuuy';
  final b = StringBuffer();
  for (final c in s.toLowerCase().replaceAll('œ', 'oe').split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : vers[i]);
  }
  return b.toString();
}

final _separateur = RegExp(r'[^a-z0-9%]+');

/// La table Ciqual embarquée dans l'appli (recherche hors connexion).
class TableCiqual {
  TableCiqual(this.aliments)
    : _cles = [for (final a in aliments) _simple(a.nom)];

  final List<AlimentCiqual> aliments;
  final List<String> _cles;

  static Future<TableCiqual>? _chargee;

  static Future<TableCiqual> charger() => _chargee ??= _lire();

  static Future<TableCiqual> _lire() async {
    final brut = jsonDecode(
      await rootBundle.loadString('assets/ciqual.json'),
    ) as Map<String, dynamic>;
    double n(Object? v) => (v as num?)?.toDouble() ?? 0;
    return TableCiqual([
      for (final l in brut['aliments'] as List)
        AlimentCiqual(
          nom: (l as List)[1] as String,
          kcal: n(l[3]),
          proteines: n(l[4]),
          glucides: n(l[5]),
          sucres: n(l[6]),
          lipides: n(l[7]),
          satures: n(l[8]),
        ),
    ]);
  }

  /// Aliments dont chaque mot de [requete] commence un mot du libellé ; ceux
  /// qui commencent par le premier mot d'abord, les libellés courts avant les
  /// longs.
  List<AlimentCiqual> chercher(String requete, {int max = 40}) {
    final mots = _simple(requete)
        .split(_separateur)
        .where((m) => m.isNotEmpty)
        .toList();
    if (mots.isEmpty) return const [];
    final trouves = <(int, AlimentCiqual)>[];
    for (var i = 0; i < aliments.length; i++) {
      final cle = _cles[i];
      final dansLibelle = cle.split(_separateur);
      final tous = mots.every((m) => dansLibelle.any((w) => w.startsWith(m)));
      if (!tous) continue;
      final debut = cle.startsWith(mots.first) ? 0 : 1000;
      trouves.add((debut + cle.length, aliments[i]));
    }
    trouves.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final t in trouves.take(max)) t.$2];
  }
}

/// Recherche d'un aliment dans la table Ciqual ; renvoie l'aliment choisi.
class DialogueRechercheCiqual extends StatefulWidget {
  const DialogueRechercheCiqual({super.key, this.depart = ''});

  final String depart;

  @override
  State<DialogueRechercheCiqual> createState() =>
      _DialogueRechercheCiqualState();
}

class _DialogueRechercheCiqualState extends State<DialogueRechercheCiqual> {
  late final _requete = TextEditingController(text: widget.depart);
  TableCiqual? _table;

  @override
  void initState() {
    super.initState();
    TableCiqual.charger().then((t) {
      if (mounted) setState(() => _table = t);
    });
  }

  @override
  void dispose() {
    _requete.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final resultats = _table?.chercher(_requete.text) ?? const [];
    return AlertDialog(
      title: Text(t.ciqualRechercheTitre),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _requete,
              autofocus: true,
              decoration: InputDecoration(labelText: t.ciqualRechercheLabel),
              onChanged: (_) => setState(() {}),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final a in resultats)
                    ListTile(
                      dense: true,
                      title: Text(a.nom),
                      subtitle: Text(t.ciqualPour100(a.kcal.round())),
                      onTap: () => Navigator.of(context).pop(a),
                    ),
                ],
              ),
            ),
            Text(t.ciqualSource, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.annuler),
        ),
      ],
    );
  }
}
