import 'package:flutter/material.dart';

/// Palette Coach : vert pour le sport et l'identité, orange pour l'assiette.
abstract final class CouleursCoach {
  static const vert = Color(0xFF0F6E56);
  static const vertMoyen = Color(0xFF1D9E75);
  static const vertFonce = Color(0xFF085041);
  static const vertClair = Color(0xFFE1F5EE);
  static const vertPale = Color(0xFF9FE1CB);
  static const vertVif = Color(0xFF2BB98A);
  static const bleu = Color(0xFF378ADD);
  static const bleuClair = Color(0xFF6CB4EE);
  static const orange = Color(0xFFEF9F27);
  static const orangeClair = Color(0xFFFAEEDA);
  static const orangeFonce = Color(0xFF633806);
  static const fond = Color(0xFFF6F8F5);
  static const bordure = Color(0xFFD3D1C7);
  static const texte = Color(0xFF2C2C2A);
  static const texteDoux = Color(0xFF5F5E5A);
}

const rayonCarte = 16.0;
const rayonBouton = 14.0;

ThemeData themeCoach() {
  final couleurs = ColorScheme.fromSeed(
    seedColor: CouleursCoach.vert,
    primary: CouleursCoach.vert,
    tertiary: CouleursCoach.orange,
    surface: CouleursCoach.fond,
  );
  final formeBouton = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(rayonBouton),
  );
  const texteBouton = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  final base = ThemeData(colorScheme: couleurs, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: CouleursCoach.fond,
    textTheme: base.textTheme
        .apply(
          bodyColor: CouleursCoach.texte,
          displayColor: CouleursCoach.texte,
        )
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: CouleursCoach.texte,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: CouleursCoach.texte,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: formeBouton,
        textStyle: texteBouton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: formeBouton,
        textStyle: texteBouton,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        textStyle: texteBouton,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayonCarte),
        side: const BorderSide(color: CouleursCoach.bordure, width: 0.8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rayonBouton),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 52),
        selectedBackgroundColor: CouleursCoach.vertClair,
        selectedForegroundColor: CouleursCoach.vertFonce,
        textStyle: texteBouton,
      ),
    ),
  );
}
