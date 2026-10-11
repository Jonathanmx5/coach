import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../profil/questionnaire/etapes.dart';
import '../profil/saisie.dart';
import 'calculs.dart';
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
  ValueChanged<String>? onChanged,
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
    onChanged: onChanged,
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

/// Saisie d'une activité : type, durée, intensité. Renvoie l'[Activite].
class AjoutActivitePage extends StatefulWidget {
  const AjoutActivitePage({
    super.key,
    required this.date,
    required this.poidsKg,
  });

  final DateTime date;
  final double poidsKg;

  @override
  State<AjoutActivitePage> createState() => _AjoutActivitePageState();
}

class _AjoutActivitePageState extends State<AjoutActivitePage> {
  final _duree = TextEditingController();
  TypeActivite _type = TypeActivite.velo;
  Intensite _intensite = Intensite.moderee;
  String? _erreur;

  @override
  void dispose() {
    _duree.dispose();
    super.dispose();
  }

  int? get _minutes {
    final m = lireNombre(_duree.text);
    return (m == null || m <= 0 || m > 600 || m != m.roundToDouble())
        ? null
        : m.toInt();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final minutes = _minutes;
    return Scaffold(
      appBar: AppBar(title: Text(t.menuActivite)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          grille([
            for (final a in TypeActivite.values)
              TuileChoix(
                titre: libelleActivite(t, a),
                icone: iconesActivite[a]!,
                selectionne: _type == a,
                onTap: () => setState(() => _type = a),
              ),
          ]),
          _champ(
            _duree,
            t.champDureeMin,
            erreur: _erreur,
            onChanged: (_) => setState(() => _erreur = null),
          ),
          const SizedBox(height: 4),
          SegmentedButton<Intensite>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: Intensite.legere, label: Text(t.intLegere)),
              ButtonSegment(
                value: Intensite.moderee,
                label: Text(t.intModeree),
              ),
              ButtonSegment(
                value: Intensite.intense,
                label: Text(t.intIntense),
              ),
            ],
            selected: {_intensite},
            onSelectionChanged: (s) => setState(() => _intensite = s.first),
          ),
          const SizedBox(height: 16),
          if (minutes != null)
            Text(
              t.activiteEstimation(
                kcalActivite(
                  _type,
                  minutes,
                  _intensite,
                  widget.poidsKg,
                ).round(),
              ),
              style: textes.titleMedium,
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final m = _minutes;
              if (m == null) {
                setState(() => _erreur = t.erreurDuree);
                return;
              }
              Navigator.of(context).pop(
                Activite(
                  date: widget.date,
                  type: _type,
                  minutes: m,
                  intensite: _intensite,
                  kcal: kcalActivite(_type, m, _intensite, widget.poidsKg),
                ),
              );
            },
            child: Text(t.enregistrer),
          ),
        ],
      ),
    );
  }
}
