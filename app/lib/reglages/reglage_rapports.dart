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
    _actif.value = v;
    await _prefs.setBool(_cle, v);
    await _appliquer(v);
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
