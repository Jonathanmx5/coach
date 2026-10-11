import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../profil/modele.dart';
import '../theme.dart';
import 'analyse_photo.dart';
import 'calculs.dart';
import 'formulaires.dart';
import 'modele.dart';
import 'photo_repas_page.dart';
import 'photos_repas.dart';
import 'verdict.dart';

/// Un repas du journal : l'analyse telle qu'elle avait été enregistrée
/// (carton du coach, aliments et portions), ou un simple résumé pour un repas
/// saisi à la main.
class DetailRepasPage extends StatelessWidget {
  const DetailRepasPage({
    super.key,
    required this.repas,
    required this.dejaMange,
    required this.cibles,
    required this.objectif,
    required this.photos,
  });

  final Repas repas;

  /// Le reste de la journée, sans ce repas.
  final Macros dejaMange;
  final CiblesJour cibles;
  final Objectif objectif;
  final PhotosRepas photos;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final aliments = repas.aliments;
    double? somme(double? Function(AlimentEstime) f) {
      final valeurs = [for (final a in aliments) f(a)].whereType<double>();
      return valeurs.isEmpty ? null : valeurs.fold<double>(0, (s, v) => s + v);
    }

    return Scaffold(
      appBar: AppBar(title: Text(libelleMoment(t, repas.moment))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            DateFormat('EEEE d MMMM · HH:mm', 'fr').format(repas.date),
            style: textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux),
          ),
          const SizedBox(height: 12),
          if (repas.photoId != null)
            FutureBuilder<Uint8List?>(
              future: photos.lire(repas.photoId!),
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
              style: textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux),
            ),
          ] else ...[
            CarteVerdict(
              description: repas.description,
              repas: repas.macros,
              sucres: somme((a) => a.sucres),
              satures: somme((a) => a.satures),
              // Le jugement de l'époque ; à défaut (ancien repas), recalculé.
              verdict:
                  repas.verdict ??
                  verdictRepas(
                    repas: repas.macros,
                    sucres: somme((a) => a.sucres),
                    satures: somme((a) => a.satures),
                    dejaMange: dejaMange,
                    cibles: cibles,
                    objectif: objectif,
                  ),
            ),
            const SizedBox(height: 20),
            Text(t.composition, style: textes.titleMedium),
            for (final a in aliments)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  title: Text(a.nom),
                  subtitle: Text(
                    t.portionGrammes(a.grammes.round(), a.macros.kcal.round()),
                  ),
                  trailing: a.aVerifier
                      ? Text(
                          t.aVerifier,
                          style: textes.labelSmall?.copyWith(
                            color: CouleursCoach.orangeFonce,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
