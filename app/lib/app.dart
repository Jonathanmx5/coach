import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'theme.dart';

/// Coquille de l'appli : thème, langue française et écran d'entrée.
class CoachApp extends StatelessWidget {
  const CoachApp({super.key, required this.accueil});

  final Widget accueil;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitre,
    debugShowCheckedModeBanner: false,
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: themeCoach(),
    darkTheme: themeCoach(luminosite: Brightness.dark),
    themeMode: ThemeMode.system,
    home: accueil,
  );
}
