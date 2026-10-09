import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'modele.dart';
import 'suivi.dart';

String formaterDuree(AppLocalizations t, Duration d) =>
    t.dureeHeures(d.inHours, (d.inMinutes % 60).toString().padLeft(2, '0'));

/// Carte « Ma journée » de l'accueil (spec santé connectée §5).
class CarteJournee extends StatelessWidget {
  const CarteJournee({
    super.key,
    required this.suivi,
    required this.montre,
    required this.onConnecter,
    required this.onAutoriser,
    this.onDetail,
  });

  final Suivi suivi;
  final bool montre;
  final VoidCallback onConnecter;
  final VoidCallback onAutoriser;
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    final doux = textes.bodyMedium?.copyWith(color: CouleursCoach.texteDoux);

    if (!montre) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: const Icon(Icons.watch_outlined, color: CouleursCoach.vert),
          title: Text(t.connecterMontre, style: textes.titleMedium),
          subtitle: Text(t.connecterMontreAide),
          trailing: const Icon(Icons.chevron_right),
          onTap: onConnecter,
        ),
      );
    }

    final Widget contenu = switch (suivi.etat) {
      EtatSuivi.chargement => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      EtatSuivi.erreur || EtatSuivi.inactif => _Message(
        texte: t.suiviErreur,
        bouton: t.boutonAutoriser,
        onTap: onAutoriser,
      ),
      EtatSuivi.pret when suivi.sansDonnees => _Message(
        texte: t.aucuneDonneeMontre,
        bouton: t.boutonAutoriser,
        onTap: onAutoriser,
      ),
      EtatSuivi.pret => _Statistiques(jour: suivi.aujourdhui),
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(rayonCarte),
        onTap: suivi.etat == EtatSuivi.pret && !suivi.sansDonnees
            ? onDetail
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(t.maJournee, style: textes.titleLarge),
                  const Spacer(),
                  if (onDetail != null &&
                      suivi.etat == EtatSuivi.pret &&
                      !suivi.sansDonnees)
                    Text(t.voirDetail, style: doux),
                ],
              ),
              const SizedBox(height: 12),
              contenu,
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.texte,
    required this.bouton,
    required this.onTap,
  });

  final String texte;
  final String bouton;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(texte),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: onTap, child: Text(bouton)),
    ],
  );
}

class _Statistiques extends StatelessWidget {
  const _Statistiques({required this.jour});

  final JourSante? jour;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final j = jour;
    final kcal = j?.kcalTotales ?? j?.kcalActives;
    final sommeil = j?.sommeil?.endormi;
    String ou(Object? v) => v == null ? '—' : '$v';
    return Column(
      children: [
        Row(
          children: [
            _Stat(Icons.directions_walk, ou(j?.pas), t.statPas),
            _Stat(
              Icons.local_fire_department_outlined,
              ou(kcal?.round()),
              t.statKcal,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stat(
              Icons.bedtime_outlined,
              sommeil == null ? '—' : formaterDuree(t, sommeil),
              t.statSommeil,
            ),
            _Stat(
              Icons.favorite_border,
              ou(j?.fcRepos?.round()),
              t.statFcRepos,
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icone, this.valeur, this.libelle);

  final IconData icone;
  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CouleursCoach.vertClair,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: CouleursCoach.vert, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valeur, style: textes.titleMedium),
                Text(
                  libelle,
                  style: textes.bodySmall?.copyWith(
                    color: CouleursCoach.texteDoux,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
