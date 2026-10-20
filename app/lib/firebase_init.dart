import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Démarre Firebase dans ce processus : l'application, App Check et le cache
/// hors ligne de Firestore. Partagée par l'application et par le widget de
/// l'écran d'accueil (qui démarre seul, application fermée), pour que les
/// deux écrivent avec la même preuve App Check et le même cache.
Future<void> initialiserFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  // App Check : prouve que les appels viennent de la vraie application. Sans
  // effet tant que la vérification n'est pas activée côté serveur, et jamais
  // bloquant (APK installé hors Play Store, pas de réseau...).
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}
  // Hors-ligne : l'appli lit et écrit dans le cache, synchronisé au retour du
  // réseau.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
}

/// Vrai si [erreur], non rattrapée, doit compter comme un plantage. Une
/// erreur Firebase (écriture refusée par les règles, réseau...) n'arrête pas
/// l'application : elle est notée comme non fatale.
bool erreurFatale(Object erreur) => erreur is! FirebaseException;
