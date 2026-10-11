import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../bienetre/bienetre_repository.dart';
import '../bienetre/hydratation.dart';
import '../bienetre/suivi_meteo.dart';
import '../journal/calculs.dart';
import '../journal/journal_repository.dart';
import '../journal/modele.dart';
import '../l10n/app_localizations.dart';
import '../profil/besoins.dart';
import '../profil/modele.dart';
import '../sante/suivi.dart';
import '../theme.dart';

/// Couleurs des anneaux, celles de l'application, sur un fond vert très clair :
/// vert pour le sport (vert profond pour les calories brûlées, vert moyen pour
/// les protéines, qui font le muscle), orange pour l'assiette, bleu pour l'eau.
const _cBrule = CouleursCoach.vert;
const _cMange = CouleursCoach.orange;
const _cProteines = CouleursCoach.vertMoyen;
const _cEau = CouleursCoach.bleu;
const _fond = CouleursCoach.vertClair;

/// Quatre anneaux concentriques : de l'extérieur vers l'intérieur, calories
/// brûlées, calories mangées, protéines, eau. Chaque valeur va de 0 à 1 ;
/// au-delà de 1 l'anneau reste fermé.
class Anneaux extends StatelessWidget {
  const Anneaux({
    super.key,
    required this.progres,
    this.taille = 230,
    this.centre,
  });

  /// Dans l'ordre : brûlées, mangées, protéines, eau.
  final List<double> progres;
  final double taille;

  /// Affiché au milieu des anneaux.
  final Widget? centre;

  static const couleurs = [_cBrule, _cMange, _cProteines, _cEau];

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: taille,
    child: Stack(
      alignment: Alignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            size: Size.square(taille),
            painter: _AnneauxPainter([
              for (final p in progres) p.clamp(0.0, 1.0) * t,
            ], couleurs),
          ),
        ),
        ?centre,
      ],
    ),
  );
}

class _AnneauxPainter extends CustomPainter {
  _AnneauxPainter(this.valeurs, this.couleurs);

  final List<double> valeurs;
  final List<Color> couleurs;

  @override
  void paint(Canvas canvas, Size size) {
    const epaisseur = 16.0;
    const ecart = 3.0;
    final centre = size.center(Offset.zero);
    for (var i = 0; i < valeurs.length; i++) {
      final rayon = size.width / 2 - epaisseur / 2 - i * (epaisseur + ecart);
      final rect = Rect.fromCircle(center: centre, radius: rayon);
      final piste = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..color = couleurs[i].withValues(alpha: 0.22);
      canvas.drawCircle(centre, rayon, piste);
      if (valeurs[i] <= 0) continue;
      final trait = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = epaisseur
        ..strokeCap = StrokeCap.round
        ..color = couleurs[i];
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * valeurs[i],
        false,
        trait,
      );
    }
  }

  @override
  bool shouldRepaint(_AnneauxPainter ancien) =>
      !listEquals(ancien.valeurs, valeurs);
}

/// Calories brûlées jusqu'à maintenant : le total de la montre s'il existe,
/// sinon le métabolisme de base × 1,2 au prorata de la journée écoulée ; plus
/// les activités saisies que la montre n'a pas comptées.
double kcalBruleesJusquaMaintenant({
  required int depenseBase,
  required double? kcalMontre,
  required double kcalActivites,
  required DateTime maintenant,
}) {
  final ecoule = (maintenant.hour * 60 + maintenant.minute) / 1440;
  final corps = (kcalMontre ?? 0) > 0
      ? kcalMontre!
      : depenseBase * 1.2 * ecoule;
  return corps + kcalActivites;
}

/// « Aujourd'hui » à la Apple : anneaux et quatre lignes de chiffres.
class CarteAujourdhui extends StatefulWidget {
  const CarteAujourdhui({
    super.key,
    required this.uid,
    required this.profil,
    required this.suivi,
    required this.journal,
    required this.bienetre,
    required this.meteoSuivi,
    required this.horloge,
    required this.onOnglet,
  });

  final String uid;
  final Profil profil;
  final Suivi suivi;
  final JournalRepository journal;
  final BienEtreRepository bienetre;
  final SuiviMeteo meteoSuivi;
  final DateTime Function() horloge;

  /// Ouvre un onglet de la barre du bas (1 Repas, 2 Sport, 3 Poids, 4 Bien-être).
  final ValueChanged<int> onOnglet;

  @override
  State<CarteAujourdhui> createState() => _CarteAujourdhuiState();
}

class _CarteAujourdhuiState extends State<CarteAujourdhui> {
  late final DateTime _jour = DateTime(
    widget.horloge().year,
    widget.horloge().month,
    widget.horloge().day,
  );
  late final DateTime _demain = DateTime(
    _jour.year,
    _jour.month,
    _jour.day + 1,
  );
  late final Stream<List<Repas>> _repas = widget.journal.repas(
    widget.uid,
    _jour,
    _demain,
  );
  late final Stream<List<Activite>> _activites = widget.journal.activites(
    widget.uid,
    _jour,
    _demain,
  );
  late final Stream<List<EntreeEau>> _eau = widget.bienetre.eau(
    widget.uid,
    _jour,
    _demain,
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Repas>>(
    stream: _repas,
    builder: (context, repas) => StreamBuilder<List<Activite>>(
      stream: _activites,
      builder: (context, activites) => StreamBuilder<List<EntreeEau>>(
        stream: _eau,
        builder: (context, eau) => ListenableBuilder(
          listenable: Listenable.merge([widget.suivi, widget.meteoSuivi]),
          builder: (context, _) => _contenu(
            context,
            repas.data ?? const [],
            activites.data ?? const [],
            eau.data ?? const [],
          ),
        ),
      ),
    ),
  );

  Widget _contenu(
    BuildContext context,
    List<Repas> repas,
    List<Activite> activites,
    List<EntreeEau> eau,
  ) {
    final t = AppLocalizations.of(context)!;
    final maintenant = widget.horloge();
    final jourSante = widget.suivi.jours
        .where((j) => j.jour == _jour)
        .firstOrNull;
    final reperes = calculerReperes(
      widget.profil,
      maintenant: maintenant,
      maintienMesure: widget.suivi.maintien,
    );

    final manuelles = kcalActivitesNonComptees(
      activites,
      jourSante?.seances ?? const [],
    );
    final seancesMontre = jourSante == null
        ? 0.0
        : (jourSante.kcalActives ??
              jourSante.seances.fold<double>(0, (s, x) => s + (x.kcal ?? 0)));
    final cibles = ciblesDuJour(
      reperes,
      kcalExercice: manuelles + seancesMontre,
    );

    final brulees = kcalBruleesJusquaMaintenant(
      depenseBase: reperes.depenseBase,
      kcalMontre: jourSante?.kcalTotales,
      kcalActivites: manuelles,
      maintenant: maintenant,
    );
    final objectifBrule = reperes.maintien.toDouble();
    final macros = totalMacros(repas);
    final objectifEau = objectifEauMl(
      poidsKg: widget.profil.poidsKg,
      minutesEffort: activites.fold<int>(0, (s, a) => s + a.minutes),
      tempMaxC: widget.meteoSuivi.temperature,
    );
    final bu = totalEauMl(eau);
    final mesure = (jourSante?.kcalTotales ?? 0) > 0;

    double part(double v, double objectif) => objectif <= 0 ? 0 : v / objectif;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: _fond,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              t.anneauxTitre,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: CouleursCoach.texte,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Anneaux(
            centre: _Bilan(net: macros.kcal - brulees),
            progres: [
              part(brulees, objectifBrule),
              part(macros.kcal, cibles.kcal),
              part(macros.proteines, cibles.proteines),
              part(bu.toDouble(), objectifEau.toDouble()),
            ],
          ),
          const SizedBox(height: 12),
          _Ligne(
            couleur: _cBrule,
            libelle: t.libBrule,
            sous: mesure ? t.sourceMesure : t.sourceEstimeJusqua,
            valeur: '${brulees.round()}',
            objectif: '${objectifBrule.round()}',
            unite: 'kcal',
            onTap: () => widget.onOnglet(2),
          ),
          _Ligne(
            couleur: _cMange,
            libelle: t.libMange,
            sous: t.objectifDuJour,
            valeur: '${macros.kcal.round()}',
            objectif: '${cibles.kcal.round()}',
            unite: 'kcal',
            onTap: () => widget.onOnglet(1),
          ),
          _Ligne(
            couleur: _cProteines,
            libelle: t.libProteines,
            sous: t.objectifDuJour,
            valeur: '${macros.proteines.round()}',
            objectif: '${cibles.proteines.round()}',
            unite: 'g',
            onTap: () => widget.onOnglet(1),
          ),
          _Ligne(
            couleur: _cEau,
            libelle: t.libEau,
            sous: widget.meteoSuivi.temperature == null
                ? t.objectifDuJour
                : t.eauChaleur(widget.meteoSuivi.temperature!.round()),
            valeur: _litres(bu),
            objectif: _litres(objectifEau),
            unite: 'L',
            onTap: () => widget.onOnglet(4),
          ),
        ],
      ),
    );
  }
}

/// Calories mangées moins calories brûlées : négatif = déficit.
String bilanTexte(double net) {
  final n = net.round();
  if (n == 0) return '0';
  return n > 0 ? '+$n' : '\u2212${-n}';
}

class _Bilan extends StatelessWidget {
  const _Bilan({required this.net});

  final double net;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          bilanTexte(net),
          style: textes.titleLarge?.copyWith(
            color: CouleursCoach.texte,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          t.bilanCentre,
          style: textes.labelSmall?.copyWith(color: CouleursCoach.texteDoux),
        ),
      ],
    );
  }
}

String _litres(int ml) => (ml / 1000).toStringAsFixed(2).replaceAll('.', ',');

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.couleur,
    required this.libelle,
    required this.sous,
    required this.valeur,
    required this.objectif,
    required this.unite,
    required this.onTap,
  });

  final Color couleur;
  final String libelle;
  final String sous;
  final String valeur;
  final String objectif;
  final String unite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: BoxDecoration(
                color: couleur,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libelle,
                    style: textes.titleSmall?.copyWith(
                      color: CouleursCoach.texte,
                    ),
                  ),
                  Text(
                    sous,
                    style: textes.bodySmall?.copyWith(
                      color: CouleursCoach.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: valeur,
                    style: textes.headlineSmall?.copyWith(
                      color: couleur,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' / $objectif $unite',
                    style: textes.bodyMedium?.copyWith(
                      color: CouleursCoach.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
