import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le thème choisi : clair, sombre, ou celui du téléphone (automatique).
/// Gardé sur l'appareil, pour s'appliquer dès l'écran de bienvenue.
abstract class ReglageTheme {
  ValueListenable<ThemeMode> get mode;

  Future<void> definir(ThemeMode mode);
}

class ReglageThemeLocal implements ReglageTheme {
  ReglageThemeLocal._(this._prefs, ThemeMode initial)
    : _mode = ValueNotifier(initial);

  static const _cle = 'theme';

  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> _mode;

  /// Relit le choix enregistré ; automatique par défaut.
  static Future<ReglageThemeLocal> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = ThemeMode.values.asNameMap()[prefs.getString(_cle)];
    return ReglageThemeLocal._(prefs, mode ?? ThemeMode.system);
  }

  @override
  ValueListenable<ThemeMode> get mode => _mode;

  @override
  Future<void> definir(ThemeMode m) async {
    _mode.value = m;
    await _prefs.setString(_cle, m.name);
  }
}

/// Thème qui ne change jamais (tests, repli).
class ReglageThemeFixe implements ReglageTheme {
  ReglageThemeFixe([ThemeMode m = ThemeMode.system]) : _mode = ValueNotifier(m);

  final ValueNotifier<ThemeMode> _mode;

  @override
  ValueListenable<ThemeMode> get mode => _mode;

  @override
  Future<void> definir(ThemeMode m) async => _mode.value = m;
}
