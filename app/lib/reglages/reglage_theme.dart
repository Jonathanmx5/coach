import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// Le thème choisi : clair, sombre, ou celui du téléphone (automatique).
/// Gardé sur l'appareil, pour s'appliquer dès l'écran de bienvenue.
abstract class ReglageTheme {
  ValueListenable<ThemeMode> get mode;

  Future<void> definir(ThemeMode mode);

  /// Teinte des couleurs ; null tant qu'elle n'a jamais été choisie (l'appli
  /// la propose alors au premier lancement).
  ValueListenable<Teinte?> get teinte;

  Future<void> definirTeinte(Teinte teinte);
}

class ReglageThemeLocal implements ReglageTheme {
  ReglageThemeLocal._(this._prefs, ThemeMode initial, Teinte? teinte)
    : _mode = ValueNotifier(initial),
      _teinte = ValueNotifier(teinte);

  static const _cle = 'theme';
  static const _cleTeinte = 'teinte';
  final ValueNotifier<Teinte?> _teinte;

  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> _mode;

  /// Relit le choix enregistré ; automatique par défaut.
  static Future<ReglageThemeLocal> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = ThemeMode.values.asNameMap()[prefs.getString(_cle)];
    final teinte = Teinte.values.asNameMap()[prefs.getString(_cleTeinte)];
    return ReglageThemeLocal._(prefs, mode ?? ThemeMode.system, teinte);
  }

  @override
  ValueListenable<Teinte?> get teinte => _teinte;

  @override
  Future<void> definirTeinte(Teinte t) async {
    _teinte.value = t;
    await _prefs.setString(_cleTeinte, t.name);
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
  ReglageThemeFixe([ThemeMode m = ThemeMode.system, Teinte? t = Teinte.foret])
    : _mode = ValueNotifier(m),
      _teinte = ValueNotifier(t);

  final ValueNotifier<ThemeMode> _mode;
  final ValueNotifier<Teinte?> _teinte;

  @override
  ValueListenable<Teinte?> get teinte => _teinte;

  @override
  Future<void> definirTeinte(Teinte t) async => _teinte.value = t;

  @override
  ValueListenable<ThemeMode> get mode => _mode;

  @override
  Future<void> definir(ThemeMode m) async => _mode.value = m;
}
