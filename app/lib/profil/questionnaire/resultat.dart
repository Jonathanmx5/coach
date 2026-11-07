import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../format.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../besoins.dart';
import '../garde_fous.dart';
import '../modele.dart';
import 'etapes.dart';

/// Écran de résultat à la fin du questionnaire : objectif retenu, cible
/// calorique, protéines, rythme attendu et, avec un poids visé, date
/// estimée.
class ResultatQuestionnaire extends StatelessWidget {
  const ResultatQuestionnaire({
    super.key,
    required this.profil,
    required this.reperes,
    required this.maintenant,
    this.objectifDemande,
  });

  /// Profil final, garde-fous appliqués.
  final Profil profil;
  final Reperes reperes;
  final DateTime maintenant;

  /// Objectif choisi dans le questionnaire : s'il diffère de celui du
  /// profil, la raison du changement est rappelée.
  final Objectif? objectifDemande;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final petit = theme.textTheme.bodyMedium?.copyWith(
      color: context.palette.texteDoux,
    );
    final rythme = rythmeKgParSemaine(reperes);
    final cible = profil.poidsCibleKg;
    final date = dateEstimee(
      poidsKg: profil.poidsKg,
      poidsCibleKg: cible,
      rythme: rythme,
      maintenant: maintenant,
    );
    final refus =
        objectifDemande == Objectif.perte && profil.objectif != Objectif.perte
        ? refusPerte(
            profil.copyWith(objectif: Objectif.perte),
            maintenant: maintenant,
          )
        : null;
    final libelle = estRecomposition(profil)
        ? t.objectifRecomposition
        : libelleObjectif(t, profil.objectif);
    final kg = formatDecimal(rythme.abs());

    Widget chiffre(String valeur, String legende) => Expanded(
      child: Column(
        children: [
          Text(
            valeur,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.palette.vertFonce,
            ),
          ),
          Text(legende, textAlign: TextAlign.center, style: petit),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.objectifPastille(libelle.toLowerCase()),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: context.palette.vertClair,
            borderRadius: BorderRadius.circular(rayonCarte),
          ),
          child: Row(
            children: [
              chiffre('${reperes.kcalCible}', t.reperesKcalLabel),
              chiffre(
                t.reperesProteinesValeur(reperes.proteinesG),
                t.reperesProteinesLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(t.resultatMaintien(reperes.maintien)),
        const SizedBox(height: 8),
        Text(
          rythme <= -rythmeStable
              ? t.resultatRythmePerte(kg)
              : rythme >= rythmeStable
              ? t.resultatRythmePrise(kg)
              : t.resultatRythmeStable,
        ),
        if (cible != null) ...[
          const SizedBox(height: 8),
          Text(
            date == null
                ? t.resultatSansDate(formatDecimal(cible))
                : t.resultatDate(
                    formatDecimal(cible),
                    DateFormat.yMMMMd('fr').format(date),
                  ),
          ),
        ],
        if (estRecomposition(profil)) ...[
          const SizedBox(height: 16),
          EncadreInfo(t.messageRecomposition),
        ],
        if (refus != null) ...[
          const SizedBox(height: 16),
          EncadreAlerte(switch (refus) {
            RefusPerte.sante => t.messagePerteGrossesse,
            RefusPerte.imcBas => t.messagePerteImc,
            RefusPerte.plancher => t.messagePertePlancher,
          }),
        ],
        const SizedBox(height: 16),
        Text('${t.reperesEstimation} ${t.resultatAide}', style: petit),
        const SizedBox(height: 4),
        Text(t.mentionMedicale, style: petit),
      ],
    );
  }
}
