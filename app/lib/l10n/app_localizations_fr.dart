// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitre => 'Coach';

  @override
  String get bienvenueTitre => 'Ton coach sport et alimentation';

  @override
  String get bienvenueSousTitre => 'Un programme adapté à toi, en une minute.';

  @override
  String get boutonCommencer => 'Commencer';

  @override
  String get boutonDejaCompte => 'J\'ai déjà un compte';

  @override
  String get boutonSuivant => 'Suivant';

  @override
  String get boutonRetour => 'Retour';

  @override
  String get boutonOui => 'Oui';

  @override
  String get boutonNon => 'Non';

  @override
  String get qObjectif => 'Quel est ton objectif ?';

  @override
  String get objectifPerte => 'Perdre du poids';

  @override
  String get objectifMuscle => 'Prendre du muscle';

  @override
  String get objectifForme => 'Garder la forme';

  @override
  String get objectifReprise => 'Reprendre le sport';

  @override
  String get qSexeAge => 'Parle-nous un peu de toi';

  @override
  String get sexeHomme => 'Homme';

  @override
  String get sexeFemme => 'Femme';

  @override
  String get sexeExplication => 'Sert uniquement au calcul de tes besoins.';

  @override
  String get champAge => 'Âge';

  @override
  String get qMensurations => 'Ta taille et ton poids';

  @override
  String get champTaille => 'Taille (cm)';

  @override
  String get champPoids => 'Poids (kg)';

  @override
  String get qTypeDeVie => 'Ton quotidien ressemble plutôt à…';

  @override
  String get vieSedentaire => 'Assis toute la journée';

  @override
  String get vieSedentaireEx => 'Bureau, voiture, peu de marche';

  @override
  String get viePeuActif => 'Un peu actif';

  @override
  String get viePeuActifEx => 'Souvent debout, un peu de marche';

  @override
  String get vieActif => 'Actif';

  @override
  String get vieActifEx => 'Métier physique, beaucoup de marche';

  @override
  String get vieTresActif => 'Très actif';

  @override
  String get vieTresActifEx => 'Travail très physique ou sport tous les jours';

  @override
  String get qEntrainements => 'Où veux-tu t\'entraîner ?';

  @override
  String get qEntrainementsAide => 'Plusieurs choix possibles.';

  @override
  String get entrainementSalle => 'Salle de sport';

  @override
  String get entrainementMaison => 'À la maison';

  @override
  String get entrainementCourse => 'Course à pied';

  @override
  String get entrainementMarche => 'Marche';

  @override
  String get qNiveau => 'Ton niveau';

  @override
  String get niveauDebutant => 'Débutant';

  @override
  String get niveauReprise => 'Je reprends';

  @override
  String get niveauRegulier => 'Régulier';

  @override
  String get qDisponibilite => 'Ton temps disponible';

  @override
  String get champJours => 'Jours par semaine';

  @override
  String get champDuree => 'Durée d\'une séance';

  @override
  String dureeMinutes(int n) {
    return '$n min';
  }

  @override
  String get qSante =>
      'Es-tu enceinte ou as-tu un problème de santé particulier ?';

  @override
  String get conseilMedecin =>
      'Parles-en à ton médecin avant de commencer. Par prudence, l\'objectif « perdre du poids » est désactivé.';

  @override
  String get messageMineur =>
      'Coach est réservé aux personnes de 18 ans et plus. Les besoins des adolescents sont différents : parles-en à ton médecin.';

  @override
  String get messagePerteImc =>
      'Ton poids est déjà bas pour ta taille : on part plutôt sur « garder la forme ».';

  @override
  String get erreurNombre => 'Entre un nombre valide.';

  @override
  String erreurPlage(int min, int max) {
    return 'Entre une valeur entre $min et $max.';
  }

  @override
  String get qConnexion => 'Dernière étape : sauvegarde ton profil';

  @override
  String get boutonGoogle => 'Continuer avec Google';

  @override
  String get erreurConnexion =>
      'La connexion a échoué. Vérifie ta connexion internet et réessaie.';

  @override
  String get mentionMedicale => 'Coach ne remplace pas un avis médical.';

  @override
  String accueilBonjour(String prenom) {
    return 'Bonjour $prenom !';
  }

  @override
  String get accueilBonjourSansNom => 'Bonjour !';

  @override
  String get accueilProgrammeBientot => 'Ton programme arrive bientôt.';

  @override
  String get boutonVoirReperes => 'Voir mes repères';

  @override
  String reperesKcal(int kcal) {
    return '$kcal kcal par jour (estimation)';
  }

  @override
  String reperesProteines(int g) {
    return '$g g de protéines par jour';
  }

  @override
  String get boutonModifierProfil => 'Modifier mon profil';

  @override
  String get boutonDeconnexion => 'Se déconnecter';
}
