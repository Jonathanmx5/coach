import 'package:flutter/material.dart';

import '../entrainement/entrainement_repository.dart';
import '../entrainement/modele.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import 'bienetre_repository.dart';
import 'carte_series.dart';
import 'hydratation.dart';
import 'series.dart';

/// Séries des 60 derniers jours. Recréé chaque jour (clé = date).
class BlocSeries extends StatefulWidget {
  const BlocSeries({
    super.key,
    required this.uid,
    required this.poidsKg,
    required this.maintenant,
    required this.journal,
    required this.entrainement,
    required this.bienetre,
  });

  final String uid;
  final double poidsKg;
  final DateTime maintenant;
  final JournalRepository journal;
  final EntrainementRepository entrainement;
  final BienEtreRepository bienetre;

  @override
  State<BlocSeries> createState() => _BlocSeriesState();
}

class _BlocSeriesState extends State<BlocSeries> {
  static const _fenetre = 60;

  late final DateTime _debut = DateTime(
    widget.maintenant.year,
    widget.maintenant.month,
    widget.maintenant.day - _fenetre,
  );
  late final DateTime _fin = DateTime(
    widget.maintenant.year,
    widget.maintenant.month,
    widget.maintenant.day + 1,
  );
  late final Stream<List<Repas>> _repas = widget.journal.repas(
    widget.uid,
    _debut,
    _fin,
  );
  late final Stream<List<SeanceFaite>> _seances = widget.entrainement.seances(
    widget.uid,
  );
  late final Stream<List<EntreeEau>> _eau = widget.bienetre.eau(
    widget.uid,
    _debut,
    _fin,
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Repas>>(
    stream: _repas,
    builder: (context, repas) => StreamBuilder<List<SeanceFaite>>(
      stream: _seances,
      builder: (context, seances) => StreamBuilder<List<EntreeEau>>(
        stream: _eau,
        builder: (context, eau) => CarteSeries(
          journal: serieEnCours(
            joursDe((repas.data ?? const []).map((r) => r.date)),
            widget.maintenant,
          ),
          entrainement: serieEnCours(
            joursDe((seances.data ?? const []).map((s) => s.date)),
            widget.maintenant,
          ),
          eau: serieEnCours(
            joursEauAtteinte(
              eau.data ?? const [],
              objectifEauMl(poidsKg: widget.poidsKg),
            ),
            widget.maintenant,
          ),
        ),
      ),
    ),
  );
}
