import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// Coquille de l'appli : thème, langue française et écran d'entrée.
class CoachApp extends StatelessWidget {
  const CoachApp({super.key, required this.accueil});

  final Widget accueil;

  static const _couleur = Color(0xFF2E7D5B);
  static const _hauteurBouton = Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final couleurs = ColorScheme.fromSeed(seedColor: _couleur);
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitre,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: couleurs,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: _hauteurBouton),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: _hauteurBouton),
        ),
      ),
      home: accueil,
    );
  }
}
