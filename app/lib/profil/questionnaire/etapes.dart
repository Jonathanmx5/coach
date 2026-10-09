import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../modele.dart';
import '../../theme.dart';
import 'controleur.dart';

/// Carte de choix pleine largeur, avec icône et sous-titre facultatif.
class CarteChoix extends StatelessWidget {
  const CarteChoix({
    super.key,
    required this.titre,
    this.sousTitre,
    this.icone,
    required this.selectionne,
    required this.onTap,
  });

  final String titre;
  final String? sousTitre;
  final IconData? icone;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Cadre(
    selectionne: selectionne,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (icone != null) ...[
            _Icone(icone!, selectionne),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: _styleTitre(context, selectionne)),
                if (sousTitre != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sousTitre!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: CouleursCoach.texteDoux),
                  ),
                ],
              ],
            ),
          ),
          if (selectionne)
            const Icon(Icons.check_circle, color: CouleursCoach.vert),
        ],
      ),
    ),
  );
}

/// Tuile carrée de choix (grille de deux colonnes).
class TuileChoix extends StatelessWidget {
  const TuileChoix({
    super.key,
    required this.titre,
    required this.icone,
    required this.selectionne,
    required this.onTap,
  });

  final String titre;
  final IconData icone;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Cadre(
    selectionne: selectionne,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Column(
        children: [
          _Icone(icone, selectionne, taille: 52),
          const SizedBox(height: 12),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: _styleTitre(context, selectionne),
          ),
        ],
      ),
    ),
  );
}

TextStyle? _styleTitre(BuildContext context, bool selectionne) =>
    Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: selectionne ? FontWeight.w700 : FontWeight.w500,
      color: selectionne ? CouleursCoach.vertFonce : CouleursCoach.texte,
    );

class _Cadre extends StatelessWidget {
  const _Cadre({
    required this.selectionne,
    required this.onTap,
    required this.child,
  });

  final bool selectionne;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    decoration: BoxDecoration(
      color: selectionne ? CouleursCoach.vertClair : Colors.white,
      borderRadius: BorderRadius.circular(rayonCarte),
      border: Border.all(
        color: selectionne ? CouleursCoach.vert : CouleursCoach.bordure,
        width: selectionne ? 2 : 0.8,
      ),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(rayonCarte),
        onTap: onTap,
        child: child,
      ),
    ),
  );
}

class _Icone extends StatelessWidget {
  const _Icone(this.icone, this.selectionne, {this.taille = 44});

  final IconData icone;
  final bool selectionne;
  final double taille;

  @override
  Widget build(BuildContext context) => Container(
    width: taille,
    height: taille,
    decoration: BoxDecoration(
      color: selectionne ? CouleursCoach.vert : CouleursCoach.vertClair,
      borderRadius: BorderRadius.circular(taille / 3.5),
    ),
    child: Icon(
      icone,
      size: taille * 0.52,
      color: selectionne ? Colors.white : CouleursCoach.vert,
    ),
  );
}

/// Dispose des tuiles sur deux colonnes.
Widget grille(List<Widget> tuiles) => Column(
  children: [
    for (var i = 0; i < tuiles.length; i += 2)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tuiles[i]),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < tuiles.length ? tuiles[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
  ],
);

/// Message bienveillant (jamais en rouge).
class EncadreAlerte extends StatelessWidget {
  const EncadreAlerte(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CouleursCoach.orangeClair,
      borderRadius: BorderRadius.circular(rayonCarte),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: CouleursCoach.orangeFonce),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texte,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: CouleursCoach.orangeFonce),
          ),
        ),
      ],
    ),
  );
}

/// Information neutre (vert pâle).
class EncadreInfo extends StatelessWidget {
  const EncadreInfo(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CouleursCoach.vertClair,
      borderRadius: BorderRadius.circular(rayonCarte),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_outline, color: CouleursCoach.vertFonce),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texte,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: CouleursCoach.vertFonce),
          ),
        ),
      ],
    ),
  );
}

String formaterNombre(num? v) {
  if (v == null) return '';
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toString().replaceAll('.', ',');
}

class ChampNombre extends StatefulWidget {
  const ChampNombre({
    super.key,
    required this.label,
    required this.valeurInitiale,
    required this.onSaisie,
    required this.min,
    required this.max,
  });

  final String label;
  final String valeurInitiale;
  final ErreurChamp? Function(String) onSaisie;
  final int min;
  final int max;

  @override
  State<ChampNombre> createState() => _ChampNombreState();
}

class _ChampNombreState extends State<ChampNombre> {
  late final _texte = TextEditingController(text: widget.valeurInitiale);
  ErreurChamp? _erreur;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: _texte,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: switch (_erreur) {
            null => null,
            ErreurChamp.nombreInvalide => t.erreurNombre,
            ErreurChamp.horsPlage => t.erreurPlage(widget.min, widget.max),
          },
        ),
        onChanged: (v) => setState(() => _erreur = widget.onSaisie(v)),
      ),
    );
  }
}

String titreEtape(AppLocalizations t, Etape e) => switch (e) {
  Etape.objectif => t.qObjectif,
  Etape.sexeAge => t.qSexeAge,
  Etape.mensurations => t.qMensurations,
  Etape.typeDeVie => t.qTypeDeVie,
  Etape.entrainements => t.qEntrainements,
  Etape.niveau => t.qNiveau,
  Etape.disponibilite => t.qDisponibilite,
  Etape.sante => t.qSante,
  Etape.montre => t.qMontre,
  Etape.appMontre => t.qAppMontre,
  Etape.connexion => t.qConnexion,
};

String libelleObjectif(AppLocalizations t, Objectif o) => switch (o) {
  Objectif.perte => t.objectifPerte,
  Objectif.muscle => t.objectifMuscle,
  Objectif.forme => t.objectifForme,
  Objectif.reprise => t.objectifReprise,
};

String texteAlerte(AppLocalizations t, Alerte a) => switch (a) {
  Alerte.mineur => t.messageMineur,
  Alerte.perteRefuseeImc => t.messagePerteImc,
  Alerte.conseilMedecin => t.conseilMedecin,
};

const iconesObjectif = {
  Objectif.perte: Icons.monitor_weight_outlined,
  Objectif.muscle: Icons.fitness_center,
  Objectif.forme: Icons.favorite_outline,
  Objectif.reprise: Icons.replay,
};

const iconesAppMontre = {
  AppMontre.googleFit: Icons.favorite_border,
  AppMontre.samsungHealth: Icons.monitor_heart_outlined,
  AppMontre.miFitness: Icons.watch_outlined,
  AppMontre.fitbit: Icons.directions_walk,
  AppMontre.garmin: Icons.explore_outlined,
  AppMontre.autre: Icons.more_horiz,
};

String libelleAppMontre(AppLocalizations t, AppMontre a) => switch (a) {
  AppMontre.googleFit => t.appGoogleFit,
  AppMontre.samsungHealth => t.appSamsungHealth,
  AppMontre.miFitness => t.appMiFitness,
  AppMontre.fitbit => t.appFitbit,
  AppMontre.garmin => t.appGarmin,
  AppMontre.autre => t.appAutre,
};

/// Contenu des étapes de réponse (l'étape connexion est gérée par la page).
List<Widget> contenuEtape(BuildContext context, QuestionnaireControleur c) {
  final t = AppLocalizations.of(context)!;
  final petit = Theme.of(context).textTheme.bodyMedium
      ?.copyWith(color: CouleursCoach.texteDoux);
  TuileChoix tuile(
    String titre,
    IconData icone,
    bool sel,
    VoidCallback onTap,
  ) => TuileChoix(titre: titre, icone: icone, selectionne: sel, onTap: onTap);
  Widget carte(
    String titre,
    IconData icone,
    bool sel,
    VoidCallback onTap, [
    String? sousTitre,
  ]) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CarteChoix(
      titre: titre,
      sousTitre: sousTitre,
      icone: icone,
      selectionne: sel,
      onTap: onTap,
    ),
  );
  Widget titreSection(String texte) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
  );

  switch (c.etape) {
    case Etape.objectif:
      return [
        grille([
          for (final o in Objectif.values)
            tuile(
              libelleObjectif(t, o),
              iconesObjectif[o]!,
              c.objectif == o,
              () => c.choisirObjectif(o),
            ),
        ]),
      ];
    case Etape.sexeAge:
      return [
        grille([
          tuile(
            t.sexeHomme,
            Icons.male,
            c.sexe == Sexe.homme,
            () => c.choisirSexe(Sexe.homme),
          ),
          tuile(
            t.sexeFemme,
            Icons.female,
            c.sexe == Sexe.femme,
            () => c.choisirSexe(Sexe.femme),
          ),
        ]),
        Text(t.sexeExplication, style: petit),
        const SizedBox(height: 16),
        ChampNombre(
          key: const ValueKey('age'),
          label: t.champAge,
          valeurInitiale: formaterNombre(c.age),
          onSaisie: c.saisirAge,
          min: 18,
          max: ageMax,
        ),
      ];
    case Etape.mensurations:
      return [
        ChampNombre(
          key: const ValueKey('taille'),
          label: t.champTaille,
          valeurInitiale: formaterNombre(c.tailleCm),
          onSaisie: c.saisirTaille,
          min: tailleMin,
          max: tailleMax,
        ),
        ChampNombre(
          key: const ValueKey('poids'),
          label: t.champPoids,
          valeurInitiale: formaterNombre(c.poidsKg),
          onSaisie: c.saisirPoids,
          min: poidsMin,
          max: poidsMax,
        ),
      ];
    case Etape.typeDeVie:
      final libelles = {
        TypeDeVie.sedentaire: (
          t.vieSedentaire,
          t.vieSedentaireEx,
          Icons.chair_outlined,
        ),
        TypeDeVie.peuActif: (
          t.viePeuActif,
          t.viePeuActifEx,
          Icons.directions_walk,
        ),
        TypeDeVie.actif: (t.vieActif, t.vieActifEx, Icons.handyman_outlined),
        TypeDeVie.tresActif: (t.vieTresActif, t.vieTresActifEx, Icons.bolt),
      };
      return [
        for (final MapEntry(key: v, value: (titre, exemple, icone))
            in libelles.entries)
          carte(
            titre,
            icone,
            c.typeDeVie == v,
            () => c.choisirTypeDeVie(v),
            exemple,
          ),
      ];
    case Etape.entrainements:
      final libelles = {
        TypeEntrainement.salle: (t.entrainementSalle, Icons.fitness_center),
        TypeEntrainement.maison: (t.entrainementMaison, Icons.home_outlined),
        TypeEntrainement.course: (t.entrainementCourse, Icons.directions_run),
        TypeEntrainement.marche: (t.entrainementMarche, Icons.hiking),
      };
      return [
        Text(t.qEntrainementsAide, style: petit),
        const SizedBox(height: 12),
        grille([
          for (final MapEntry(key: v, value: (titre, icone))
              in libelles.entries)
            tuile(
              titre,
              icone,
              c.typesEntrainement.contains(v),
              () => c.basculerEntrainement(v),
            ),
        ]),
      ];
    case Etape.niveau:
      final libelles = {
        Niveau.debutant: (t.niveauDebutant, Icons.signal_cellular_alt_1_bar),
        Niveau.reprise: (t.niveauReprise, Icons.signal_cellular_alt_2_bar),
        Niveau.regulier: (t.niveauRegulier, Icons.signal_cellular_alt),
      };
      return [
        for (final MapEntry(key: v, value: (titre, icone)) in libelles.entries)
          carte(titre, icone, c.niveau == v, () => c.choisirNiveau(v)),
      ];
    case Etape.disponibilite:
      return [
        titreSection(t.champJours),
        SegmentedButton<int>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            for (var j = joursMin; j <= joursMax; j++)
              ButtonSegment(value: j, label: Text('$j')),
          ],
          selected: {?c.joursParSemaine},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) c.choisirJours(s.first);
          },
        ),
        const SizedBox(height: 28),
        titreSection(t.champDuree),
        SegmentedButton<int>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            for (final d in durees)
              ButtonSegment(value: d, label: Text(t.dureeMinutes(d))),
          ],
          selected: {?c.dureeSeanceMin},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) c.choisirDuree(s.first);
          },
        ),
      ];
    case Etape.sante:
      return [
        grille([
          tuile(
            t.boutonOui,
            Icons.medical_services_outlined,
            c.problemeSante == true,
            () => c.repondreSante(true),
          ),
          tuile(
            t.boutonNon,
            Icons.thumb_up_outlined,
            c.problemeSante == false,
            () => c.repondreSante(false),
          ),
        ]),
        Text(t.mentionMedicale, style: petit),
      ];
    case Etape.montre:
      return [
        Text(t.montreAide, style: petit),
        const SizedBox(height: 16),
        grille([
          tuile(
            t.boutonOui,
            Icons.watch_outlined,
            c.montre == true,
            () => c.repondreMontre(true),
          ),
          tuile(
            t.boutonNon,
            Icons.phone_android,
            c.montre == false,
            () => c.repondreMontre(false),
          ),
        ]),
      ];
    case Etape.appMontre:
      return [
        grille([
          for (final a in AppMontre.values)
            tuile(
              libelleAppMontre(t, a),
              iconesAppMontre[a]!,
              c.appMontre == a,
              () => c.choisirAppMontre(a),
            ),
        ]),
      ];
    case Etape.connexion:
      return const [];
  }
}
