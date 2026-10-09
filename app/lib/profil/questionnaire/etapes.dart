import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../modele.dart';
import 'controleur.dart';

/// Grosse carte de choix, adaptée aux débutants.
class CarteChoix extends StatelessWidget {
  const CarteChoix({
    super.key,
    required this.titre,
    this.sousTitre,
    required this.selectionne,
    required this.onTap,
  });

  final String titre;
  final String? sousTitre;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Card(
      color: selectionne ? couleurs.primaryContainer : null,
      child: ListTile(
        minVerticalPadding: 16,
        title: Text(titre, style: Theme.of(context).textTheme.titleMedium),
        subtitle: sousTitre == null ? null : Text(sousTitre!),
        trailing: selectionne
            ? Icon(Icons.check_circle, color: couleurs.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}

/// Message bienveillant (jamais en rouge).
class EncadreAlerte extends StatelessWidget {
  const EncadreAlerte(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 12),
              Expanded(child: Text(texte)),
            ],
          ),
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
          border: const OutlineInputBorder(),
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

/// Contenu des étapes de réponse (l'étape connexion est gérée par la page).
List<Widget> contenuEtape(
    BuildContext context, QuestionnaireControleur c) {
  final t = AppLocalizations.of(context)!;
  CarteChoix carte(String titre, bool sel, VoidCallback onTap,
          [String? sousTitre]) =>
      CarteChoix(
          titre: titre, sousTitre: sousTitre, selectionne: sel, onTap: onTap);

  switch (c.etape) {
    case Etape.objectif:
      return [
        for (final o in Objectif.values)
          carte(libelleObjectif(t, o), c.objectif == o,
              () => c.choisirObjectif(o)),
      ];
    case Etape.sexeAge:
      return [
        carte(t.sexeHomme, c.sexe == Sexe.homme,
            () => c.choisirSexe(Sexe.homme)),
        carte(t.sexeFemme, c.sexe == Sexe.femme,
            () => c.choisirSexe(Sexe.femme)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(t.sexeExplication,
              style: Theme.of(context).textTheme.bodySmall),
        ),
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
        TypeDeVie.sedentaire: (t.vieSedentaire, t.vieSedentaireEx),
        TypeDeVie.peuActif: (t.viePeuActif, t.viePeuActifEx),
        TypeDeVie.actif: (t.vieActif, t.vieActifEx),
        TypeDeVie.tresActif: (t.vieTresActif, t.vieTresActifEx),
      };
      return [
        for (final MapEntry(key: v, value: (titre, exemple)) in libelles.entries)
          carte(titre, c.typeDeVie == v, () => c.choisirTypeDeVie(v), exemple),
      ];
    case Etape.entrainements:
      final libelles = {
        TypeEntrainement.salle: t.entrainementSalle,
        TypeEntrainement.maison: t.entrainementMaison,
        TypeEntrainement.course: t.entrainementCourse,
        TypeEntrainement.marche: t.entrainementMarche,
      };
      return [
        Text(t.qEntrainementsAide),
        const SizedBox(height: 8),
        for (final MapEntry(key: v, value: titre) in libelles.entries)
          carte(titre, c.typesEntrainement.contains(v),
              () => c.basculerEntrainement(v)),
      ];
    case Etape.niveau:
      final libelles = {
        Niveau.debutant: t.niveauDebutant,
        Niveau.reprise: t.niveauReprise,
        Niveau.regulier: t.niveauRegulier,
      };
      return [
        for (final MapEntry(key: v, value: titre) in libelles.entries)
          carte(titre, c.niveau == v, () => c.choisirNiveau(v)),
      ];
    case Etape.disponibilite:
      return [
        Text(t.champJours, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
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
        const SizedBox(height: 24),
        Text(t.champDuree, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
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
        carte(t.boutonOui, c.problemeSante == true,
            () => c.repondreSante(true)),
        carte(t.boutonNon, c.problemeSante == false,
            () => c.repondreSante(false)),
        const SizedBox(height: 8),
        Text(t.mentionMedicale, style: Theme.of(context).textTheme.bodySmall),
      ];
    case Etape.connexion:
      return const [];
  }
}
