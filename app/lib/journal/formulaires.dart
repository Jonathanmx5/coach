import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../profil/saisie.dart';
import 'modele.dart';

String libelleMoment(AppLocalizations t, Moment m) => switch (m) {
  Moment.petitDejeuner => t.momentPetitDej,
  Moment.dejeuner => t.momentDejeuner,
  Moment.diner => t.momentDiner,
  Moment.collation => t.momentCollation,
};

String libelleActivite(AppLocalizations t, TypeActivite a) => switch (a) {
  TypeActivite.velo => t.actVelo,
  TypeActivite.mma => t.actMma,
  TypeActivite.course => t.actCourse,
  TypeActivite.natation => t.actNatation,
  TypeActivite.musculation => t.actMuscu,
  TypeActivite.marche => t.actMarche,
  TypeActivite.autre => t.actAutre,
};

const iconesActivite = {
  TypeActivite.velo: Icons.directions_bike,
  TypeActivite.mma: Icons.sports_mma,
  TypeActivite.course: Icons.directions_run,
  TypeActivite.natation: Icons.pool,
  TypeActivite.musculation: Icons.fitness_center,
  TypeActivite.marche: Icons.hiking,
  TypeActivite.autre: Icons.sports,
};

/// Moment de la journée le plus probable à cette heure.
Moment momentPourHeure(DateTime t) => t.hour < 10
    ? Moment.petitDejeuner
    : t.hour < 15
    ? Moment.dejeuner
    : t.hour < 18
    ? Moment.collation
    : Moment.diner;

final _decimal = FilteringTextInputFormatter.allow(RegExp('[0-9.,]'));

Widget _champ(
  TextEditingController c,
  String label, {
  String? erreur,
  bool decimal = true,
  bool focus = false,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextField(
    controller: c,
    autofocus: focus,
    keyboardType: decimal
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters: decimal ? [_decimal] : null,
    decoration: InputDecoration(labelText: label, errorText: erreur),
  ),
);

DropdownButtonFormField<Moment> _choixMoment(
  AppLocalizations t,
  Moment valeur,
  ValueChanged<Moment> onChanged,
) => DropdownButtonFormField<Moment>(
  initialValue: valeur,
  decoration: InputDecoration(labelText: t.champMoment),
  items: [
    for (final m in Moment.values)
      DropdownMenuItem(value: m, child: Text(libelleMoment(t, m))),
  ],
  onChanged: (m) {
    if (m != null) onChanged(m);
  },
);

/// Lit un nombre facultatif (vide = 0) ; null si invalide.
double? _facultatif(String texte) =>
    texte.trim().isEmpty ? 0 : lireNombre(texte);

/// Saisie manuelle d'un repas. Renvoie le [Repas] enregistré (ou null).
class AjoutRepasPage extends StatefulWidget {
  const AjoutRepasPage({super.key, required this.date});

  final DateTime date;

  @override
  State<AjoutRepasPage> createState() => _AjoutRepasPageState();
}

class _AjoutRepasPageState extends State<AjoutRepasPage> {
  final _nom = TextEditingController();
  final _kcal = TextEditingController();
  final _prot = TextEditingController();
  final _gluc = TextEditingController();
  final _lip = TextEditingController();
  late Moment _moment = momentPourHeure(widget.date);
  String? _erreurKcal;
  String? _erreurMacros;

  @override
  void dispose() {
    for (final c in [_nom, _kcal, _prot, _gluc, _lip]) {
      c.dispose();
    }
    super.dispose();
  }

  void _valider(AppLocalizations t) {
    final kcal = lireNombre(_kcal.text);
    final p = _facultatif(_prot.text);
    final g = _facultatif(_gluc.text);
    final l = _facultatif(_lip.text);
    setState(() {
      _erreurKcal = kcal == null
          ? t.erreurNombre
          : (kcal < 0 || kcal > 5000)
          ? t.erreurPlage(0, 5000)
          : null;
      _erreurMacros = (p == null || g == null || l == null)
          ? t.erreurNombre
          : null;
    });
    if (_erreurKcal != null || _erreurMacros != null) return;
    final nom = _nom.text.trim();
    Navigator.of(context).pop(
      Repas(
        date: widget.date,
        moment: _moment,
        nom: nom.isEmpty ? t.nomRepasDefaut : nom,
        macros: Macros(kcal: kcal!, proteines: p!, glucides: g!, lipides: l!),
        source: SourceRepas.manuel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.menuRepas)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _champ(_nom, t.champNomRepas, decimal: false),
          _choixMoment(t, _moment, (m) => setState(() => _moment = m)),
          const SizedBox(height: 12),
          _champ(_kcal, t.champKcal, erreur: _erreurKcal),
          _champ(_prot, t.champProteines, erreur: _erreurMacros),
          _champ(_gluc, t.champGlucides),
          _champ(_lip, t.champLipides),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _valider(t),
            child: Text(t.enregistrer),
          ),
        ],
      ),
    );
  }
}
