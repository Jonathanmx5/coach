import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../compte/auth_service.dart';
import '../journal/calculs.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import '../l10n/app_localizations.dart';
import '../profil/besoins.dart';
import '../profil/garde_fous.dart';
import '../profil/modele.dart';
import '../profil/profil_repository.dart';
import '../profil/questionnaire/controleur.dart';
import '../profil/saisie.dart';
import '../sante/agregation.dart';
import '../sante/modele.dart';
import '../sante/sante_service.dart';
import '../theme.dart';
import 'mensurations_repository.dart';
import 'mensurations_section.dart';
import 'pesees.dart';
import 'photos.dart';
import 'photos_section.dart';
import 'pesees_repository.dart';

/// Onglet Poids : poids actuel, IMC, courbe et historique des pesées.
class PoidsPage extends StatefulWidget {
  const PoidsPage({
    super.key,
    required this.utilisateur,
    required this.enregistre,
    required this.depot,
    required this.pesees,
    required this.journal,
    required this.mensurations,
    required this.photos,
    required this.sante,
    required this.horloge,
  });

  final Utilisateur utilisateur;
  final ProfilEnregistre enregistre;
  final ProfilRepository depot;
  final PeseesRepository pesees;
  final JournalRepository journal;
  final MensurationsRepository mensurations;
  final PhotosProgres photos;
  final SanteService sante;
  final DateTime Function() horloge;

  @override
  State<PoidsPage> createState() => _PoidsPageState();
}

class _PoidsPageState extends State<PoidsPage> {
  int _jours = 30;
  List<Mesure> _montre = const [];
  late final Stream<List<Pesee>> _saisies = widget.pesees.observer(
    widget.utilisateur.uid,
  );

  Profil get _profil => widget.enregistre.profil;
  String get _uid => widget.utilisateur.uid;

  @override
  void initState() {
    super.initState();
    _lireMontre();
  }

  /// Un an de pesées Health Connect, pour que la courbe soit pleine d'emblée.
  Future<void> _lireMontre() async {
    if (!_profil.montre) return;
    try {
      if (await widget.sante.disponibilite() != DispoSante.disponible) return;
      final maintenant = widget.horloge();
      final points = await widget.sante.lire(
        DateTime(maintenant.year - 1, maintenant.month, maintenant.day),
        maintenant,
        types: {TypeMesure.poids},
      );
      if (mounted) setState(() => _montre = mesures(points, TypeMesure.poids));
    } catch (_) {
      // Pas de pesées de la montre : seules les saisies s'affichent.
    }
  }

  void _enregistrerProfil(Profil profil) {
    // Hors-ligne, l'écriture ne se termine qu'à la synchronisation.
    unawaited(
      widget.depot.enregistrer(
        _uid,
        profil,
        calculerReperes(profil, maintenant: widget.horloge()),
      ),
    );
  }

  void _ajouter(double kg, DateTime date) {
    unawaited(widget.pesees.ajouter(_uid, kg: kg, date: date));
    final profil = profilAvecPesee(_profil, kg: kg, date: date);
    if (profil != null) _enregistrerProfil(profil);
  }

  void _supprimer(Pesee pesee, List<Pesee> toutes) {
    unawaited(widget.pesees.supprimer(_uid, pesee.id!));
    final restantes = [
      for (final p in toutes)
        if (p.id != pesee.id) p,
    ];
    final etaitLaDerniere = toutes.isNotEmpty && toutes.last.id == pesee.id;
    if (etaitLaDerniere && restantes.isNotEmpty) {
      _enregistrerProfil(profilDepuisDerniere(_profil, restantes.last));
    }
  }

  Future<void> _ouvrirAjout() async {
    final resultat = await showModalBottomSheet<({double kg, DateTime date})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FeuilleAjout(maintenant: widget.horloge()),
    );
    if (resultat != null) _ajouter(resultat.kg, resultat.date);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.tabPoids)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-poids',
        onPressed: _ouvrirAjout,
        icon: const Icon(Icons.add),
        label: Text(t.ajouterPesee),
      ),
      body: StreamBuilder<List<Pesee>>(
        stream: _saisies,
        builder: (context, snap) {
          final toutes = fusionnerPesees(snap.data ?? const [], _montre);
          final maintenant = widget.horloge();
          final dernierePesee = toutes.isEmpty ? null : toutes.last;
          final poids = dernierePesee?.kg ?? _profil.poidsKg;
          final ecart = ecartDepuisPremiere(toutes);
          final debut = DateTime(
            maintenant.year,
            maintenant.month,
            maintenant.day - _jours,
          );
          final visibles = peseesDepuis(toutes, debut);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              _CartePoids(
                kg: poids,
                depuis: ecart == null
                    ? null
                    : t.poidsDepuis(
                        '${ecart > 0 ? '+' : '−'}'
                        '${_virgule(ecart.abs())}',
                        DateFormat.yMMMd('fr').format(toutes.first.date),
                      ),
              ),
              const SizedBox(height: 16),
              _CarteImc(imc: imc(poids, _profil.tailleCm)),
              const SizedBox(height: 24),
              Text(t.courbePoids, style: textes.titleLarge),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 30, label: Text(t.periode30)),
                  ButtonSegment(value: 90, label: Text(t.periode90)),
                  ButtonSegment(value: 365, label: Text(t.periode1an)),
                ],
                selected: {_jours},
                onSelectionChanged: (s) => setState(() => _jours = s.first),
              ),
              const SizedBox(height: 12),
              _CourbeAvecProjection(
                journal: widget.journal,
                uid: _uid,
                maintien: widget.enregistre.reperes.maintien,
                maintenant: maintenant,
                pesees: visibles,
                debut: debut,
              ),
              const SizedBox(height: 24),
              MensurationsSection(
                depot: widget.mensurations,
                uid: _uid,
                horloge: widget.horloge,
              ),
              const SizedBox(height: 16),
              PhotosSection(photos: widget.photos, horloge: widget.horloge),
              const SizedBox(height: 24),
              Text(t.historiquePoids, style: textes.titleLarge),
              const SizedBox(height: 8),
              if (toutes.isEmpty)
                Text(
                  t.aucunePesee,
                  style: textes.bodyMedium?.copyWith(
                    color: context.palette.texteDoux,
                  ),
                )
              else
                for (final p in toutes.reversed)
                  _LignePesee(
                    pesee: p,
                    onSupprimer: p.id == null
                        ? null
                        : () => _supprimer(p, toutes),
                  ),
            ],
          );
        },
      ),
    );
  }
}

String _virgule(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

class _CartePoids extends StatelessWidget {
  const _CartePoids({required this.kg, required this.depuis});

  final double kg;
  final String? depuis;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CouleursCoach.vert,
        borderRadius: BorderRadius.circular(rayonCarte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.poidsActuel,
            style: textes.labelLarge?.copyWith(color: CouleursCoach.vertPale),
          ),
          const SizedBox(height: 4),
          Text(
            t.poidsKgValeur(_virgule(kg)),
            style: textes.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (depuis != null)
            Text(
              depuis!,
              style: textes.bodyMedium?.copyWith(color: CouleursCoach.vertPale),
            ),
        ],
      ),
    );
  }
}

const _couleursImc = {
  CategorieImc.maigreur: Color(0xFF378ADD),
  CategorieImc.normal: CouleursCoach.vertMoyen,
  CategorieImc.surpoids: CouleursCoach.orange,
  CategorieImc.obesite: Color(0xFFE24B4A),
};

String _libelleImc(AppLocalizations t, CategorieImc c) => switch (c) {
  CategorieImc.maigreur => t.imcMaigreur,
  CategorieImc.normal => t.imcNormal,
  CategorieImc.surpoids => t.imcSurpoids,
  CategorieImc.obesite => t.imcObesite,
};

class _CarteImc extends StatelessWidget {
  const _CarteImc({required this.imc});

  final double imc;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final categorie = categorieImc(imc);
    final couleur = _couleursImc[categorie]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.imcTitre, style: textes.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _virgule(imc),
                  style: textes.headlineMedium?.copyWith(color: couleur),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _libelleImc(t, categorie),
                    style: textes.labelLarge?.copyWith(
                      color: context.palette.texte,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final c in CategorieImc.values)
                  Expanded(
                    child: Container(
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _couleursImc[c]!.withValues(
                          alpha: c == categorie ? 1 : 0.25,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.imcAide,
              style: textes.bodySmall?.copyWith(
                color: context.palette.texteDoux,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Courbe + projection à 5 jours d'après le solde moyen des 7 derniers jours
/// renseignés dans le journal (aujourd'hui exclu : journée incomplète).
class _CourbeAvecProjection extends StatelessWidget {
  const _CourbeAvecProjection({
    required this.journal,
    required this.uid,
    required this.maintien,
    required this.maintenant,
    required this.pesees,
    required this.debut,
  });

  final JournalRepository journal;
  final String uid;
  final int maintien;
  final DateTime maintenant;
  final List<Pesee> pesees;
  final DateTime debut;

  @override
  Widget build(BuildContext context) {
    final aujourdhui = DateTime(
      maintenant.year,
      maintenant.month,
      maintenant.day,
    );
    final depart = DateTime(
      aujourdhui.year,
      aujourdhui.month,
      aujourdhui.day - 7,
    );
    return StreamBuilder<List<Repas>>(
      stream: journal.repas(uid, depart, aujourdhui),
      builder: (context, repas) => StreamBuilder<List<Activite>>(
        stream: journal.activites(uid, depart, aujourdhui),
        builder: (context, activites) {
          List<double>? projection;
          if (pesees.isNotEmpty && repas.hasData) {
            projection = projeterPoids(
              poidsKg: pesees.last.kg,
              soldes: soldesRecents(
                repas: repas.data!,
                activites: activites.data ?? const [],
                maintien: maintien,
                debut: depart,
                fin: aujourdhui,
              ),
            );
          }
          return _Courbe(
            pesees: pesees,
            debut: debut,
            projection: projection,
            aujourdhui: aujourdhui,
          );
        },
      ),
    );
  }
}

/// Cadre du graphique : bornes et pas du quadrillage.
typedef GrilleCourbe = ({
  double maxX,
  double pasJours,
  double minY,
  double maxY,
  double pasKg,
});

/// Un trait vertical par semaine sur 30 jours, tous les 15 jours sur 90, tous
/// les 2 mois sur un an ; un trait horizontal tous les 1, 2 ou 5 kg selon
/// l'écart des pesées, avec 1 kg de marge en haut et en bas.
GrilleCourbe grilleCourbe({
  required int jours,
  required List<double> poids,
  required bool avecProjection,
}) {
  final pasJours = jours <= 31 ? 7.0 : (jours <= 92 ? 15.0 : 60.0);
  final bas = poids.isEmpty ? 0.0 : poids.reduce((a, b) => a < b ? a : b);
  final haut = poids.isEmpty ? 0.0 : poids.reduce((a, b) => a > b ? a : b);
  final ecart = haut - bas;
  final pasKg = ecart <= 6 ? 1.0 : (ecart <= 15 ? 2.0 : 5.0);
  final minY = ((bas - 1) / pasKg).floorToDouble() * pasKg;
  final maxY = ((haut + 1) / pasKg).ceilToDouble() * pasKg;
  return (
    maxX: jours + (avecProjection ? 5.0 : 1.0),
    pasJours: pasJours,
    minY: minY,
    maxY: maxY,
    pasKg: pasKg,
  );
}

class _Courbe extends StatelessWidget {
  const _Courbe({
    required this.pesees,
    required this.debut,
    this.projection,
    required this.aujourdhui,
  });

  final List<Pesee> pesees;
  final DateTime debut;
  final List<double>? projection;
  final DateTime aujourdhui;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final g = grilleCourbe(
      jours: aujourdhui.difference(debut).inDays,
      poids: [for (final p in pesees) p.kg, ...?projection],
      avecProjection: projection != null,
    );
    final trait = FlLine(color: context.palette.bordure, strokeWidth: 0.8);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          children: [
            SizedBox(
              height: 230,
              child: pesees.isEmpty
                  ? const SizedBox.shrink()
                  : LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: g.maxX,
                        minY: g.minY,
                        maxY: g.maxY,
                        gridData: FlGridData(
                          horizontalInterval: g.pasKg,
                          verticalInterval: g.pasJours,
                          getDrawingHorizontalLine: (_) => trait,
                          getDrawingVerticalLine: (_) => trait,
                        ),
                        borderData: FlBorderData(
                          border: Border.all(color: context.palette.bordure),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              interval: g.pasJours,
                              getTitlesWidget: (v, meta) => v % g.pasJours != 0
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        DateFormat('d/M', 'fr').format(
                                          DateTime(
                                            debut.year,
                                            debut.month,
                                            debut.day + v.round(),
                                          ),
                                        ),
                                        style: textes.labelSmall,
                                      ),
                                    ),
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: g.pasKg,
                              getTitlesWidget: (v, meta) => Text(
                                v.toStringAsFixed(0),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            color: CouleursCoach.vert,
                            barWidth: 3,
                            spots: [
                              for (final p in pesees)
                                FlSpot(
                                  p.date.difference(debut).inHours / 24,
                                  p.kg,
                                ),
                            ],
                            dotData: FlDotData(
                              getDotPainter: (spot, _, _, i) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color:
                                        pesees[i].source == SourcePesee.montre
                                        ? CouleursCoach.orange
                                        : CouleursCoach.vert,
                                    strokeColor: Colors.white,
                                    strokeWidth: 1.5,
                                  ),
                            ),
                          ),
                          if (projection != null)
                            LineChartBarData(
                              color: context.palette.texteDoux,
                              barWidth: 2,
                              dashArray: [6, 5],
                              dotData: const FlDotData(show: false),
                              spots: [
                                FlSpot(
                                  pesees.last.date.difference(debut).inHours /
                                      24,
                                  pesees.last.kg,
                                ),
                                for (var i = 0; i < projection!.length; i++)
                                  FlSpot(
                                    aujourdhui.difference(debut).inDays +
                                        i +
                                        1.0,
                                    projection![i],
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
            if (projection != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 8),
                child: Text(
                  t.projectionLegende,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.palette.texteDoux),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LignePesee extends StatelessWidget {
  const _LignePesee({required this.pesee, required this.onSupprimer});

  final Pesee pesee;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final montre = pesee.source == SourcePesee.montre;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          t.poidsKgValeur(_virgule(pesee.kg)),
          style: textes.titleMedium,
        ),
        subtitle: Text(DateFormat.yMMMd('fr').format(pesee.date)),
        leading: Icon(
          montre ? Icons.watch_outlined : Icons.edit_outlined,
          color: montre ? CouleursCoach.orange : CouleursCoach.vert,
        ),
        trailing: onSupprimer == null
            ? Text(
                t.sourceMontre,
                style: textes.labelMedium?.copyWith(
                  color: context.palette.texteDoux,
                ),
              )
            : IconButton(
                tooltip: t.supprimerPesee,
                onPressed: onSupprimer,
                icon: const Icon(Icons.delete_outline),
              ),
      ),
    );
  }
}

/// Feuille d'ajout : poids (virgule acceptée) et date.
class _FeuilleAjout extends StatefulWidget {
  const _FeuilleAjout({required this.maintenant});

  final DateTime maintenant;

  @override
  State<_FeuilleAjout> createState() => _FeuilleAjoutState();
}

class _FeuilleAjoutState extends State<_FeuilleAjout> {
  final _texte = TextEditingController();
  late DateTime _jour = DateTime(
    widget.maintenant.year,
    widget.maintenant.month,
    widget.maintenant.day,
  );
  String? _erreur;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final choix = await showDatePicker(
      context: context,
      initialDate: _jour,
      firstDate: DateTime(widget.maintenant.year - 5),
      lastDate: widget.maintenant,
      locale: const Locale('fr'),
    );
    if (choix != null) setState(() => _jour = choix);
  }

  void _valider(AppLocalizations t) {
    final kg = lireNombre(_texte.text);
    if (kg == null) {
      setState(() => _erreur = t.erreurNombre);
      return;
    }
    if (kg < poidsMin || kg > poidsMax) {
      setState(() => _erreur = t.erreurPlage(poidsMin, poidsMax));
      return;
    }
    final aujourdhui =
        _jour ==
        DateTime(
          widget.maintenant.year,
          widget.maintenant.month,
          widget.maintenant.day,
        );
    // Aujourd'hui : l'heure exacte départage deux pesées du même jour.
    final date = aujourdhui
        ? widget.maintenant
        : DateTime(_jour.year, _jour.month, _jour.day, 12);
    Navigator.of(context).pop((kg: (kg * 10).round() / 10, date: date));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
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
          TextField(
            controller: _texte,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: t.champPoids,
              errorText: _erreur,
            ),
            onChanged: (_) {
              if (_erreur != null) setState(() => _erreur = null);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _choisirDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              '${t.champDate} : ${DateFormat.yMMMd('fr').format(_jour)}',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _valider(t),
            child: Text(t.enregistrer),
          ),
        ],
      ),
    );
  }
}
