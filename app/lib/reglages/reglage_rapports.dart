import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Envoi des rapports de plantage (Crashlytics) : activé par défaut, gardé
/// sur l'appareil et appliqué dès le démarrage, avant toute connexion.
abstract class ReglageRapports {
  ValueListenable<bool> get actif;

  Future<void> definir(bool actif);
}

/// Applique le choix au service de rapports (Crashlytics dans l'appli).
typedef AppliquerRapports = Future<void> Function(bool actif);

/// Règle la collecte : jamais en [debug], sinon selon [actif]. Un refus
/// coupe d'abord la collecte, puis efface les rapports en attente d'envoi :
/// rien de ce qui a été noté avant le refus ne part plus tard. Une erreur du
/// service n'empêche pas l'appli de démarrer.
Future<void> appliquerChoixRapports({
  required bool actif,
  required bool debug,
  required Future<void> Function(bool) activerCollecte,
  required Future<void> Function() effacerEnAttente,
}) async {
  try {
    await activerCollecte(actif && !debug);
  } catch (_) {
    // Service indisponible : il ne peut rien envoyer non plus.
  }
  if (actif) return;
  try {
    await effacerEnAttente();
  } catch (_) {
    // Rien en attente, ou service indisponible.
  }
}

class ReglageRapportsLocal implements ReglageRapports {
  ReglageRapportsLocal._(this._prefs, bool initial, this._appliquer)
    : _actif = ValueNotifier(initial);

  static const _cle = 'rapports_plantage';

  final SharedPreferences _prefs;
  final ValueNotifier<bool> _actif;
  final AppliquerRapports _appliquer;

  /// Relit le choix enregistré ; activé par défaut.
  static Future<ReglageRapportsLocal> charger({
    required AppliquerRapports appliquer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return ReglageRapportsLocal._(
      prefs,
      prefs.getBool(_cle) ?? true,
      appliquer,
    );
  }

  @override
  ValueListenable<bool> get actif => _actif;

  @override
  Future<void> definir(bool v) async {
    // Appliqué d'abord : un refus vaut tout de suite, même si l'écriture
    // du choix échoue (il vaut alors jusqu'à la fermeture de l'appli).
    _actif.value = v;
    await _appliquer(v);
    try {
      await _prefs.setBool(_cle, v);
    } catch (_) {
      // Stockage indisponible.
    }
  }
}

/// Choix en mémoire seulement (tests, repli si le stockage échoue).
class ReglageRapportsFixe implements ReglageRapports {
  ReglageRapportsFixe([bool v = true, AppliquerRapports? appliquer])
    : _actif = ValueNotifier(v),
      _appliquer = appliquer;

  final ValueNotifier<bool> _actif;
  final AppliquerRapports? _appliquer;

  @override
  ValueListenable<bool> get actif => _actif;

  @override
  Future<void> definir(bool v) async {
    _actif.value = v;
    await _appliquer?.call(v);
  }
}
