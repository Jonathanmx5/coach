import 'package:connectivity_plus/connectivity_plus.dart';

/// État du réseau. Firestore garde les données en cache et envoie les
/// écritures au retour du réseau : l'appli reste utilisable hors-ligne.
abstract class Reseau {
  /// Émet l'état actuel puis chaque changement (true = connecté).
  Stream<bool> get enLigne;
}

class ReseauReel implements Reseau {
  ReseauReel([Connectivity? connectivite])
    : _connectivite = connectivite ?? Connectivity();

  final Connectivity _connectivite;

  static bool _connecte(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  @override
  Stream<bool> get enLigne async* {
    try {
      yield _connecte(await _connectivite.checkConnectivity());
      yield* _connectivite.onConnectivityChanged.map(_connecte);
    } catch (_) {
      yield true;
    }
  }
}
