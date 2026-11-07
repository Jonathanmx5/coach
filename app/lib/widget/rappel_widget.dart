import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../bienetre/bienetre_repository.dart';
import '../bienetre/hydratation.dart';
import '../ecriture.dart';
import '../firebase_init.dart';
import 'donnees_widget.dart';

/// Exécute des tâches une à une, dans l'ordre d'arrivée. Android lance le
/// code Dart du widget sans attendre la fin du précédent appui : sans file,
/// deux appuis rapprochés liraient le même total.
class FileDAttente {
  Future<void> _derniere = Future.value();

  Future<T> ajouter<T>(Future<T> Function() tache) {
    final resultat = Completer<T>();
    _derniere = _derniere.then(
      // Une tâche en échec ne bloque pas les suivantes.
      (_) =>
          Future.sync(tache)
              .then(resultat.complete, onError: resultat.completeError),
    );
    return resultat.future;
  }
}

final _fileEau = FileDAttente();
final _fileRappels = FileDAttente();

/// Eau ajoutée depuis un bouton du widget : on l'enregistre pour [uid] puis on
/// remet à jour le texte du widget. Rend le nouveau total du jour en ml.
///
/// Le total de départ est celui du jour dans le cache Firestore (écritures
/// locales comprises, même hors ligne), pas celui du dernier affichage : il
/// vaut pour ce compte et ce jour. Les appels sont traités un à un.
Future<int> ajouterEauDepuisWidget({
  required String uid,
  required int ml,
  required DateTime maintenant,
  required BienEtreRepository depot,
  required StockageWidget stockage,
  Duration attente = const Duration(milliseconds: 600),
}) => _fileEau.ajouter(
  () => _ajouterEau(
    uid: uid,
    ml: ml,
    maintenant: maintenant,
    depot: depot,
    stockage: stockage,
    attente: attente,
  ),
);

Future<int> _ajouterEau({
  required String uid,
  required int ml,
  required DateTime maintenant,
  required BienEtreRepository depot,
  required StockageWidget stockage,
  required Duration attente,
}) async {
  final jour = cleDuJour(maintenant);
  final debut = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final fin = DateTime(maintenant.year, maintenant.month, maintenant.day + 1);

  final memeCompte = await stockage.lire('uid') == uid;
  if (!memeCompte) {
    // Chiffres d'un autre compte (ou d'avant la déconnexion) : on ne les
    // montre plus à côté de l'eau de celui-ci.
    await retirerDuWidget(stockage, clesDonneesJour);
  }

  int avant;
  try {
    avant = totalEauMl(
      await depot
          .eau(uid, debut, fin)
          .first
          .timeout(const Duration(seconds: 5)),
    );
  } catch (_) {
    // Cache illisible : le dernier total affiché, s'il est de ce compte et
    // de ce jour.
    final memeJour = await stockage.lire('eau_jour') == jour;
    avant = memeCompte && memeJour
        ? int.tryParse(await stockage.lire('eau_ml') ?? '') ?? 0
        : 0;
  }

  // Hors-ligne l'écriture n'aboutit qu'à la synchronisation : on attend un
  // peu qu'elle soit au moins enregistrée sur le téléphone.
  final ecriture = depot.ajouterEau(uid, EntreeEau(date: maintenant, ml: ml));
  ecrireSansAttendre(ecriture);
  await Future.any([
    ecriture.catchError((Object _) {}),
    Future<void>.delayed(attente),
  ]);

  final objectif =
      int.tryParse(await stockage.lire('eau_objectif_ml') ?? '') ?? 2000;
  final total = avant + ml;
  await stockage.ecrire('eau_ml', '$total');
  await stockage.ecrire('eau_jour', jour);
  await stockage.ecrire('eau_texte', texteEau(total, objectif));
  await stockage.ecrire('uid', uid);
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

  // Un appui à la fois, démarrage de Firebase compris.
  await _fileRappels.ajouter(() async {
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
    final stockage = StockageHomeWidget();
    if (utilisateur == null) {
      // Personne de connecté : le widget le dit (« Connecte-toi dans
      // l'appli ») au lieu de ne rien faire.
      await effacerDonneesWidget(stockage);
      return;
    }

    await ajouterEauDepuisWidget(
      uid: utilisateur.uid,
      ml: ml,
      maintenant: DateTime.now(),
      depot: FirestoreBienEtreRepository(),
      stockage: stockage,
    );
  });
}
