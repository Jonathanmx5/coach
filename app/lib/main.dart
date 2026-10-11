import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'firebase_options.dart';
import 'profil/profil_repository.dart';
import 'racine.dart';
import 'recettes/avis_repository.dart';
import 'recettes/planning_repository.dart';
import 'reglages/mises_a_jour.dart';
import 'reseau.dart';
import 'widget/donnees_widget.dart';
import 'widget/rappel_widget.dart';
import 'sante/sante_service.dart';
import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Boutons d'eau du widget de l'écran d'accueil (application fermée).
  unawaited(HomeWidget.registerInteractivityCallback(rappelWidget));

  // Hors-ligne : l'appli lit et écrit dans le cache, synchronisé au retour du réseau.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (erreur, pile) {
    unawaited(crashlytics.recordError(erreur, pile, fatal: true));
    return true;
  };

  final auth = FirebaseAuthService();
  runApp(
    CoachApp(
      accueil: Racine(
        services: Services(
          auth: auth,
          depot: FirestoreProfilRepository(),
          pesees: FirestorePeseesRepository(),
          mensurations: FirestoreMensurationsRepository(),
          photos: PhotosProgresLocales(),
          catalogue: CatalogueOpenFoodFacts(),
          photosRepas: PhotosRepasLocales(),
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
          ),
          journal: FirestoreJournalRepository(),
          sante: HealthSanteService(),
        ),
        horloge: DateTime.now,
      ),
    ),
  );
}
