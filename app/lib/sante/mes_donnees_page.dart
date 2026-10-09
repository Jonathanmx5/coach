import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'agregation.dart';
import 'modele.dart';
import 'suivi.dart';

/// Détail des mesures Health Connect sur 7 ou 30 jours (spec santé §5).
class MesDonneesPage extends StatefulWidget {
  const MesDonneesPage({super.key, required this.suivi});

  final Suivi suivi;

  @override
  State<MesDonneesPage> createState() => _MesDonneesPageState();
}

class _MesDonneesPageState extends State<MesDonneesPage> {
  int _periode = 7;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final tous = widget.suivi.jours;
    final jours = tous.length <= _periode
        ? tous
        : tous.sublist(tous.length - _periode);

    List<double?> serie(double? Function(JourSante j) valeur) => [
      for (final j in jours) valeur(j),
    ];
    List<double?> parJour(List<Mesure> mesures) => [
      for (final j in jours)
        mesures
            .where((m) => jourDe(m.date) == j.jour)
            .map((m) => m.valeur)
            .lastOrNull,
    ];

    final sections = <(String, List<Widget>)>[
      (
        t.sectionActivite,
        [
          ?_graphe('pas', t.mesurePas, serie((j) => j.pas?.toDouble())),
          ?_graphe('kcal', t.mesureKcalActives, serie((j) => j.kcalActives)),
          ?_graphe(
            'distance',
            t.mesureDistance,
            serie((j) => j.distanceM == null ? null : j.distanceM! / 1000),
            decimales: 1,
          ),
          ?_graphe(
            'etages',
            t.mesureEtages,
            serie((j) => j.etages?.toDouble()),
          ),
        ],
      ),
      (t.sectionSommeil, [?_grapheSommeil(t, jours)]),
      (
        t.sectionCoeur,
        [
          ?_graphe(
            'fc-repos',
            t.mesureFcRepos,
            serie((j) => j.fcRepos),
            ligne: true,
          ),
          ?_graphe(
            'variabilite',
            t.mesureVariabilite,
            serie((j) => j.variabiliteMs),
            ligne: true,
          ),
          ?_graphe('spo2', t.mesureSpo2, serie((j) => j.spo2), ligne: true),
          ?_graphe(
            'freq-resp',
            t.mesureFreqResp,
            serie((j) => j.freqResp),
            ligne: true,
            decimales: 1,
          ),
        ],
      ),
      (
        t.sectionCorps,
        [
          ?_graphe(
            'poids',
            t.mesurePoids,
            parJour(widget.suivi.pesees),
            ligne: true,
            decimales: 1,
          ),
          ?_graphe(
            'masse-grasse',
            t.mesureMasseGrasse,
            parJour(widget.suivi.masseGrasse),
            ligne: true,
            decimales: 1,
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t.mesDonnees)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 7, label: Text(t.periode7)),
              ButtonSegment(value: 30, label: Text(t.periode30)),
            ],
            selected: {_periode},
            onSelectionChanged: (s) => setState(() => _periode = s.first),
          ),
          for (final (titre, graphes) in sections) ...[
            const SizedBox(height: 24),
            Text(titre, style: textes.titleLarge),
            const SizedBox(height: 12),
            if (graphes.isEmpty)
              Text(
                t.aucuneDonneePeriode,
                style: textes.bodyMedium?.copyWith(
                  color: CouleursCoach.texteDoux,
                ),
              )
            else
              for (final g in graphes) ...[g, const SizedBox(height: 12)],
          ],
        ],
      ),
    );
  }

  /// Un graphe par mesure ; null si la mesure est absente de la période.
  Widget? _graphe(
    String cle,
    String titre,
    List<double?> valeurs, {
    bool ligne = false,
    int decimales = 0,
  }) {
    if (valeurs.every((v) => v == null)) return null;
    final derniere = valeurs.lastWhere((v) => v != null)!;
    final graphe = ligne
        ? LineChart(
            key: ValueKey('graphe-$cle'),
            LineChartData(
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < valeurs.length; i++)
                      if (valeurs[i] != null) FlSpot(i.toDouble(), valeurs[i]!),
                  ],
                  color: CouleursCoach.vert,
                  barWidth: 3,
                  isCurved: true,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          )
        : BarChart(
            key: ValueKey('graphe-$cle'),
            BarChartData(
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < valeurs.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: valeurs[i] ?? 0,
                        color: CouleursCoach.vert,
                        width: valeurs.length > 10 ? 5 : 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          );
    return _Cadre(
      titre: titre,
      sousTitre: AppLocalizations.of(context)!
          .derniereValeur(derniere.toStringAsFixed(decimales)),
      graphe: graphe,
    );
  }

  /// Barres empilées : profond, léger, paradoxal (en heures).
  Widget? _grapheSommeil(AppLocalizations t, List<JourSante> jours) {
    if (jours.every((j) => j.sommeil == null)) return null;
    double h(Duration d) => d.inMinutes / 60;
    final derniere = jours.lastWhere((j) => j.sommeil != null).sommeil!;
    const couleurs = (
      profond: CouleursCoach.vertFonce,
      leger: CouleursCoach.vertMoyen,
      paradoxal: CouleursCoach.orange,
    );
    return _Cadre(
      titre: t.mesureSommeil,
      sousTitre: t.derniereValeur(
        '${derniere.endormi.inHours} h '
        '${(derniere.endormi.inMinutes % 60).toString().padLeft(2, '0')}',
      ),
      legende: [
        (t.phaseProfond, couleurs.profond),
        (t.phaseLeger, couleurs.leger),
        (t.phaseParadoxal, couleurs.paradoxal),
      ],
      graphe: BarChart(
        key: const ValueKey('graphe-sommeil'),
        BarChartData(
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < jours.length; i++)
              _barreSommeil(i, jours[i].sommeil, jours.length, couleurs, h),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _barreSommeil(
    int x,
    ResumeSommeil? s,
    int nombre,
    ({Color profond, Color leger, Color paradoxal}) couleurs,
    double Function(Duration) h,
  ) {
    final largeur = nombre > 10 ? 5.0 : 14.0;
    if (s == null) {
      return BarChartGroupData(
        x: x,
        barRods: [BarChartRodData(toY: 0, width: largeur)],
      );
    }
    if (!s.aDesPhases) {
      return BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: h(s.endormi),
            color: couleurs.leger,
            width: largeur,
          ),
        ],
      );
    }
    final p = h(s.profond), l = h(s.leger), r = h(s.paradoxal);
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: p + l + r,
          width: largeur,
          rodStackItems: [
            BarChartRodStackItem(0, p, couleurs.profond),
            BarChartRodStackItem(p, p + l, couleurs.leger),
            BarChartRodStackItem(p + l, p + l + r, couleurs.paradoxal),
          ],
        ),
      ],
    );
  }
}

class _Cadre extends StatelessWidget {
  const _Cadre({
    required this.titre,
    required this.sousTitre,
    required this.graphe,
    this.legende = const [],
  });

  final String titre;
  final String sousTitre;
  final Widget graphe;
  final List<(String, Color)> legende;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: textes.titleMedium),
            Text(
              sousTitre,
              style: textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 120, child: graphe),
            if (legende.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  for (final (nom, couleur) in legende)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, color: couleur),
                        const SizedBox(width: 4),
                        Text(nom, style: textes.bodySmall),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
