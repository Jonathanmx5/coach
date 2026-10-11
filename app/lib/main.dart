import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'compte/auth_service.dart';
import 'journal/catalogue.dart';
import 'journal/journal_repository.dart';
import 'poids/mensurations_repository.dart';
import 'poids/pesees_repository.dart';
import 'poids/photos.dart';
import 'entrainement/entrainement_repository.dart';
import 'entrainement/voix.dart';
import 'firebase_options.dart';
import 'profil/profil_repository.dart';
import 'racine.dart';
import 'sante/sante_service.dart';
import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

  runApp(
    CoachApp(
      accueil: Racine(
        services: Services(
          auth: FirebaseAuthService(),
          depot: FirestoreProfilRepository(),
          pesees: FirestorePeseesRepository(),
          mensurations: FirestoreMensurationsRepository(),
          photos: PhotosProgresLocales(),
          entrainement: FirestoreEntrainementRepository(),
          voix: VoixTts(),
          journal: FirestoreJournalRepository(),
          catalogue: CatalogueOpenFoodFacts(),
          sante: HealthSanteService(),
        ),
        horloge: DateTime.now,
      ),
    ),
  );
}
