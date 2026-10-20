import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app.dart';
import 'bienetre/bienetre_repository.dart';
import 'bienetre/meteo.dart';
import 'bienetre/rappels.dart';
import 'compte/auth_service.dart';
import 'compte/donnees_compte.dart';
import 'journal/journal_repository.dart';
import 'poids/mensurations_repository.dart';
import 'poids/pesees_repository.dart';
import 'journal/catalogue.dart';
import 'journal/photos_repas.dart';
import 'poids/photos.dart';
import 'entrainement/entrainement_repository.dart';
import 'journal/analyse_photo.dart';
import 'entrainement/voix.dart';
import 'firebase_init.dart';
import 'profil/profil_repository.dart';
import 'racine.dart';
import 'recettes/avis_repository.dart';
import 'recettes/planning_repository.dart';
import 'reglages/mises_a_jour.dart';
import 'reglages/reglage_theme.dart';
import 'sauvegarde/fichiers.dart';
import 'sauvegarde/sauvegarde.dart';
import 'reseau.dart';
import 'widget/donnees_widget.dart';
import 'widget/rappel_widget.dart';
import 'sante/sante_service.dart';
import 'services.dart';

/// Le thème enregistré ; si le stockage échoue, celui du téléphone.
Future<ReglageTheme> _chargerTheme() async {
  try {
    return await ReglageThemeLocal.charger();
  } catch (_) {
    return ReglageThemeFixe();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialiserFirebase();
  // Boutons d'eau du widget de l'écran d'accueil (application fermée).
  unawaited(HomeWidget.registerInteractivityCallback(rappelWidget));

  // Une erreur Firebase non rattrapée (écriture refusée, réseau) est notée
  // sans compter comme un plantage.
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = (details) => erreurFatale(details.exception)
      ? crashlytics.recordFlutterFatalError(details)
      : crashlytics.recordFlutterError(details);
  PlatformDispatcher.instance.onError = (erreur, pile) {
    unawaited(
      crashlytics.recordError(erreur, pile, fatal: erreurFatale(erreur)),
    );
    return true;
  };

  final auth = FirebaseAuthService();
  final theme = await _chargerTheme();
  runApp(
    CoachApp(
      theme: theme.mode,
      accueil: Racine(
        services: Services(
          auth: auth,
          depot: FirestoreProfilRepository(),
          pesees: FirestorePeseesRepository(),
          mensurations: FirestoreMensurationsRepository(),
          photos: PhotosProgresLocales(),
          catalogue: CatalogueOpenFoodFacts(),
          photosRepas: PhotosRepasLocales(),
          theme: theme,
          sauvegarde: SauvegardeFirestore(),
          fichiers: FichiersSysteme(),
          entrainement: FirestoreEntrainementRepository(),
          voix: VoixTts(),
          bienetre: FirestoreBienEtreRepository(),
          meteo: MeteoOpenMeteo(),
          rappels: RappelsLocaux(),
          reseau: ReseauReel(),
          planning: FirestorePlanningRepository(),
          avis: FirestoreAvisRepository(),
          miseAJour: MisesAJourGithub(),
          versionAppli: VersionAppliReelle(),
          donnees: FirestoreDonneesCompte(),
          consentements: FirestoreConsentementsRepository(),
          widgetAccueil: WidgetAccueil(),
          ouvrirLien: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
          analyse: AnalysePhotoRelais(
            url: const String.fromEnvironment('RELAIS_URL'),
            jeton: auth.jeton,
            preuve: () async {
              try {
                return await FirebaseAppCheck.instance.getToken();
              } catch (_) {
                return null;
              }
            },
          ),
          journal: FirestoreJournalRepository(),
          sante: HealthSanteService(),
        ),
        horloge: DateTime.now,
      ),
    ),
  );
}
