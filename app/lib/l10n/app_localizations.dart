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

  /// No description provided for @carteProgrammeSous.
  ///
  /// In fr, this message translates to:
  /// **'Ta séance du jour'**
  String get carteProgrammeSous;

  /// No description provided for @carteIdees.
  ///
  /// In fr, this message translates to:
  /// **'Idées de repas'**
  String get carteIdees;

  /// No description provided for @carteIdeesSous.
  ///
  /// In fr, this message translates to:
  /// **'Balaie des idées adaptées à toi'**
  String get carteIdeesSous;

  /// No description provided for @tabSport.
  ///
  /// In fr, this message translates to:
  /// **'Sport'**
  String get tabSport;

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
  /// **'Masse grasse'**
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

  /// No description provided for @projectionLegende.
  ///
  /// In fr, this message translates to:
  /// **'Pointillés : projection sur 5 jours d\'après ton journal des 7 derniers jours.'**
  String get projectionLegende;

  /// No description provided for @mensurationsTitre.
  ///
  /// In fr, this message translates to:
  /// **'Mensurations'**
  String get mensurationsTitre;

  /// No description provided for @mesureTaille.
  ///
  /// In fr, this message translates to:
  /// **'Tour de taille'**
  String get mesureTaille;

  /// No description provided for @mesurePoitrine.
  ///
  /// In fr, this message translates to:
  /// **'Tour de poitrine'**
  String get mesurePoitrine;

  /// No description provided for @mesureBras.
  ///
  /// In fr, this message translates to:
  /// **'Tour de bras'**
  String get mesureBras;

  /// No description provided for @ajouterMesures.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des mesures'**
  String get ajouterMesures;

  /// No description provided for @aucuneMesure.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de mesure. Un mètre ruban suffit !'**
  String get aucuneMesure;

  /// No description provided for @mesuresAide.
  ///
  /// In fr, this message translates to:
  /// **'Remplis seulement ce que tu as mesuré.'**
  String get mesuresAide;

  /// No description provided for @erreurMesures.
  ///
  /// In fr, this message translates to:
  /// **'Entre au moins une mesure.'**
  String get erreurMesures;

  /// No description provided for @photosTitre.
  ///
  /// In fr, this message translates to:
  /// **'Photos de progression'**
  String get photosTitre;

  /// No description provided for @photosAide.
  ///
  /// In fr, this message translates to:
  /// **'Une photo par mois, de face et dans la même lumière. Elles restent sur ton téléphone, rien n\'est envoyé.'**
  String get photosAide;

  /// No description provided for @prendrePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get prendrePhoto;

  /// No description provided for @comparerPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Comparer'**
  String get comparerPhotos;

  /// No description provided for @supprimerPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get supprimerPhoto;

  /// No description provided for @photoAvant.
  ///
  /// In fr, this message translates to:
  /// **'Avant'**
  String get photoAvant;

  /// No description provided for @photoApres.
  ///
  /// In fr, this message translates to:
  /// **'Après'**
  String get photoApres;

  /// No description provided for @tabEntrainement.
  ///
  /// In fr, this message translates to:
  /// **'Entraînement'**
  String get tabEntrainement;

  /// No description provided for @lieuMaison.
  ///
  /// In fr, this message translates to:
  /// **'Maison'**
  String get lieuMaison;

  /// No description provided for @lieuSalle.
  ///
  /// In fr, this message translates to:
  /// **'Salle'**
  String get lieuSalle;

  /// No description provided for @lieuCourse.
  ///
  /// In fr, this message translates to:
  /// **'Course à pied'**
  String get lieuCourse;

  /// No description provided for @lieuMarche.
  ///
  /// In fr, this message translates to:
  /// **'Marche'**
  String get lieuMarche;

  /// No description provided for @materielHalteres.
  ///
  /// In fr, this message translates to:
  /// **'Haltères'**
  String get materielHalteres;

  /// No description provided for @materielElastiques.
  ///
  /// In fr, this message translates to:
  /// **'Élastiques'**
  String get materielElastiques;

  /// No description provided for @materielBarre.
  ///
  /// In fr, this message translates to:
  /// **'Barre de traction'**
  String get materielBarre;

  /// No description provided for @materielKettlebell.
  ///
  /// In fr, this message translates to:
  /// **'Kettlebell'**
  String get materielKettlebell;

  /// No description provided for @materielBanc.
  ///
  /// In fr, this message translates to:
  /// **'Banc'**
  String get materielBanc;

  /// No description provided for @materielCorde.
  ///
  /// In fr, this message translates to:
  /// **'Corde à sauter'**
  String get materielCorde;

  /// No description provided for @monMateriel.
  ///
  /// In fr, this message translates to:
  /// **'Mon matériel'**
  String get monMateriel;

  /// No description provided for @materielAide.
  ///
  /// In fr, this message translates to:
  /// **'Coche ce que tu as chez toi : sans matériel, on remplace par un exercice au poids du corps.'**
  String get materielAide;

  /// No description provided for @commencerSeance.
  ///
  /// In fr, this message translates to:
  /// **'Commencer la séance'**
  String get commencerSeance;

  /// No description provided for @seanceTerminee.
  ///
  /// In fr, this message translates to:
  /// **'Séance terminée, bravo !'**
  String get seanceTerminee;

  /// No description provided for @terminer.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get terminer;

  /// No description provided for @couperVoix.
  ///
  /// In fr, this message translates to:
  /// **'Couper la voix'**
  String get couperVoix;

  /// No description provided for @activerVoix.
  ///
  /// In fr, this message translates to:
  /// **'Activer la voix'**
  String get activerVoix;

  /// No description provided for @reprendre.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get reprendre;

  /// No description provided for @pause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @passer.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get passer;

  /// No description provided for @fait.
  ///
  /// In fr, this message translates to:
  /// **'Fait'**
  String get fait;

  /// No description provided for @seancesSemaine.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine : {faites} séance(s) sur {prevues}'**
  String seancesSemaine(int faites, int prevues);

  /// No description provided for @dureeEstimee.
  ///
  /// In fr, this message translates to:
  /// **'Environ {minutes} min'**
  String dureeEstimee(int minutes);

  /// No description provided for @remplace.
  ///
  /// In fr, this message translates to:
  /// **'remplace {nom}'**
  String remplace(String nom);

  /// No description provided for @repetitions.
  ///
  /// In fr, this message translates to:
  /// **'{n} répétitions'**
  String repetitions(int n);

  /// No description provided for @recuperationTitre.
  ///
  /// In fr, this message translates to:
  /// **'Récupération'**
  String get recuperationTitre;

  /// No description provided for @recuperationVide.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de donnée de sommeil. Dis-nous comment tu te sens, ou connecte ta montre.'**
  String get recuperationVide;

  /// No description provided for @recuperationBon.
  ///
  /// In fr, this message translates to:
  /// **'Feu vert : tu peux faire ta séance normalement.'**
  String get recuperationBon;

  /// No description provided for @recuperationMoyen.
  ///
  /// In fr, this message translates to:
  /// **'Récupération correcte : écoute ton corps, évite de forcer sur l\'intensité.'**
  String get recuperationMoyen;

  /// No description provided for @recuperationFaible.
  ///
  /// In fr, this message translates to:
  /// **'Corps fatigué : privilégie une marche, des étirements ou du repos aujourd\'hui.'**
  String get recuperationFaible;

  /// No description provided for @ressentiQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Comment te sens-tu ce matin ?'**
  String get ressentiQuestion;

  /// No description provided for @ressentiFatigue.
  ///
  /// In fr, this message translates to:
  /// **'Fatigué'**
  String get ressentiFatigue;

  /// No description provided for @ressentiMoyen.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get ressentiMoyen;

  /// No description provided for @ressentiForme.
  ///
  /// In fr, this message translates to:
  /// **'En forme'**
  String get ressentiForme;

  /// No description provided for @mobiliteTitre.
  ///
  /// In fr, this message translates to:
  /// **'Mobilité et étirements'**
  String get mobiliteTitre;

  /// No description provided for @routineApresEffort.
  ///
  /// In fr, this message translates to:
  /// **'Étirements après l\'effort'**
  String get routineApresEffort;

  /// No description provided for @routineReveil.
  ///
  /// In fr, this message translates to:
  /// **'Réveil articulaire (5 min)'**
  String get routineReveil;

  /// No description provided for @routineRecuperation.
  ///
  /// In fr, this message translates to:
  /// **'Récupération douce (8 min)'**
  String get routineRecuperation;

  /// No description provided for @conseilleMaintenant.
  ///
  /// In fr, this message translates to:
  /// **'Conseillé maintenant'**
  String get conseilleMaintenant;

  /// No description provided for @tabBienEtre.
  ///
  /// In fr, this message translates to:
  /// **'Bien-être'**
  String get tabBienEtre;

  /// No description provided for @hydratationTitre.
  ///
  /// In fr, this message translates to:
  /// **'Hydratation'**
  String get hydratationTitre;

  /// No description provided for @eauBueSur.
  ///
  /// In fr, this message translates to:
  /// **'{bu} L sur {objectif} L'**
  String eauBueSur(String bu, String objectif);

  /// No description provided for @eauBaseProfil.
  ///
  /// In fr, this message translates to:
  /// **'Selon ton poids'**
  String get eauBaseProfil;

  /// No description provided for @eauEffort.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min d\'effort'**
  String eauEffort(int minutes);

  /// No description provided for @eauChaleur.
  ///
  /// In fr, this message translates to:
  /// **'{degres} °C aujourd\'hui'**
  String eauChaleur(int degres);

  /// No description provided for @ajouterEau.
  ///
  /// In fr, this message translates to:
  /// **'+ {ml} ml'**
  String ajouterEau(int ml);

  /// No description provided for @annulerDernier.
  ///
  /// In fr, this message translates to:
  /// **'Annuler le dernier'**
  String get annulerDernier;

  /// No description provided for @adapterMeteo.
  ///
  /// In fr, this message translates to:
  /// **'Adapter à la météo'**
  String get adapterMeteo;

  /// No description provided for @meteoAide.
  ///
  /// In fr, this message translates to:
  /// **'Utilise ta position approximative pour la température du jour. Elle n\'est pas enregistrée.'**
  String get meteoAide;

  /// No description provided for @annuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get annuler;

  /// No description provided for @complementsTitre.
  ///
  /// In fr, this message translates to:
  /// **'Compléments'**
  String get complementsTitre;

  /// No description provided for @complementsAide.
  ///
  /// In fr, this message translates to:
  /// **'Un rappel par jour pour ne pas oublier. Coach ne conseille aucune dose : demande à ton médecin ou à ton pharmacien.'**
  String get complementsAide;

  /// No description provided for @ajouterComplement.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un complément'**
  String get ajouterComplement;

  /// No description provided for @nomComplement.
  ///
  /// In fr, this message translates to:
  /// **'Nom (ex. vitamine D)'**
  String get nomComplement;

  /// No description provided for @rappelA.
  ///
  /// In fr, this message translates to:
  /// **'Rappel à {heure}'**
  String rappelA(String heure);

  /// No description provided for @rappelDesactive.
  ///
  /// In fr, this message translates to:
  /// **'Rappel désactivé'**
  String get rappelDesactive;

  /// No description provided for @optionsComplement.
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get optionsComplement;

  /// No description provided for @activerRappel.
  ///
  /// In fr, this message translates to:
  /// **'Activer le rappel'**
  String get activerRappel;

  /// No description provided for @desactiverRappel.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le rappel'**
  String get desactiverRappel;

  /// No description provided for @supprimerComplement.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get supprimerComplement;

  /// No description provided for @seriesTitre.
  ///
  /// In fr, this message translates to:
  /// **'Tes séries'**
  String get seriesTitre;

  /// No description provided for @serieJournal.
  ///
  /// In fr, this message translates to:
  /// **'Journal tenu'**
  String get serieJournal;

  /// No description provided for @serieEntrainement.
  ///
  /// In fr, this message translates to:
  /// **'Séance faite'**
  String get serieEntrainement;

  /// No description provided for @serieEau.
  ///
  /// In fr, this message translates to:
  /// **'Objectif d\'eau atteint'**
  String get serieEau;

  /// No description provided for @nbJours.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{0 jour} =1{1 jour} other{{n} jours}}'**
  String nbJours(int n);

  /// No description provided for @horsLigne.
  ///
  /// In fr, this message translates to:
  /// **'Hors-ligne : tes saisies sont gardées et seront envoyées au retour du réseau.'**
  String get horsLigne;

  /// No description provided for @menuPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo du repas'**
  String get menuPhoto;

  /// No description provided for @analyseEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Analyse de ton repas…'**
  String get analyseEnCours;

  /// No description provided for @analyseReseau.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion pour analyser la photo. Réessaie quand le réseau revient, ou saisis le repas à la main.'**
  String get analyseReseau;

  /// No description provided for @analyseAuth.
  ///
  /// In fr, this message translates to:
  /// **'Ta session a expiré. Reconnecte-toi pour analyser une photo.'**
  String get analyseAuth;

  /// No description provided for @analyseQuota.
  ///
  /// In fr, this message translates to:
  /// **'Tu as atteint la limite de photos analysées pour aujourd\'hui (ou le service est très sollicité). Saisis le repas à la main, ou réessaie demain.'**
  String get analyseQuota;

  /// No description provided for @analyseIllisible.
  ///
  /// In fr, this message translates to:
  /// **'Je n\'ai pas réussi à lire cette photo. Essaie avec plus de lumière, ou saisis le repas à la main.'**
  String get analyseIllisible;

  /// No description provided for @analyseIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Le service d\'analyse est indisponible pour le moment.'**
  String get analyseIndisponible;

  /// No description provided for @reessayer.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get reessayer;

  /// No description provided for @saisirALaMain.
  ///
  /// In fr, this message translates to:
  /// **'Saisir à la main'**
  String get saisirALaMain;

  /// No description provided for @aucunAliment.
  ///
  /// In fr, this message translates to:
  /// **'Je ne vois pas d\'aliment sur cette photo.'**
  String get aucunAliment;

  /// No description provided for @estimationAVerifier.
  ///
  /// In fr, this message translates to:
  /// **'Estimation par IA, à vérifier : décoche ce qui est faux et corrige les portions.'**
  String get estimationAVerifier;

  /// No description provided for @changerPortion.
  ///
  /// In fr, this message translates to:
  /// **'Changer la portion'**
  String get changerPortion;

  /// No description provided for @planningTitre.
  ///
  /// In fr, this message translates to:
  /// **'Repas de la semaine'**
  String get planningTitre;

  /// No description provided for @planningAide.
  ///
  /// In fr, this message translates to:
  /// **'Des repas simples qui visent tes {kcal} kcal par jour. Touche un repas pour voir la recette.'**
  String planningAide(int kcal);

  /// No description provided for @sansViande.
  ///
  /// In fr, this message translates to:
  /// **'Sans viande ni poisson'**
  String get sansViande;

  /// No description provided for @nbPortions.
  ///
  /// In fr, this message translates to:
  /// **'{n} portion(s)'**
  String nbPortions(String n);

  /// No description provided for @minutesValeur.
  ///
  /// In fr, this message translates to:
  /// **'{n} min'**
  String minutesValeur(int n);

  /// No description provided for @ingredientsTitre.
  ///
  /// In fr, this message translates to:
  /// **'Ingrédients'**
  String get ingredientsTitre;

  /// No description provided for @preparationTitre.
  ///
  /// In fr, this message translates to:
  /// **'Préparation'**
  String get preparationTitre;

  /// No description provided for @ajouterAuJournal.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au journal'**
  String get ajouterAuJournal;

  /// No description provided for @changerRecette.
  ///
  /// In fr, this message translates to:
  /// **'Changer de recette'**
  String get changerRecette;

  /// No description provided for @repasAjoute.
  ///
  /// In fr, this message translates to:
  /// **'Repas ajouté au journal.'**
  String get repasAjoute;

  /// No description provided for @coursesTitre.
  ///
  /// In fr, this message translates to:
  /// **'Liste de courses'**
  String get coursesTitre;

  /// No description provided for @coursesAide.
  ///
  /// In fr, this message translates to:
  /// **'Tout ce qu\'il faut pour la semaine, rangé par rayon.'**
  String get coursesAide;

  /// No description provided for @rayonFruitsLegumes.
  ///
  /// In fr, this message translates to:
  /// **'Fruits et légumes'**
  String get rayonFruitsLegumes;

  /// No description provided for @rayonBoulangerie.
  ///
  /// In fr, this message translates to:
  /// **'Boulangerie'**
  String get rayonBoulangerie;

  /// No description provided for @rayonViandePoisson.
  ///
  /// In fr, this message translates to:
  /// **'Viandes et poissons'**
  String get rayonViandePoisson;

  /// No description provided for @rayonCremerie.
  ///
  /// In fr, this message translates to:
  /// **'Crèmerie et œufs'**
  String get rayonCremerie;

  /// No description provided for @rayonEpicerie.
  ///
  /// In fr, this message translates to:
  /// **'Épicerie'**
  String get rayonEpicerie;

  /// No description provided for @menuPlanning.
  ///
  /// In fr, this message translates to:
  /// **'Repas de la semaine'**
  String get menuPlanning;

  /// No description provided for @ideesTitre.
  ///
  /// In fr, this message translates to:
  /// **'Idées de repas'**
  String get ideesTitre;

  /// No description provided for @mesEnvies.
  ///
  /// In fr, this message translates to:
  /// **'Mes envies'**
  String get mesEnvies;

  /// No description provided for @tousLesRepas.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get tousLesRepas;

  /// No description provided for @ideesTerminees.
  ///
  /// In fr, this message translates to:
  /// **'Tu as fait le tour des idées pour ce choix ! Retrouve tes préférées dans « Mes envies », ou change de type de repas.'**
  String get ideesTerminees;

  /// No description provided for @jeNaimePas.
  ///
  /// In fr, this message translates to:
  /// **'Je n\'aime pas'**
  String get jeNaimePas;

  /// No description provided for @jAimePlusTard.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime, pour une prochaine fois'**
  String get jAimePlusTard;

  /// No description provided for @photosIllustratives.
  ///
  /// In fr, this message translates to:
  /// **'Photos illustratives générées par IA.'**
  String get photosIllustratives;

  /// No description provided for @etiquetteEnvie.
  ///
  /// In fr, this message translates to:
  /// **'ENVIE'**
  String get etiquetteEnvie;

  /// No description provided for @etiquetteNon.
  ///
  /// In fr, this message translates to:
  /// **'NON'**
  String get etiquetteNon;

  /// No description provided for @pourToiKcal.
  ///
  /// In fr, this message translates to:
  /// **'≈ {kcal} kcal pour toi'**
  String pourToiKcal(int kcal);

  /// No description provided for @vegetarienCourt.
  ///
  /// In fr, this message translates to:
  /// **'végé'**
  String get vegetarienCourt;

  /// No description provided for @aucuneEnvie.
  ///
  /// In fr, this message translates to:
  /// **'Aucune envie pour l\'instant. Balaie une carte vers la droite pour garder une recette pour une prochaine fois.'**
  String get aucuneEnvie;

  /// No description provided for @retirerEnvie.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de mes envies'**
  String get retirerEnvie;

  /// No description provided for @menuIdees.
  ///
  /// In fr, this message translates to:
  /// **'Idées de repas'**
  String get menuIdees;

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

  /// No description provided for @tabJournal.
  ///
  /// In fr, this message translates to:
  /// **'Repas'**
  String get tabJournal;

  /// No description provided for @jourAujourdhui.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get jourAujourdhui;

  /// No description provided for @jourPrecedent.
  ///
  /// In fr, this message translates to:
  /// **'Jour précédent'**
  String get jourPrecedent;

  /// No description provided for @jourSuivant.
  ///
  /// In fr, this message translates to:
  /// **'Jour suivant'**
  String get jourSuivant;

  /// No description provided for @bilanTitre.
  ///
  /// In fr, this message translates to:
  /// **'Bilan énergétique'**
  String get bilanTitre;

  /// No description provided for @bilanMange.
  ///
  /// In fr, this message translates to:
  /// **'Mangé'**
  String get bilanMange;

  /// No description provided for @bilanDepense.
  ///
  /// In fr, this message translates to:
  /// **'Dépensé'**
  String get bilanDepense;

  /// No description provided for @bilanSolde.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get bilanSolde;

  /// No description provided for @kcalValeur.
  ///
  /// In fr, this message translates to:
  /// **'{kcal} kcal'**
  String kcalValeur(String kcal);

  /// No description provided for @soldeDeficit.
  ///
  /// In fr, this message translates to:
  /// **'Déficit'**
  String get soldeDeficit;

  /// No description provided for @soldeExcedent.
  ///
  /// In fr, this message translates to:
  /// **'Excédent'**
  String get soldeExcedent;

  /// No description provided for @cibleJour.
  ///
  /// In fr, this message translates to:
  /// **'Objectif du jour : {kcal} kcal'**
  String cibleJour(int kcal);

  /// No description provided for @jourRepos.
  ///
  /// In fr, this message translates to:
  /// **'Jour de repos'**
  String get jourRepos;

  /// No description provided for @jourModere.
  ///
  /// In fr, this message translates to:
  /// **'Jour modéré'**
  String get jourModere;

  /// No description provided for @jourIntense.
  ///
  /// In fr, this message translates to:
  /// **'Jour intense'**
  String get jourIntense;

  /// No description provided for @macrosTitre.
  ///
  /// In fr, this message translates to:
  /// **'Macros du jour'**
  String get macrosTitre;

  /// No description provided for @macroProteines.
  ///
  /// In fr, this message translates to:
  /// **'Protéines'**
  String get macroProteines;

  /// No description provided for @macroGlucides.
  ///
  /// In fr, this message translates to:
  /// **'Glucides'**
  String get macroGlucides;

  /// No description provided for @macroLipides.
  ///
  /// In fr, this message translates to:
  /// **'Lipides'**
  String get macroLipides;

  /// No description provided for @macroProgression.
  ///
  /// In fr, this message translates to:
  /// **'{mange} / {cible} g'**
  String macroProgression(int mange, int cible);

  /// No description provided for @repasTitre.
  ///
  /// In fr, this message translates to:
  /// **'Repas'**
  String get repasTitre;

  /// No description provided for @activitesTitre.
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get activitesTitre;

  /// No description provided for @aucunRepas.
  ///
  /// In fr, this message translates to:
  /// **'Aucun repas enregistré.'**
  String get aucunRepas;

  /// No description provided for @aucuneActivite.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité enregistrée.'**
  String get aucuneActivite;

  /// No description provided for @momentPetitDej.
  ///
  /// In fr, this message translates to:
  /// **'Petit-déjeuner'**
  String get momentPetitDej;

  /// No description provided for @momentDejeuner.
  ///
  /// In fr, this message translates to:
  /// **'Déjeuner'**
  String get momentDejeuner;

  /// No description provided for @momentDiner.
  ///
  /// In fr, this message translates to:
  /// **'Dîner'**
  String get momentDiner;

  /// No description provided for @momentCollation.
  ///
  /// In fr, this message translates to:
  /// **'Collation'**
  String get momentCollation;

  /// No description provided for @menuRepas.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un repas'**
  String get menuRepas;

  /// No description provided for @menuScanner.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un produit'**
  String get menuScanner;

  /// No description provided for @menuActivite.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une activité'**
  String get menuActivite;

  /// No description provided for @ajouter.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get ajouter;

  /// No description provided for @champNomRepas.
  ///
  /// In fr, this message translates to:
  /// **'Nom du repas'**
  String get champNomRepas;

  /// No description provided for @champKcal.
  ///
  /// In fr, this message translates to:
  /// **'Calories (kcal)'**
  String get champKcal;

  /// No description provided for @champProteines.
  ///
  /// In fr, this message translates to:
  /// **'Protéines (g)'**
  String get champProteines;

  /// No description provided for @champGlucides.
  ///
  /// In fr, this message translates to:
  /// **'Glucides (g)'**
  String get champGlucides;

  /// No description provided for @champLipides.
  ///
  /// In fr, this message translates to:
  /// **'Lipides (g)'**
  String get champLipides;

  /// No description provided for @champMoment.
  ///
  /// In fr, this message translates to:
  /// **'Moment'**
  String get champMoment;

  /// No description provided for @nomRepasDefaut.
  ///
  /// In fr, this message translates to:
  /// **'Repas'**
  String get nomRepasDefaut;

  /// No description provided for @scanTitre.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un produit'**
  String get scanTitre;

  /// No description provided for @scanAide.
  ///
  /// In fr, this message translates to:
  /// **'Place le code-barres dans le cadre.'**
  String get scanAide;

  /// No description provided for @scanOuSaisir.
  ///
  /// In fr, this message translates to:
  /// **'Ou saisis le code à la main'**
  String get scanOuSaisir;

  /// No description provided for @champCode.
  ///
  /// In fr, this message translates to:
  /// **'Code-barres'**
  String get champCode;

  /// No description provided for @scanRechercher.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get scanRechercher;

  /// No description provided for @produitIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Produit introuvable. Tu peux l\'ajouter à la main.'**
  String get produitIntrouvable;

  /// No description provided for @erreurReseauProduit.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre Open Food Facts. Vérifie ta connexion.'**
  String get erreurReseauProduit;

  /// No description provided for @champQuantite.
  ///
  /// In fr, this message translates to:
  /// **'Quantité (g)'**
  String get champQuantite;

  /// No description provided for @produitPour100g.
  ///
  /// In fr, this message translates to:
  /// **'Pour 100 g : {kcal} kcal'**
  String produitPour100g(int kcal);

  /// No description provided for @actVelo.
  ///
  /// In fr, this message translates to:
  /// **'Vélo'**
  String get actVelo;

  /// No description provided for @actMma.
  ///
  /// In fr, this message translates to:
  /// **'MMA'**
  String get actMma;

  /// No description provided for @actCourse.
  ///
  /// In fr, this message translates to:
  /// **'Course à pied'**
  String get actCourse;

  /// No description provided for @actNatation.
  ///
  /// In fr, this message translates to:
  /// **'Natation'**
  String get actNatation;

  /// No description provided for @actMuscu.
  ///
  /// In fr, this message translates to:
  /// **'Musculation'**
  String get actMuscu;

  /// No description provided for @actMarche.
  ///
  /// In fr, this message translates to:
  /// **'Marche'**
  String get actMarche;

  /// No description provided for @actAutre.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get actAutre;

  /// No description provided for @champDureeMin.
  ///
  /// In fr, this message translates to:
  /// **'Durée (min)'**
  String get champDureeMin;

  /// No description provided for @intLegere.
  ///
  /// In fr, this message translates to:
  /// **'Légère'**
  String get intLegere;

  /// No description provided for @intModeree.
  ///
  /// In fr, this message translates to:
  /// **'Modérée'**
  String get intModeree;

  /// No description provided for @intIntense.
  ///
  /// In fr, this message translates to:
  /// **'Intense'**
  String get intIntense;

  /// No description provided for @activiteEstimation.
  ///
  /// In fr, this message translates to:
  /// **'≈ {kcal} kcal brûlées'**
  String activiteEstimation(int kcal);

  /// No description provided for @supprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get supprimer;

  /// No description provided for @erreurDuree.
  ///
  /// In fr, this message translates to:
  /// **'Entre une durée en minutes.'**
  String get erreurDuree;
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
