// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitre => 'Crunch & Go';

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
      'Crunch & Go est réservé aux personnes de 18 ans et plus. Les besoins des adolescents sont différents : parles-en à ton médecin.';

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
  String get mentionMedicale => 'Crunch & Go ne remplace pas un avis médical.';

  @override
  String accueilBonjour(String prenom) {
    return 'Bonjour $prenom !';
  }

  @override
  String get accueilBonjourSansNom => 'Bonjour !';

  @override
  String get boutonModifierProfil => 'Modifier mon profil';

  @override
  String get boutonDeconnexion => 'Se déconnecter';

  @override
  String get bienvenuePoint1 => 'Programme à la maison, en salle ou en course';

  @override
  String get bienvenuePoint2 => 'Repas en photo, sans compter';

  @override
  String etapeSur(int n, int total) {
    return 'Étape $n sur $total';
  }

  @override
  String objectifPastille(String objectif) {
    return 'Objectif : $objectif';
  }

  @override
  String get reperesTitre => 'Tes repères du jour';

  @override
  String get reperesKcalLabel => 'kcal par jour';

  @override
  String reperesProteinesValeur(int g) {
    return '$g g';
  }

  @override
  String get reperesProteinesLabel => 'de protéines';

  @override
  String get reperesEstimation => 'Estimations calculées d\'après ton profil.';

  @override
  String get carteProgramme => 'Ton programme';

  @override
  String get carteProgrammeSous => 'Ta séance du jour';

  @override
  String get carteIdees => 'Idées de repas';

  @override
  String get carteIdeesSous => 'Balaie des idées adaptées à toi';

  @override
  String get tabSport => 'Sport';

  @override
  String get qMontre => 'As-tu une montre ou un bracelet connecté ?';

  @override
  String get montreAide =>
      'Crunch & Go pourra lire ton activité, ton sommeil et ton cœur via Health Connect, sans rien envoyer sur internet.';

  @override
  String get qAppMontre => 'Quelle application l\'accompagne ?';

  @override
  String get appGoogleFit => 'Google Fit';

  @override
  String get appSamsungHealth => 'Samsung Health';

  @override
  String get appMiFitness => 'Mi Fitness';

  @override
  String get appFitbit => 'Fitbit';

  @override
  String get appGarmin => 'Garmin Connect';

  @override
  String get appAutre => 'Autre';

  @override
  String consignePartage(String app) {
    return 'Dans $app, active le partage des données vers Health Connect (souvent dans Profil ou Paramètres, rubrique « Health Connect » ou « Applications connectées »).';
  }

  @override
  String get consignePartageAutre =>
      'Dans l\'application de ta montre, active le partage des données vers Health Connect.';

  @override
  String get boutonAutoriser => 'Autoriser l\'accès';

  @override
  String get boutonInstallerHc => 'Installer Health Connect';

  @override
  String get hcAInstaller =>
      'Health Connect doit être installé ou mis à jour sur ce téléphone.';

  @override
  String get hcIndisponible =>
      'Health Connect n\'est pas disponible sur ce téléphone. Crunch & Go utilisera des estimations.';

  @override
  String get accesAccorde =>
      'Accès autorisé : Crunch & Go lira les données de ta montre.';

  @override
  String get accesRefuse =>
      'Accès non autorisé. Pas de souci : Crunch & Go utilisera des estimations, et tu pourras réessayer plus tard.';

  @override
  String get sourceMesure => 'Mesuré par ta montre';

  @override
  String get sourceEstime => 'Estimé';

  @override
  String get maJournee => 'Ma journée';

  @override
  String get statPas => 'pas';

  @override
  String get statKcal => 'kcal brûlées';

  @override
  String get statSommeil => 'de sommeil';

  @override
  String get statFcRepos => 'bpm au repos';

  @override
  String dureeHeures(int h, String m) {
    return '$h h $m';
  }

  @override
  String get connecterMontre => 'Connecte ta montre';

  @override
  String get connecterMontreAide =>
      'Pour voir ton activité et ton sommeil, et ajuster tes repères.';

  @override
  String get aucuneDonneeMontre =>
      'Aucune donnée reçue de ta montre pour l\'instant.';

  @override
  String get suiviErreur =>
      'Impossible de lire les données de ta montre pour le moment.';

  @override
  String get voirDetail => 'Voir le détail';

  @override
  String get mesDonnees => 'Mes données';

  @override
  String get sectionActivite => 'Activité';

  @override
  String get sectionSommeil => 'Sommeil';

  @override
  String get sectionCoeur => 'Cœur et respiration';

  @override
  String get sectionCorps => 'Corps';

  @override
  String get periode7 => '7 jours';

  @override
  String get periode30 => '30 jours';

  @override
  String get mesurePas => 'Pas';

  @override
  String get mesureKcalActives => 'Calories actives';

  @override
  String get mesureDistance => 'Distance (km)';

  @override
  String get mesureEtages => 'Étages';

  @override
  String get mesureSommeil => 'Durée de sommeil (h)';

  @override
  String get phaseProfond => 'Profond';

  @override
  String get phaseLeger => 'Léger';

  @override
  String get phaseParadoxal => 'Paradoxal';

  @override
  String get mesureFcRepos => 'FC au repos (bpm)';

  @override
  String get mesureVariabilite => 'Variabilité cardiaque (ms)';

  @override
  String get mesureSpo2 => 'Oxygène sanguin (%)';

  @override
  String get mesureFreqResp => 'Fréquence respiratoire (/min)';

  @override
  String get mesurePoids => 'Poids (kg)';

  @override
  String get mesureMasseGrasse => 'Masse grasse';

  @override
  String derniereValeur(String valeur) {
    return 'Dernière valeur : $valeur';
  }

  @override
  String get aucuneDonneePeriode => 'Aucune donnée sur cette période.';

  @override
  String get tabAccueil => 'Accueil';

  @override
  String get tabPoids => 'Poids';

  @override
  String get poidsActuel => 'Poids actuel';

  @override
  String poidsDepuis(String ecart, String date) {
    return '$ecart kg depuis le $date';
  }

  @override
  String poidsKgValeur(String kg) {
    return '$kg kg';
  }

  @override
  String get imcTitre => 'Ton IMC';

  @override
  String get imcMaigreur => 'Maigreur';

  @override
  String get imcNormal => 'Poids normal';

  @override
  String get imcSurpoids => 'Surpoids';

  @override
  String get imcObesite => 'Obésité';

  @override
  String get imcAide =>
      'L\'IMC est un repère général : il ne tient pas compte de ta masse musculaire.';

  @override
  String get projectionLegende =>
      'Pointillés : projection sur 5 jours d\'après ton journal des 7 derniers jours.';

  @override
  String get mensurationsTitre => 'Mensurations';

  @override
  String get mesureTaille => 'Tour de taille';

  @override
  String get mesurePoitrine => 'Tour de poitrine';

  @override
  String get mesureBras => 'Tour de bras';

  @override
  String get ajouterMesures => 'Ajouter des mesures';

  @override
  String get aucuneMesure => 'Pas encore de mesure. Un mètre ruban suffit !';

  @override
  String get mesuresAide => 'Remplis seulement ce que tu as mesuré.';

  @override
  String get erreurMesures => 'Entre au moins une mesure.';

  @override
  String get photosTitre => 'Photos de progression';

  @override
  String get photosAide =>
      'Une photo par mois, de face et dans la même lumière. Elles restent sur ton téléphone, rien n\'est envoyé.';

  @override
  String get prendrePhoto => 'Prendre une photo';

  @override
  String get comparerPhotos => 'Comparer';

  @override
  String get supprimerPhoto => 'Supprimer la photo';

  @override
  String get photoAvant => 'Avant';

  @override
  String get photoApres => 'Après';

  @override
  String get tabEntrainement => 'Entraînement';

  @override
  String get lieuMaison => 'Maison';

  @override
  String get lieuSalle => 'Salle';

  @override
  String get lieuCourse => 'Course à pied';

  @override
  String get lieuMarche => 'Marche';

  @override
  String get materielHalteres => 'Haltères';

  @override
  String get materielElastiques => 'Élastiques';

  @override
  String get materielBarre => 'Barre de traction';

  @override
  String get materielKettlebell => 'Kettlebell';

  @override
  String get materielBanc => 'Banc';

  @override
  String get materielCorde => 'Corde à sauter';

  @override
  String get monMateriel => 'Mon matériel';

  @override
  String get materielAide =>
      'Coche ce que tu as chez toi : sans matériel, on remplace par un exercice au poids du corps.';

  @override
  String get commencerSeance => 'Commencer la séance';

  @override
  String get seanceTerminee => 'Séance terminée, bravo !';

  @override
  String get terminer => 'Terminer';

  @override
  String get couperVoix => 'Couper la voix';

  @override
  String get activerVoix => 'Activer la voix';

  @override
  String get reprendre => 'Reprendre';

  @override
  String get pause => 'Pause';

  @override
  String get passer => 'Passer';

  @override
  String get fait => 'Fait';

  @override
  String seancesSemaine(int faites, int prevues) {
    return 'Cette semaine : $faites séance(s) sur $prevues';
  }

  @override
  String dureeEstimee(int minutes) {
    return 'Environ $minutes min';
  }

  @override
  String remplace(String nom) {
    return 'remplace $nom';
  }

  @override
  String repetitions(int n) {
    return '$n répétitions';
  }

  @override
  String get recuperationTitre => 'Récupération';

  @override
  String get recuperationVide =>
      'Pas encore de donnée de sommeil. Dis-nous comment tu te sens, ou connecte ta montre.';

  @override
  String get recuperationBon =>
      'Feu vert : tu peux faire ta séance normalement.';

  @override
  String get recuperationMoyen =>
      'Récupération correcte : écoute ton corps, évite de forcer sur l\'intensité.';

  @override
  String get recuperationFaible =>
      'Corps fatigué : privilégie une marche, des étirements ou du repos aujourd\'hui.';

  @override
  String get ressentiQuestion => 'Comment te sens-tu ce matin ?';

  @override
  String get ressentiFatigue => 'Fatigué';

  @override
  String get ressentiMoyen => 'Moyen';

  @override
  String get ressentiForme => 'En forme';

  @override
  String get mobiliteTitre => 'Mobilité et étirements';

  @override
  String get routineApresEffort => 'Étirements après l\'effort';

  @override
  String get routineReveil => 'Réveil articulaire (5 min)';

  @override
  String get routineRecuperation => 'Récupération douce (8 min)';

  @override
  String get conseilleMaintenant => 'Conseillé maintenant';

  @override
  String get tabBienEtre => 'Bien-être';

  @override
  String get hydratationTitre => 'Hydratation';

  @override
  String eauBueSur(String bu, String objectif) {
    return '$bu L sur $objectif L';
  }

  @override
  String get eauBaseProfil => 'Selon ton poids';

  @override
  String eauEffort(int minutes) {
    return '$minutes min d\'effort';
  }

  @override
  String eauChaleur(int degres) {
    return '$degres °C aujourd\'hui';
  }

  @override
  String ajouterEau(int ml) {
    return '+ $ml ml';
  }

  @override
  String get annulerDernier => 'Annuler le dernier';

  @override
  String get adapterMeteo => 'Adapter à la météo';

  @override
  String get meteoAide =>
      'Utilise ta position approximative pour la température du jour. Elle n\'est pas enregistrée.';

  @override
  String get annuler => 'Annuler';

  @override
  String get complementsTitre => 'Compléments';

  @override
  String get complementsAide =>
      'Un rappel par jour pour ne pas oublier. Crunch & Go ne conseille aucune dose : demande à ton médecin ou à ton pharmacien.';

  @override
  String get ajouterComplement => 'Ajouter un complément';

  @override
  String get nomComplement => 'Nom (ex. vitamine D)';

  @override
  String rappelA(String heure) {
    return 'Rappel à $heure';
  }

  @override
  String get rappelDesactive => 'Rappel désactivé';

  @override
  String get optionsComplement => 'Options';

  @override
  String get activerRappel => 'Activer le rappel';

  @override
  String get desactiverRappel => 'Désactiver le rappel';

  @override
  String get supprimerComplement => 'Supprimer';

  @override
  String get seriesTitre => 'Tes séries';

  @override
  String get serieJournal => 'Journal tenu';

  @override
  String get serieEntrainement => 'Séance faite';

  @override
  String get serieEau => 'Objectif d\'eau atteint';

  @override
  String nbJours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n jours',
      one: '1 jour',
      zero: '0 jour',
    );
    return '$_temp0';
  }

  @override
  String get horsLigne =>
      'Hors-ligne : tes saisies sont gardées et seront envoyées au retour du réseau.';

  @override
  String get menuPhoto => 'Photo du repas';

  @override
  String get analyseEnCours => 'Analyse de ton repas…';

  @override
  String get analyseReseau =>
      'Pas de connexion pour analyser la photo. Réessaie quand le réseau revient, ou saisis le repas à la main.';

  @override
  String get analyseAuth =>
      'Ta session a expiré. Reconnecte-toi pour analyser une photo.';

  @override
  String get analyseQuota =>
      'Tu as atteint la limite de photos analysées pour aujourd\'hui (ou le service est très sollicité). Saisis le repas à la main, ou réessaie demain.';

  @override
  String get analyseIllisible =>
      'Je n\'ai pas réussi à lire cette photo. Essaie avec plus de lumière, ou saisis le repas à la main.';

  @override
  String get analyseIndisponible =>
      'Le service d\'analyse est indisponible pour le moment.';

  @override
  String get reessayer => 'Réessayer';

  @override
  String get saisirALaMain => 'Saisir à la main';

  @override
  String get aucunAliment => 'Je ne vois pas d\'aliment sur cette photo.';

  @override
  String get estimationAVerifier =>
      'Estimation par IA, à vérifier : décoche ce qui est faux et corrige les portions.';

  @override
  String get changerPortion => 'Changer la portion';

  @override
  String get planningTitre => 'Repas de la semaine';

  @override
  String planningAide(int kcal) {
    return 'Des repas simples qui visent tes $kcal kcal par jour. Touche un repas pour voir la recette.';
  }

  @override
  String get sansViande => 'Sans viande ni poisson';

  @override
  String nbPortions(String n) {
    return '$n portion(s)';
  }

  @override
  String minutesValeur(int n) {
    return '$n min';
  }

  @override
  String get ingredientsTitre => 'Ingrédients';

  @override
  String get preparationTitre => 'Préparation';

  @override
  String get ajouterAuJournal => 'Ajouter au journal';

  @override
  String get changerRecette => 'Changer de recette';

  @override
  String get repasAjoute => 'Repas ajouté au journal.';

  @override
  String get coursesTitre => 'Liste de courses';

  @override
  String get coursesAide =>
      'Tout ce qu\'il faut pour la semaine, rangé par rayon.';

  @override
  String get rayonFruitsLegumes => 'Fruits et légumes';

  @override
  String get rayonBoulangerie => 'Boulangerie';

  @override
  String get rayonViandePoisson => 'Viandes et poissons';

  @override
  String get rayonCremerie => 'Crèmerie et œufs';

  @override
  String get rayonEpicerie => 'Épicerie';

  @override
  String get menuPlanning => 'Repas de la semaine';

  @override
  String get ideesTitre => 'Idées de repas';

  @override
  String get mesEnvies => 'Mes envies';

  @override
  String get tousLesRepas => 'Tous';

  @override
  String get ideesTerminees =>
      'Tu as fait le tour des idées pour ce choix ! Retrouve tes préférées dans « Mes envies », ou change de type de repas.';

  @override
  String get jeNaimePas => 'Je n\'aime pas';

  @override
  String get jAimePlusTard => 'J\'aime, pour une prochaine fois';

  @override
  String get photosIllustratives => 'Photos illustratives générées par IA.';

  @override
  String get etiquetteEnvie => 'ENVIE';

  @override
  String get etiquetteNon => 'NON';

  @override
  String pourToiKcal(int kcal) {
    return '≈ $kcal kcal pour toi';
  }

  @override
  String get vegetarienCourt => 'végé';

  @override
  String get aucuneEnvie =>
      'Aucune envie pour l\'instant. Balaie une carte vers la droite pour garder une recette pour une prochaine fois.';

  @override
  String get retirerEnvie => 'Retirer de mes envies';

  @override
  String get menuIdees => 'Idées de repas';

  @override
  String get reglagesTitre => 'Réglages';

  @override
  String get reglagesInfobulle => 'Réglages';

  @override
  String versionNumero(String v) {
    return 'Version $v';
  }

  @override
  String majDisponible(String v) {
    return 'Nouvelle version $v disponible';
  }

  @override
  String get majTelecharger => 'Télécharger la mise à jour';

  @override
  String get majAJour => 'Tu as la dernière version.';

  @override
  String get majAideVerifier =>
      'Touche le bouton pour chercher une nouvelle version.';

  @override
  String get majVerifier => 'Vérifier les mises à jour';

  @override
  String get partagerTitre => 'Partager l\'application';

  @override
  String get partagerAide =>
      'Fais scanner ce code à un ami pour qu\'il puisse installer l\'application.';

  @override
  String get copierLien => 'Copier le lien';

  @override
  String get lienCopie => 'Lien copié.';

  @override
  String get confidentialite => 'Politique de confidentialité';

  @override
  String get accepter => 'Accepter';

  @override
  String get refuser => 'Refuser';

  @override
  String get consentPhotoTitre => 'Envoyer la photo pour l\'analyse ?';

  @override
  String get consentPhotoTexte =>
      'La photo de ton repas est envoyée à un service d\'IA hébergé par Cloudflare pour estimer les aliments. Elle n\'est ni enregistrée ni conservée : seul le résultat que tu valides est ajouté à tes repas. Tu peux retirer ton accord à tout moment dans les Réglages.';

  @override
  String get consentMeteoTitre => 'Utiliser ta position ?';

  @override
  String get consentMeteoTexte =>
      'Ta position approximative (arrondie à environ 10 km) est envoyée au service Open-Meteo pour connaître la température du jour. Elle n\'est pas enregistrée.';

  @override
  String get consentPhotoReglage => 'Photo de repas analysée par IA';

  @override
  String get consentPhotoReglageAide =>
      'Autorise l\'envoi de tes photos de repas au service d\'analyse.';

  @override
  String get supprimerCompte => 'Supprimer mon compte et mes données';

  @override
  String get supprimerCompteTitre => 'Supprimer définitivement ton compte ?';

  @override
  String get supprimerCompteTexte =>
      'Ton profil, tes repas, ton poids, tes séances, ton eau et tes compléments seront effacés pour toujours, ainsi que les photos de progression de ce téléphone. Cette action est irréversible.';

  @override
  String get supprimerConfirmer => 'Tout supprimer';

  @override
  String get supprimerEnCours => 'Suppression en cours…';

  @override
  String get supprimerHorsLigne =>
      'Connecte-toi à internet pour supprimer ton compte.';

  @override
  String get supprimerEchec =>
      'La suppression a échoué. Réessaie ; si besoin, reconnecte-toi puis recommence.';

  @override
  String get anneauxTitre => 'Aujourd\'hui';

  @override
  String get libBrule => 'Calories brûlées';

  @override
  String get libMange => 'Calories mangées';

  @override
  String get libProteines => 'Protéines';

  @override
  String get libEau => 'Hydratation';

  @override
  String get objectifDuJour => 'Objectif du jour';

  @override
  String get sourceEstimeJusqua => 'Estimé jusqu\'à maintenant';

  @override
  String get bilanCentre => 'bilan kcal';

  @override
  String get photoConseil =>
      'Photographie ton repas de dessus, dans une bonne lumière, sans rien cacher : l\'estimation des portions n\'en sera que meilleure.';

  @override
  String get prendrePhotoRepas => 'Prendre une photo';

  @override
  String get galerieChoix => 'Choisir dans la galerie';

  @override
  String get precisionLabel => 'Une précision ? (facultatif)';

  @override
  String get precisionAide => 'ex. sauce à part, grande assiette, sans pain';

  @override
  String get analyserRepas => 'Analyser ce repas';

  @override
  String get changerPhoto => 'Changer de photo';

  @override
  String get aVerifier => 'À vérifier';

  @override
  String get moinsPortion => 'Diminuer la portion';

  @override
  String get plusPortion => 'Augmenter la portion';

  @override
  String get ajouterAliment => 'Ajouter un aliment';

  @override
  String get modifierAliment => 'Modifier l\'aliment';

  @override
  String get nomAliment => 'Nom de l\'aliment';

  @override
  String get erreurNomAliment => 'Donne un nom à l\'aliment.';

  @override
  String get sansAnalyse =>
      'Sans analyse par IA, tu peux saisir ton repas à la main.';

  @override
  String ceRepas(int kcal, int p, int g, int l) {
    return 'Ce repas : $kcal kcal · $p g de protéines · $g g de glucides · $l g de lipides';
  }

  @override
  String apresRepas(int kcal, int cible, int p, int pc) {
    return 'Après ce repas : $kcal / $cible kcal · $p / $pc g de protéines';
  }

  @override
  String get cartonVert => 'C\'est un carton vert !';

  @override
  String get cartonOrange => 'C\'est un carton orange !';

  @override
  String get cartonRouge => 'C\'est un carton rouge !';

  @override
  String ilSagit(String nom) {
    return 'Il s\'agit de : $nom';
  }

  @override
  String get verdictCoach => 'Le verdict du coach';

  @override
  String get tuileCalories => 'Calories';

  @override
  String get tuileProteines => 'Protéines';

  @override
  String get tuileGlucides => 'Glucides';

  @override
  String get tuileLipides => 'Lipides';

  @override
  String dontSucres(int s) {
    return 'dont $s g de sucres';
  }

  @override
  String dontSatures(int s) {
    return 'dont $s g de saturés';
  }

  @override
  String get recapTitre => 'Total de la journée';

  @override
  String get recapTotal => 'Total';

  @override
  String recapValeur(int kcal, int p) {
    return '$kcal kcal · $p g de protéines';
  }

  @override
  String get activitesDuJour => 'Activités d\'aujourd\'hui';

  @override
  String get supprimerActivite => 'Supprimer l\'activité';

  @override
  String get ajouterPhotoProgres => 'Ajouter une photo';

  @override
  String get photoAppareil => 'Appareil photo';

  @override
  String get photoBibliotheque => 'Bibliothèque de photos';

  @override
  String get photoDate => 'Date de la photo';

  @override
  String get photoAjoutAide =>
      'Choisis la date de la photo (aujourd\'hui par défaut), puis d\'où elle vient.';

  @override
  String get composition => 'Composition';

  @override
  String get repasSansAnalyse =>
      'Ce repas a été saisi à la main : il n\'y a pas d\'analyse détaillée à revoir.';

  @override
  String portionGrammes(int g, int kcal) {
    return '$g g · $kcal kcal';
  }

  @override
  String get photosRepasTitre => 'Photos de repas';

  @override
  String photosRepasBilan(int nombre, String mo) {
    return '$nombre sur ce téléphone · $mo Mo';
  }

  @override
  String get photosRepasNettoyer => 'Supprimer les photos de plus de 90 jours';

  @override
  String get photosRepasNettoyerAide =>
      'Les repas et leur analyse restent dans ton journal ; seules les photos sont effacées de ce téléphone.';

  @override
  String photosRepasNettoyees(int nombre) {
    return '$nombre photo(s) supprimée(s).';
  }

  @override
  String get enregistrerModifications => 'Enregistrer les modifications';

  @override
  String get courbePoids => 'Évolution du poids';

  @override
  String get periode90 => '90 jours';

  @override
  String get periode1an => '1 an';

  @override
  String get ajouterPesee => 'Ajouter une pesée';

  @override
  String get enregistrer => 'Enregistrer';

  @override
  String get champDate => 'Date';

  @override
  String get historiquePoids => 'Historique';

  @override
  String get supprimerPesee => 'Supprimer';

  @override
  String get aucunePesee =>
      'Aucune pesée pour l\'instant. Ajoute la première !';

  @override
  String get sourceMontre => 'Montre';

  @override
  String get sourceSaisie => 'Saisie';

  @override
  String get tabJournal => 'Repas';

  @override
  String get jourAujourdhui => 'Aujourd\'hui';

  @override
  String get jourPrecedent => 'Jour précédent';

  @override
  String get jourSuivant => 'Jour suivant';

  @override
  String get bilanTitre => 'Bilan énergétique';

  @override
  String get bilanMange => 'Mangé';

  @override
  String get bilanDepense => 'Dépensé';

  @override
  String get bilanSolde => 'Solde';

  @override
  String kcalValeur(String kcal) {
    return '$kcal kcal';
  }

  @override
  String get soldeDeficit => 'Déficit';

  @override
  String get soldeExcedent => 'Excédent';

  @override
  String cibleJour(int kcal) {
    return 'Objectif du jour : $kcal kcal';
  }

  @override
  String get jourRepos => 'Jour de repos';

  @override
  String get jourModere => 'Jour modéré';

  @override
  String get jourIntense => 'Jour intense';

  @override
  String get macrosTitre => 'Macros du jour';

  @override
  String get macroProteines => 'Protéines';

  @override
  String get macroGlucides => 'Glucides';

  @override
  String get macroLipides => 'Lipides';

  @override
  String macroProgression(int mange, int cible) {
    return '$mange / $cible g';
  }

  @override
  String get repasTitre => 'Repas';

  @override
  String get activitesTitre => 'Activités';

  @override
  String get aucunRepas => 'Aucun repas enregistré.';

  @override
  String get aucuneActivite => 'Aucune activité enregistrée.';

  @override
  String get momentPetitDej => 'Petit-déjeuner';

  @override
  String get momentDejeuner => 'Déjeuner';

  @override
  String get momentDiner => 'Dîner';

  @override
  String get momentCollation => 'Collation';

  @override
  String get menuRepas => 'Saisie à la main';

  @override
  String get menuScanner => 'Scanner un produit';

  @override
  String get menuActivite => 'Ajouter une activité';

  @override
  String get ajouter => 'Ajouter';

  @override
  String get champNomRepas => 'Nom du repas';

  @override
  String get champKcal => 'Calories (kcal)';

  @override
  String get champProteines => 'Protéines (g)';

  @override
  String get champGlucides => 'Glucides (g)';

  @override
  String get champLipides => 'Lipides (g)';

  @override
  String get champMoment => 'Moment';

  @override
  String get nomRepasDefaut => 'Repas';

  @override
  String get scanTitre => 'Scanner un produit';

  @override
  String get scanAide => 'Place le code-barres dans le cadre.';

  @override
  String get scanOuSaisir => 'Ou saisis le code à la main';

  @override
  String get champCode => 'Code-barres';

  @override
  String get scanRechercher => 'Rechercher';

  @override
  String get produitIntrouvable =>
      'Produit introuvable. Tu peux l\'ajouter à la main.';

  @override
  String get erreurReseauProduit =>
      'Impossible de joindre Open Food Facts. Vérifie ta connexion.';

  @override
  String get champQuantite => 'Quantité (g)';

  @override
  String produitPour100g(int kcal) {
    return 'Pour 100 g : $kcal kcal';
  }

  @override
  String get actVelo => 'Vélo';

  @override
  String get actMma => 'MMA';

  @override
  String get actCourse => 'Course à pied';

  @override
  String get actNatation => 'Natation';

  @override
  String get actMuscu => 'Musculation';

  @override
  String get actMarche => 'Marche';

  @override
  String get actAutre => 'Autre';

  @override
  String get champDureeMin => 'Durée (min)';

  @override
  String get intLegere => 'Légère';

  @override
  String get intModeree => 'Modérée';

  @override
  String get intIntense => 'Intense';

  @override
  String activiteEstimation(int kcal) {
    return '≈ $kcal kcal brûlées';
  }

  @override
  String get supprimer => 'Supprimer';

  @override
  String get erreurDuree => 'Entre une durée en minutes.';
}
