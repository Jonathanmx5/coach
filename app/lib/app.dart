import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'theme.dart';

/// Coquille de l'appli : thème, langue française et écran d'entrée.
class CoachApp extends StatelessWidget {
  const CoachApp({super.key, required this.accueil, this.theme});

  final Widget accueil;

  /// Thème choisi (clair, sombre, automatique) ; automatique si absent.
  final ValueListenable<ThemeMode>? theme;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: theme ?? const _Automatique(),
    builder: (context, mode, _) => _app(mode),
  );

  Widget _app(ThemeMode mode) => MaterialApp(
    onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitre,
    debugShowCheckedModeBanner: false,
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: themeCoach(),
    darkTheme: themeCoach(luminosite: Brightness.dark),
    themeMode: mode,
    home: accueil,
  );
}

class _Automatique implements ValueListenable<ThemeMode> {
  const _Automatique();

  @override
  ThemeMode get value => ThemeMode.system;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
