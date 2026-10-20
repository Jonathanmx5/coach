import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../bienetre/bienetre_repository.dart';
import '../bienetre/hydratation.dart';
import '../firebase_init.dart';
import 'donnees_widget.dart';

/// Eau ajoutée depuis un bouton du widget : on l'enregistre pour [uid] puis on
/// remet à jour le texte du widget. Rend le nouveau total du jour en ml.
///
/// Le total de départ vient du dernier affichage de l'application (clés
/// `eau_ml` et `eau_jour`) ; un autre jour, on repart de zéro.
Future<int> ajouterEauDepuisWidget({
  required String uid,
  required int ml,
  required DateTime maintenant,
  required BienEtreRepository depot,
  required StockageWidget stockage,
}) async {
  // Hors-ligne l'écriture n'aboutit qu'à la synchronisation : on attend un
  // peu qu'elle soit au moins enregistrée sur le téléphone.
  unawaited(depot.ajouterEau(uid, EntreeEau(date: maintenant, ml: ml)));
  await Future<void>.delayed(const Duration(milliseconds: 600));

  final memeJour = await stockage.lire('eau_jour') == cleDuJour(maintenant);
  final avant = memeJour
      ? int.tryParse(await stockage.lire('eau_ml') ?? '') ?? 0
      : 0;
  final objectif =
      int.tryParse(await stockage.lire('eau_objectif_ml') ?? '') ?? 2000;
  final total = avant + ml;
  await stockage.ecrire('eau_ml', '$total');
  await stockage.ecrire('eau_jour', cleDuJour(maintenant));
  await stockage.ecrire('eau_texte', texteEau(total, objectif));
  await stockage.rafraichir();
  return total;
}

/// Appelée par Android quand on touche un bouton d'eau du widget, application
/// fermée : démarre Firebase dans ce processus puis ajoute l'eau.
@pragma('vm:entry-point')
Future<void> rappelWidget(Uri? adresse) async {
  if (adresse == null || adresse.host != 'eau') return;
  final ml = int.tryParse(adresse.queryParameters['ml'] ?? '');
  if (ml == null || ml <= 0 || ml > 2000) return;

  WidgetsFlutterBinding.ensureInitialized();
  // Même démarrage que l'application, App Check compris : sans lui, l'eau
  // ajoutée application fermée serait refusée le jour où la vérification
  // sera imposée.
  await initialiserFirebase();
  final utilisateur =
      FirebaseAuth.instance.currentUser ??
      await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
  if (utilisateur == null) return;

  await ajouterEauDepuisWidget(
    uid: utilisateur.uid,
    ml: ml,
    maintenant: DateTime.now(),
    depot: FirestoreBienEtreRepository(),
    stockage: StockageHomeWidget(),
  );
}
