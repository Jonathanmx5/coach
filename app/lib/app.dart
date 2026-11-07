import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'reglages/choix_teinte.dart';
import 'theme.dart';

/// Coquille de l'appli : thème, langue française et écran d'entrée.
class CoachApp extends StatefulWidget {
  const CoachApp({
    super.key,
    required this.accueil,
    this.theme,
    this.teinte,
    this.choisirTeinte,
  });

  final Widget accueil;

  /// Thème choisi (clair, sombre, automatique) ; automatique si absent.
  final ValueListenable<ThemeMode>? theme;

  /// Teinte choisie ; Forêt si absente. Null dans la valeur : jamais
  /// choisie, l'écran de choix passe avant [accueil].
  final ValueListenable<Teinte?>? teinte;

  /// Enregistre la teinte choisie au premier lancement.
  final Future<void> Function(Teinte)? choisirTeinte;

  @override
  State<CoachApp> createState() => _CoachAppState();
}

class _CoachAppState extends State<CoachApp> {
  /// Teinte touchée sur l'écran de choix, pas encore enregistrée.
  Teinte? _apercu;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.theme ?? const _Automatique(),
      widget.teinte,
    ]),
    builder: (context, _) {
      final enregistree = widget.teinte?.value;
      final aChoisir =
          widget.teinte != null &&
          enregistree == null &&
          widget.choisirTeinte != null;
      teinteActive = enregistree ?? _apercu ?? Teinte.foret;
      return MaterialApp(
        onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitre,
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: themeCoach(),
        darkTheme: themeCoach(luminosite: Brightness.dark),
        themeMode: (widget.theme ?? const _Automatique()).value,
        home: aChoisir
            ? ChoixTeintePage(
                onApercu: (t) => setState(() => _apercu = t),
                onChoisie: (t) => widget.choisirTeinte!(t),
              )
            : widget.accueil,
      );
    },
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
