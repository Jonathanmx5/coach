import 'package:flutter/material.dart';

import '../entrainement/entrainement_repository.dart';
import '../entrainement/semaine.dart';
import '../journal/journal_repository.dart';
import 'bienetre_repository.dart';
import 'carte_series.dart';
import 'hydratation.dart';
import 'series.dart';

/// Fenêtres de lecture des séries, en jours avant aujourd'hui : on lit
/// d'abord une semaine, et on n'élargit que si la série remonte jusqu'au
/// début de la fenêtre. Une série courte ne coûte donc que quelques lectures.
const paliersSeries = [7, 30, 90, 365];

/// Séries du journal, des séances et de l'eau. Recréé chaque jour (clé =
/// date).
class BlocSeries extends StatelessWidget {
  const BlocSeries({
    super.key,
    required this.uid,
    required this.poidsKg,
    required this.joursParSemaine,
    required this.maintenant,
    required this.journal,
    required this.entrainement,
    required this.bienetre,
  });

  final String uid;
  final double poidsKg;
  final int joursParSemaine;
  final DateTime maintenant;
  final JournalRepository journal;
  final EntrainementRepository entrainement;
  final BienEtreRepository bienetre;

  @override
  Widget build(BuildContext context) => SerieParPaliers(
    maintenant: maintenant,
    lire: (debut, fin) => journal
        .repas(uid, debut, fin)
        .map((l) => joursDe(l.map((r) => r.date))),
    builder: (context, serieJournal) => SerieParPaliers(
      maintenant: maintenant,
      // Les jours de repos du programme ne coupent pas la série.
      joursPrevus: joursPrevus(joursParSemaine),
      lire: (debut, _) => entrainement
          .seances(uid, depuis: debut)
          .map((l) => joursDe(l.map((s) => s.date))),
      builder: (context, serieSeances) => SerieParPaliers(
        maintenant: maintenant,
        lire: (debut, fin) => bienetre
            .eau(uid, debut, fin)
            .map((l) => joursEauAtteinte(l, objectifEauMl(poidsKg: poidsKg))),
        builder: (context, serieEau) => CarteSeries(
          journal: serieJournal,
          entrainement: serieSeances,
          eau: serieEau,
        ),
      ),
    ),
  );
}

/// Une série lue par paliers ([paliersSeries]) : [lire] donne les jours
/// faits entre `debut` et `fin` (demain, exclu).
class SerieParPaliers extends StatefulWidget {
  const SerieParPaliers({
    super.key,
    required this.maintenant,
    required this.lire,
    required this.builder,
    this.joursPrevus,
  });

  final DateTime maintenant;
  final Stream<Set<DateTime>> Function(DateTime debut, DateTime fin) lire;
  final Set<int>? joursPrevus;
  final Widget Function(BuildContext context, int serie) builder;

  @override
  State<SerieParPaliers> createState() => _SerieParPaliersState();
}

class _SerieParPaliersState extends State<SerieParPaliers> {
  var _palier = 0;
  var _elargissement = false;
  late Stream<Set<DateTime>> _flux = _lire();

  DateTime get _debut => DateTime(
    widget.maintenant.year,
    widget.maintenant.month,
    widget.maintenant.day - paliersSeries[_palier],
  );

  Stream<Set<DateTime>> _lire() => widget.lire(
    _debut,
    DateTime(
      widget.maintenant.year,
      widget.maintenant.month,
      widget.maintenant.day + 1,
    ),
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<Set<DateTime>>(
    stream: _flux,
    builder: (context, snap) {
      final serie = serieSurFenetre(
        snap.data ?? const {},
        widget.maintenant,
        debut: _debut,
        joursPrevus: widget.joursPrevus,
      );
      // La série touche le début de la fenêtre : elle continue peut-être
      // avant, on lit le palier suivant (le chiffre affiché, déjà juste
      // sur la fenêtre, ne fait que grandir).
      if (snap.connectionState == ConnectionState.active &&
          serie.tronquee &&
          _palier < paliersSeries.length - 1 &&
          !_elargissement) {
        _elargissement = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _elargissement = false;
            _palier++;
            _flux = _lire();
          });
        });
      }
      return widget.builder(context, serie.jours);
    },
  );
}
