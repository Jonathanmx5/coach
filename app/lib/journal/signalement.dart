import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Note une erreur inattendue dans le journal d'erreurs, sans la rendre
/// fatale : l'écran l'a déjà prise en charge (message, retour en arrière).
/// Sans Firebase (tests), l'erreur est seulement affichée en mode debug.
void signalerErreur(Object erreur, StackTrace pile) {
  if (kDebugMode) debugPrint('Erreur non fatale : $erreur');
  try {
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(erreur, pile, fatal: false)
          .catchError((Object _) {}),
    );
  } catch (_) {}
}
