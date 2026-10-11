import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

  /// No description provided for @appTitre.
  ///
  /// In fr, this message translates to:
  /// **'Coach'**
  String get appTitre;

  /// No description provided for @bienvenueTitre.
  ///
  /// In fr, this message translates to:
  /// **'Ton coach sport et alimentation'**
  String get bienvenueTitre;

  /// No description provided for @bienvenueSousTitre.
  ///
  /// In fr, this message translates to:
  /// **'Un programme adapté à toi, en une minute.'**
  String get bienvenueSousTitre;

  /// No description provided for @boutonCommencer.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get boutonCommencer;

  /// No description provided for @boutonDejaCompte.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai déjà un compte'**
  String get boutonDejaCompte;

  /// No description provided for @boutonSuivant.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get boutonSuivant;

  /// No description provided for @boutonRetour.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get boutonRetour;

  /// No description provided for @boutonOui.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get boutonOui;

  /// No description provided for @boutonNon.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get boutonNon;

  /// No description provided for @qObjectif.
  ///
  /// In fr, this message translates to:
  /// **'Quel est ton objectif ?'**
  String get qObjectif;

  /// No description provided for @objectifPerte.
  ///
  /// In fr, this message translates to:
  /// **'Perdre du poids'**
  String get objectifPerte;

  /// No description provided for @objectifMuscle.
  ///
  /// In fr, this message translates to:
  /// **'Prendre du muscle'**
  String get objectifMuscle;

  /// No description provided for @objectifForme.
  ///
  /// In fr, this message translates to:
  /// **'Garder la forme'**
  String get objectifForme;

  /// No description provided for @objectifReprise.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le sport'**
  String get objectifReprise;

  /// No description provided for @qSexeAge.
  ///
  /// In fr, this message translates to:
  /// **'Parle-nous un peu de toi'**
  String get qSexeAge;

  /// No description provided for @sexeHomme.
  ///
  /// In fr, this message translates to:
  /// **'Homme'**
  String get sexeHomme;

  /// No description provided for @sexeFemme.
  ///
  /// In fr, this message translates to:
  /// **'Femme'**
  String get sexeFemme;

  /// No description provided for @sexeExplication.
  ///
  /// In fr, this message translates to:
  /// **'Sert uniquement au calcul de tes besoins.'**
  String get sexeExplication;

  /// No description provided for @champAge.
  ///
  /// In fr, this message translates to:
  /// **'Âge'**
  String get champAge;

  /// No description provided for @qMensurations.
  ///
  /// In fr, this message translates to:
  /// **'Ta taille et ton poids'**
  String get qMensurations;

  /// No description provided for @champTaille.
  ///
  /// In fr, this message translates to:
  /// **'Taille (cm)'**
  String get champTaille;

  /// No description provided for @champPoids.
  ///
  /// In fr, this message translates to:
  /// **'Poids (kg)'**
  String get champPoids;

  /// No description provided for @qTypeDeVie.
  ///
  /// In fr, this message translates to:
  /// **'Ton quotidien ressemble plutôt à…'**
  String get qTypeDeVie;

  /// No description provided for @vieSedentaire.
  ///
  /// In fr, this message translates to:
  /// **'Assis toute la journée'**
  String get vieSedentaire;

  /// No description provided for @vieSedentaireEx.
  ///
  /// In fr, this message translates to:
  /// **'Bureau, voiture, peu de marche'**
  String get vieSedentaireEx;

  /// No description provided for @viePeuActif.
  ///
  /// In fr, this message translates to:
  /// **'Un peu actif'**
  String get viePeuActif;

  /// No description provided for @viePeuActifEx.
  ///
  /// In fr, this message translates to:
  /// **'Souvent debout, un peu de marche'**
  String get viePeuActifEx;

  /// No description provided for @vieActif.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get vieActif;

  /// No description provided for @vieActifEx.
  ///
  /// In fr, this message translates to:
  /// **'Métier physique, beaucoup de marche'**
  String get vieActifEx;

  /// No description provided for @vieTresActif.
  ///
  /// In fr, this message translates to:
  /// **'Très actif'**
  String get vieTresActif;

  /// No description provided for @vieTresActifEx.
  ///
  /// In fr, this message translates to:
  /// **'Travail très physique ou sport tous les jours'**
  String get vieTresActifEx;

  /// No description provided for @qEntrainements.
  ///
  /// In fr, this message translates to:
  /// **'Où veux-tu t\'entraîner ?'**
  String get qEntrainements;

  /// No description provided for @qEntrainementsAide.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs choix possibles.'**
  String get qEntrainementsAide;

  /// No description provided for @entrainementSalle.
  ///
  /// In fr, this message translates to:
  /// **'Salle de sport'**
  String get entrainementSalle;

  /// No description provided for @entrainementMaison.
  ///
  /// In fr, this message translates to:
  /// **'À la maison'**
  String get entrainementMaison;

  /// No description provided for @entrainementCourse.
  ///
  /// In fr, this message translates to:
  /// **'Course à pied'**
  String get entrainementCourse;

  /// No description provided for @entrainementMarche.
  ///
  /// In fr, this message translates to:
  /// **'Marche'**
  String get entrainementMarche;

  /// No description provided for @qNiveau.
  ///
  /// In fr, this message translates to:
  /// **'Ton niveau'**
  String get qNiveau;

  /// No description provided for @niveauDebutant.
  ///
  /// In fr, this message translates to:
  /// **'Débutant'**
  String get niveauDebutant;

  /// No description provided for @niveauReprise.
  ///
  /// In fr, this message translates to:
  /// **'Je reprends'**
  String get niveauReprise;

  /// No description provided for @niveauRegulier.
  ///
  /// In fr, this message translates to:
  /// **'Régulier'**
  String get niveauRegulier;

  /// No description provided for @qDisponibilite.
  ///
  /// In fr, this message translates to:
  /// **'Ton temps disponible'**
  String get qDisponibilite;

  /// No description provided for @champJours.
  ///
  /// In fr, this message translates to:
  /// **'Jours par semaine'**
  String get champJours;

  /// No description provided for @champDuree.
  ///
  /// In fr, this message translates to:
  /// **'Durée d\'une séance'**
  String get champDuree;

  /// No description provided for @dureeMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{n} min'**
  String dureeMinutes(int n);

  /// No description provided for @qSante.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu enceinte ou as-tu un problème de santé particulier ?'**
  String get qSante;

  /// No description provided for @conseilMedecin.
  ///
  /// In fr, this message translates to:
  /// **'Parles-en à ton médecin avant de commencer. Par prudence, l\'objectif « perdre du poids » est désactivé.'**
  String get conseilMedecin;

  /// No description provided for @messageMineur.
  ///
  /// In fr, this message translates to:
  /// **'Coach est réservé aux personnes de 18 ans et plus. Les besoins des adolescents sont différents : parles-en à ton médecin.'**
  String get messageMineur;

  /// No description provided for @messagePerteImc.
  ///
  /// In fr, this message translates to:
  /// **'Ton poids est déjà bas pour ta taille : on part plutôt sur « garder la forme ».'**
  String get messagePerteImc;

  /// No description provided for @erreurNombre.
  ///
  /// In fr, this message translates to:
  /// **'Entre un nombre valide.'**
  String get erreurNombre;

  /// No description provided for @erreurPlage.
  ///
  /// In fr, this message translates to:
  /// **'Entre une valeur entre {min} et {max}.'**
  String erreurPlage(int min, int max);

  /// No description provided for @qConnexion.
  ///
  /// In fr, this message translates to:
  /// **'Dernière étape : sauvegarde ton profil'**
  String get qConnexion;

  /// No description provided for @boutonGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get boutonGoogle;

  /// No description provided for @erreurConnexion.
  ///
  /// In fr, this message translates to:
  /// **'La connexion a échoué. Vérifie ta connexion internet et réessaie.'**
  String get erreurConnexion;

  /// No description provided for @mentionMedicale.
  ///
  /// In fr, this message translates to:
  /// **'Coach ne remplace pas un avis médical.'**
  String get mentionMedicale;

  /// No description provided for @accueilBonjour.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {prenom} !'**
  String accueilBonjour(String prenom);

  /// No description provided for @accueilBonjourSansNom.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour !'**
  String get accueilBonjourSansNom;

  /// No description provided for @boutonModifierProfil.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon profil'**
  String get boutonModifierProfil;

  /// No description provided for @boutonDeconnexion.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get boutonDeconnexion;

  /// No description provided for @bienvenuePoint1.
  ///
  /// In fr, this message translates to:
  /// **'Programme à la maison, en salle ou en course'**
  String get bienvenuePoint1;

  /// No description provided for @bienvenuePoint2.
  ///
  /// In fr, this message translates to:
  /// **'Repas en photo, sans compter'**
  String get bienvenuePoint2;

  /// No description provided for @etapeSur.
  ///
  /// In fr, this message translates to:
  /// **'Étape {n} sur {total}'**
  String etapeSur(int n, int total);

  /// No description provided for @objectifPastille.
  ///
  /// In fr, this message translates to:
  /// **'Objectif : {objectif}'**
  String objectifPastille(String objectif);

  /// No description provided for @reperesTitre.
  ///
  /// In fr, this message translates to:
  /// **'Tes repères du jour'**
  String get reperesTitre;

  /// No description provided for @reperesKcalLabel.
  ///
  /// In fr, this message translates to:
  /// **'kcal par jour'**
  String get reperesKcalLabel;

  /// No description provided for @reperesProteinesValeur.
  ///
  /// In fr, this message translates to:
  /// **'{g} g'**
  String reperesProteinesValeur(int g);

  /// No description provided for @reperesProteinesLabel.
  ///
  /// In fr, this message translates to:
  /// **'de protéines'**
  String get reperesProteinesLabel;

  /// No description provided for @reperesEstimation.
  ///
  /// In fr, this message translates to:
  /// **'Estimations calculées d\'après ton profil.'**
  String get reperesEstimation;

  /// No description provided for @carteProgramme.
  ///
  /// In fr, this message translates to:
  /// **'Ton programme'**
  String get carteProgramme;

  /// No description provided for @cartePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo de repas'**
  String get cartePhoto;

  /// No description provided for @bientot.
  ///
  /// In fr, this message translates to:
  /// **'Arrive bientôt'**
  String get bientot;

  /// No description provided for @qMontre.
  ///
  /// In fr, this message translates to:
  /// **'As-tu une montre ou un bracelet connecté ?'**
  String get qMontre;

  /// No description provided for @montreAide.
  ///
  /// In fr, this message translates to:
  /// **'Coach pourra lire ton activité, ton sommeil et ton cœur via Health Connect, sans rien envoyer sur internet.'**
  String get montreAide;

  /// No description provided for @qAppMontre.
  ///
  /// In fr, this message translates to:
  /// **'Quelle application l\'accompagne ?'**
  String get qAppMontre;

  /// No description provided for @appGoogleFit.
  ///
  /// In fr, this message translates to:
  /// **'Google Fit'**
  String get appGoogleFit;

  /// No description provided for @appSamsungHealth.
  ///
  /// In fr, this message translates to:
  /// **'Samsung Health'**
  String get appSamsungHealth;

  /// No description provided for @appMiFitness.
  ///
  /// In fr, this message translates to:
  /// **'Mi Fitness'**
  String get appMiFitness;

  /// No description provided for @appFitbit.
  ///
  /// In fr, this message translates to:
  /// **'Fitbit'**
  String get appFitbit;

  /// No description provided for @appGarmin.
  ///
  /// In fr, this message translates to:
  /// **'Garmin Connect'**
  String get appGarmin;

  /// No description provided for @appAutre.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get appAutre;

  /// No description provided for @consignePartage.
  ///
  /// In fr, this message translates to:
  /// **'Dans {app}, active le partage des données vers Health Connect (souvent dans Profil ou Paramètres, rubrique « Health Connect » ou « Applications connectées »).'**
  String consignePartage(String app);

  /// No description provided for @consignePartageAutre.
  ///
  /// In fr, this message translates to:
  /// **'Dans l\'application de ta montre, active le partage des données vers Health Connect.'**
  String get consignePartageAutre;

  /// No description provided for @boutonAutoriser.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser l\'accès'**
  String get boutonAutoriser;

  /// No description provided for @boutonInstallerHc.
  ///
  /// In fr, this message translates to:
  /// **'Installer Health Connect'**
  String get boutonInstallerHc;

  /// No description provided for @hcAInstaller.
  ///
  /// In fr, this message translates to:
  /// **'Health Connect doit être installé ou mis à jour sur ce téléphone.'**
  String get hcAInstaller;

  /// No description provided for @hcIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Health Connect n\'est pas disponible sur ce téléphone. Coach utilisera des estimations.'**
  String get hcIndisponible;

  /// No description provided for @accesAccorde.
  ///
  /// In fr, this message translates to:
  /// **'Accès autorisé : Coach lira les données de ta montre.'**
  String get accesAccorde;

  /// No description provided for @accesRefuse.
  ///
  /// In fr, this message translates to:
  /// **'Accès non autorisé. Pas de souci : Coach utilisera des estimations, et tu pourras réessayer plus tard.'**
  String get accesRefuse;

  /// No description provided for @sourceMesure.
  ///
  /// In fr, this message translates to:
  /// **'Mesuré par ta montre'**
  String get sourceMesure;

  /// No description provided for @sourceEstime.
  ///
  /// In fr, this message translates to:
  /// **'Estimé'**
  String get sourceEstime;

  /// No description provided for @maJournee.
  ///
  /// In fr, this message translates to:
  /// **'Ma journée'**
  String get maJournee;

  /// No description provided for @statPas.
  ///
  /// In fr, this message translates to:
  /// **'pas'**
  String get statPas;

  /// No description provided for @statKcal.
  ///
  /// In fr, this message translates to:
  /// **'kcal brûlées'**
  String get statKcal;

  /// No description provided for @statSommeil.
  ///
  /// In fr, this message translates to:
  /// **'de sommeil'**
  String get statSommeil;

  /// No description provided for @statFcRepos.
  ///
  /// In fr, this message translates to:
  /// **'bpm au repos'**
  String get statFcRepos;

  /// No description provided for @dureeHeures.
  ///
  /// In fr, this message translates to:
  /// **'{h} h {m}'**
  String dureeHeures(int h, String m);

  /// No description provided for @connecterMontre.
  ///
  /// In fr, this message translates to:
  /// **'Connecte ta montre'**
  String get connecterMontre;

  /// No description provided for @connecterMontreAide.
  ///
  /// In fr, this message translates to:
  /// **'Pour voir ton activité et ton sommeil, et ajuster tes repères.'**
  String get connecterMontreAide;

  /// No description provided for @aucuneDonneeMontre.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée reçue de ta montre pour l\'instant.'**
  String get aucuneDonneeMontre;

  /// No description provided for @suiviErreur.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire les données de ta montre pour le moment.'**
  String get suiviErreur;

  /// No description provided for @voirDetail.
  ///
  /// In fr, this message translates to:
  /// **'Voir le détail'**
  String get voirDetail;

  /// No description provided for @mesDonnees.
  ///
  /// In fr, this message translates to:
  /// **'Mes données'**
  String get mesDonnees;

  /// No description provided for @sectionActivite.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get sectionActivite;

  /// No description provided for @sectionSommeil.
  ///
  /// In fr, this message translates to:
  /// **'Sommeil'**
  String get sectionSommeil;

  /// No description provided for @sectionCoeur.
  ///
  /// In fr, this message translates to:
  /// **'Cœur et respiration'**
  String get sectionCoeur;

  /// No description provided for @sectionCorps.
  ///
  /// In fr, this message translates to:
  /// **'Corps'**
  String get sectionCorps;

  /// No description provided for @periode7.
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get periode7;

  /// No description provided for @periode30.
  ///
  /// In fr, this message translates to:
  /// **'30 jours'**
  String get periode30;

  /// No description provided for @mesurePas.
  ///
  /// In fr, this message translates to:
  /// **'Pas'**
  String get mesurePas;

  /// No description provided for @mesureKcalActives.
  ///
  /// In fr, this message translates to:
  /// **'Calories actives'**
  String get mesureKcalActives;

  /// No description provided for @mesureDistance.
  ///
  /// In fr, this message translates to:
  /// **'Distance (km)'**
  String get mesureDistance;

  /// No description provided for @mesureEtages.
  ///
  /// In fr, this message translates to:
  /// **'Étages'**
  String get mesureEtages;

  /// No description provided for @mesureSommeil.
  ///
  /// In fr, this message translates to:
  /// **'Durée de sommeil (h)'**
  String get mesureSommeil;

  /// No description provided for @phaseProfond.
  ///
  /// In fr, this message translates to:
  /// **'Profond'**
  String get phaseProfond;

  /// No description provided for @phaseLeger.
  ///
  /// In fr, this message translates to:
  /// **'Léger'**
  String get phaseLeger;

  /// No description provided for @phaseParadoxal.
  ///
  /// In fr, this message translates to:
  /// **'Paradoxal'**
  String get phaseParadoxal;

  /// No description provided for @mesureFcRepos.
  ///
  /// In fr, this message translates to:
  /// **'FC au repos (bpm)'**
  String get mesureFcRepos;

  /// No description provided for @mesureVariabilite.
  ///
  /// In fr, this message translates to:
  /// **'Variabilité cardiaque (ms)'**
  String get mesureVariabilite;

  /// No description provided for @mesureSpo2.
  ///
  /// In fr, this message translates to:
  /// **'Oxygène sanguin (%)'**
  String get mesureSpo2;

  /// No description provided for @mesureFreqResp.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence respiratoire (/min)'**
  String get mesureFreqResp;

  /// No description provided for @mesurePoids.
  ///
  /// In fr, this message translates to:
  /// **'Poids (kg)'**
  String get mesurePoids;

  /// No description provided for @mesureMasseGrasse.
  ///
  /// In fr, this message translates to:
  /// **'Masse grasse (%)'**
  String get mesureMasseGrasse;

  /// No description provided for @derniereValeur.
  ///
  /// In fr, this message translates to:
  /// **'Dernière valeur : {valeur}'**
  String derniereValeur(String valeur);

  /// No description provided for @aucuneDonneePeriode.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée sur cette période.'**
  String get aucuneDonneePeriode;

  /// No description provided for @tabAccueil.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get tabAccueil;

  /// No description provided for @tabPoids.
  ///
  /// In fr, this message translates to:
  /// **'Poids'**
  String get tabPoids;

  /// No description provided for @poidsActuel.
  ///
  /// In fr, this message translates to:
  /// **'Poids actuel'**
  String get poidsActuel;

  /// No description provided for @poidsDepuis.
  ///
  /// In fr, this message translates to:
  /// **'{ecart} kg depuis le {date}'**
  String poidsDepuis(String ecart, String date);

  /// No description provided for @poidsKgValeur.
  ///
  /// In fr, this message translates to:
  /// **'{kg} kg'**
  String poidsKgValeur(String kg);

  /// No description provided for @imcTitre.
  ///
  /// In fr, this message translates to:
  /// **'Ton IMC'**
  String get imcTitre;

  /// No description provided for @imcMaigreur.
  ///
  /// In fr, this message translates to:
  /// **'Maigreur'**
  String get imcMaigreur;

  /// No description provided for @imcNormal.
  ///
  /// In fr, this message translates to:
  /// **'Poids normal'**
  String get imcNormal;

  /// No description provided for @imcSurpoids.
  ///
  /// In fr, this message translates to:
  /// **'Surpoids'**
  String get imcSurpoids;

  /// No description provided for @imcObesite.
  ///
  /// In fr, this message translates to:
  /// **'Obésité'**
  String get imcObesite;

  /// No description provided for @imcAide.
  ///
  /// In fr, this message translates to:
  /// **'L\'IMC est un repère général : il ne tient pas compte de ta masse musculaire.'**
  String get imcAide;

  /// No description provided for @courbePoids.
  ///
  /// In fr, this message translates to:
  /// **'Évolution du poids'**
  String get courbePoids;

  /// No description provided for @periode90.
  ///
  /// In fr, this message translates to:
  /// **'90 jours'**
  String get periode90;

  /// No description provided for @periode1an.
  ///
  /// In fr, this message translates to:
  /// **'1 an'**
  String get periode1an;

  /// No description provided for @ajouterPesee.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une pesée'**
  String get ajouterPesee;

  /// No description provided for @enregistrer.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get enregistrer;

  /// No description provided for @champDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get champDate;

  /// No description provided for @historiquePoids.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get historiquePoids;

  /// No description provided for @supprimerPesee.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get supprimerPesee;

  /// No description provided for @aucunePesee.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pesée pour l\'instant. Ajoute la première !'**
  String get aucunePesee;

  /// No description provided for @sourceMontre.
  ///
  /// In fr, this message translates to:
  /// **'Montre'**
  String get sourceMontre;

  /// No description provided for @sourceSaisie.
  ///
  /// In fr, this message translates to:
  /// **'Saisie'**
  String get sourceSaisie;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
