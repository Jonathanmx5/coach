import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../profil/modele.dart';
import '../theme.dart';
import 'ajustement.dart';
import 'analyse_photo.dart';
import 'calculs.dart';
import 'formulaires.dart';
import 'modele.dart';
import 'photo_repas_page.dart';
import 'photos_repas.dart';
import 'signalement.dart';
import 'verdict.dart';

/// Un repas du journal : l'analyse telle qu'elle avait été enregistrée
/// (carton du coach, aliments et portions), ou un simple résumé pour un repas
/// saisi à la main. On peut y corriger les portions et le moment du repas :
/// les calories et le verdict sont alors recalculés.
class DetailRepasPage extends StatefulWidget {
  const DetailRepasPage({
    super.key,
    required this.repas,
    required this.dejaMange,
    required this.cibles,
    required this.objectif,
    required this.photos,
    required this.onModifier,
  });

  final Repas repas;

  /// Le reste de la journée, sans ce repas.
  final Macros dejaMange;
  final CiblesJour cibles;
  final Objectif objectif;
  final PhotosRepas photos;

  /// Enregistre le repas corrigé.
  final Future<void> Function(Repas repas) onModifier;

  @override
  State<DetailRepasPage> createState() => _DetailRepasPageState();
}

class _DetailRepasPageState extends State<DetailRepasPage> {
  late List<AlimentEstime> _aliments = widget.repas.aliments;
  late Moment _moment = widget.repas.moment;
  bool _portionsChangees = false;

  /// L'écart entre les apports enregistrés et la somme des aliments (une
  /// correction faite à la main plus tôt), puis celui d'à présent.
  late final Ajustement _initial = Ajustement.entre(
    widget.repas.macros,
    totalAliments(widget.repas.aliments),
  );
  late Ajustement _ajustement = _initial;

  /// Vrai dès le premier appui sur « Enregistrer » : les suivants sont ignorés.
  bool _enregistrement = false;

  /// La photo, lue une seule fois (pas à chaque appui sur + ou −).
  late final Future<Uint8List?>? _photo = widget.repas.photoId == null
      ? null
      : widget.photos.lire(widget.repas.photoId!);

  /// Vrai quand les apports ne sont plus ceux qui sont enregistrés.
  bool get _apportsChanges => _portionsChangees || _ajustement != _initial;

  bool get _modifie => _apportsChanges || _moment != widget.repas.moment;

  /// Les apports : recalculés si les portions ou les valeurs ont bougé.
  Macros get _macros => !_apportsChanges || _aliments.isEmpty
      ? widget.repas.macros
      : _ajustement.appliquer(totalAliments(_aliments));

  static double? _somme(
    List<AlimentEstime> l,
    double? Function(AlimentEstime) f,
  ) {
    final valeurs = [for (final a in l) f(a)].whereType<double>();
    return valeurs.isEmpty ? null : valeurs.fold<double>(0, (s, v) => s + v);
  }

  /// Sucres et saturés des aliments, mis à l'échelle des glucides et lipides
  /// affichés (corrigés à la main ou non).
  ({double? sucres, double? satures}) get _parts {
    final base = totalAliments(_aliments);
    final m = _macros;
    return (
      sucres: partCorrigee(
        _somme(_aliments, (a) => a.sucres),
        avant: base.glucides,
        apres: m.glucides,
      ),
      satures: partCorrigee(
        _somme(_aliments, (a) => a.satures),
        avant: base.lipides,
        apres: m.lipides,
      ),
    );
  }

  Verdict _calculerVerdict() => verdictRepas(
    repas: _macros,
    sucres: _parts.sucres,
    satures: _parts.satures,
    dejaMange: widget.dejaMange,
    cibles: widget.cibles,
    objectif: widget.objectif,
  );

  /// ±10 % de la portion, arrondi à 5 g (au moins 5 g d'écart). Un appui
  /// sans effet (déjà au minimum) ne compte pas comme une modification.
  void _ajuster(int i, int sens) {
    final g = _aliments[i].grammes;
    final nouveau = portionSuivante(g, sens);
    if (nouveau == g) return;
    setState(() {
      _aliments = [..._aliments]..[i] = _aliments[i].avecGrammes(nouveau);
      _portionsChangees = true;
      // La correction des tuiles reste dans les bornes du nouveau total.
      _ajustement = _ajustement.reborne(totalAliments(_aliments));
    });
  }

  void _enregistrer() {
    if (_enregistrement) return;
    _enregistrement = true;
    final r = widget.repas;
    final t = AppLocalizations.of(context)!;
    final messager = ScaffoldMessenger.of(context);
    final ecriture = widget.onModifier(
      Repas(
        id: r.id,
        date: r.date,
        moment: _moment,
        nom: _portionsChangees ? nomDuRepas(_aliments) : r.nom,
        macros: _macros,
        source: r.source,
        description: r.description,
        aliments: _aliments,
        photoId: r.photoId,
        // Le jugement est refait seulement si les apports ont changé.
        verdict: _apportsChanges && _aliments.isNotEmpty
            ? _calculerVerdict()
            : r.verdict,
      ),
    );
    // Hors ligne, l'accusé du serveur n'arrive qu'au retour du réseau : on
    // ne l'attend pas, le cache local est déjà à jour. Un refus est signalé.
    unawaited(
      ecriture.catchError((Object e, StackTrace s) {
        signalerErreur(e, s);
        if (e is FirebaseException && e.code == 'permission-denied') {
          messager.showSnackBar(SnackBar(content: Text(t.modificationRefusee)));
        }
      }),
    );
    if (ModalRoute.of(context)?.isCurrent == true) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final repas = widget.repas;
    final aliments = _aliments;

    return Scaffold(
      appBar: AppBar(title: Text(libelleMoment(t, _moment))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            DateFormat('EEEE d MMMM · HH:mm', 'fr').format(repas.date),
            style: textes.bodySmall?.copyWith(color: context.palette.texteDoux),
          ),
          const SizedBox(height: 12),
          if (_photo != null)
            FutureBuilder<Uint8List?>(
              future: _photo,
              builder: (_, snap) {
                final octets = snap.data;
                if (octets == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(rayonCarte),
                    child: Image.memory(
                      octets,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
          if (aliments.isEmpty) ...[
            Text(repas.nom, style: textes.titleLarge),
            const SizedBox(height: 8),
            Text(
              t.recapValeur(
                repas.macros.kcal.round(),
                repas.macros.proteines.round(),
              ),
              style: textes.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              t.repasSansAnalyse,
              style: textes.bodySmall?.copyWith(
                color: context.palette.texteDoux,
              ),
            ),
          ] else ...[
            CarteVerdict(
              description: repas.description,
              repas: _macros,
              sucres: _parts.sucres,
              satures: _parts.satures,
              // Le jugement de l'époque ; refait si on change les portions, ou
              // pour un ancien repas qui n'en avait pas.
              onAjuster: (champ, sens) => setState(
                () => _ajustement = _ajustement.avec(
                  champ,
                  sens,
                  totalAliments(_aliments),
                ),
              ),
              verdict: _apportsChanges
                  ? _calculerVerdict()
                  : (repas.verdict ?? _calculerVerdict()),
            ),
            const SizedBox(height: 20),
            Text(t.composition, style: textes.titleMedium),
            for (var i = 0; i < aliments.length; i++)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  title: Text(aliments[i].nom),
                  subtitle: Text(
                    t.portionGrammes(
                          aliments[i].grammes.round(),
                          aliments[i].macros.kcal.round(),
                        ) +
                        (aliments[i].aFourchette
                            ? '\n${t.fourchetteGrammes(aliments[i].grammesMin!.round(), aliments[i].grammesMax!.round())}'
                            : ''),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (aliments[i].aVerifier)
                        Text(
                          t.aVerifier,
                          style: textes.labelSmall?.copyWith(
                            color: context.palette.orangeFonce,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      IconButton(
                        tooltip: t.ajusterMoins(aliments[i].nom),
                        onPressed: () => _ajuster(i, -1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        tooltip: t.ajusterPlus(aliments[i].nom),
                        onPressed: () => _ajuster(i, 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              for (final m in Moment.values)
                ChoiceChip(
                  label: Text(libelleMoment(t, m)),
                  selected: m == _moment,
                  onSelected: (_) => setState(() => _moment = m),
                ),
            ],
          ),
          if (_modifie) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _enregistrer,
              child: Text(t.enregistrerModifications),
            ),
          ],
        ],
      ),
    );
  }
}
