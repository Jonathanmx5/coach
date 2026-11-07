import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show VoidCallback;

import 'journal/signalement.dart';

/// Lance une écriture Firestore sans l'attendre : hors ligne, l'accusé du
/// serveur n'arrive qu'au retour du réseau, et le cache local est déjà à
/// jour. Une erreur est notée comme non fatale ; un refus des règles
/// (`permission-denied`, le document local est alors retiré) appelle
/// [surRefus] pour prévenir l'utilisateur.
void ecrireSansAttendre(Future<void> ecriture, {VoidCallback? surRefus}) {
  unawaited(
    ecriture.catchError((Object e, StackTrace s) {
      signalerErreur(e, s);
      if (e is FirebaseException && e.code == 'permission-denied') {
        surRefus?.call();
      }
    }),
  );
}
