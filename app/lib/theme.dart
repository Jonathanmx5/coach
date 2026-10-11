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

/// Couleurs qui changent entre le thème clair et le thème sombre : textes,
/// fonds teintés, bordures. Les couleurs d'accent de [CouleursCoach] (vert,
/// orange, bleu) restent les mêmes dans les deux thèmes.
@immutable
class PaletteCoach extends ThemeExtension<PaletteCoach> {
  const PaletteCoach({
    required this.fond,
    required this.carte,
    required this.texte,
    required this.texteDoux,
    required this.bordure,
    required this.vertClair,
    required this.vertPale,
    required this.vertFonce,
    required this.orangeClair,
    required this.orangeFonce,
    required this.rougeClair,
    required this.verre,
    required this.verreBord,
    required this.verreDense,
  });

  final Color fond;
  final Color carte;
  final Color texte;
  final Color texteDoux;
  final Color bordure;
  final Color vertClair;
  final Color vertPale;
  final Color vertFonce;
  final Color orangeClair;
  final Color orangeFonce;
  final Color rougeClair;

  /// Verre givré : remplissage des cartes, bord lumineux, tuiles posées dessus.
  final Color verre;
  final Color verreBord;
  final Color verreDense;

  static const clair = PaletteCoach(
    fond: Color(0xFFD3E3DB),
    carte: Colors.white,
    texte: CouleursCoach.texte,
    texteDoux: Color(0xFF45453F),
    bordure: CouleursCoach.bordure,
    vertClair: CouleursCoach.vertClair,
    vertPale: CouleursCoach.vertPale,
    vertFonce: CouleursCoach.vertFonce,
    orangeClair: CouleursCoach.orangeClair,
    orangeFonce: CouleursCoach.orangeFonce,
    rougeClair: Color(0xFFFCE8E8),
    verre: Color(0x70FFFFFF),
    verreBord: Color(0xB3FFFFFF),
    verreDense: Color(0x8CFFFFFF),
  );

  static const sombre = PaletteCoach(
    fond: Color(0xFF111614),
    carte: Color(0xFF1B2220),
    texte: Color(0xFFF0F4F2),
    texteDoux: Color(0xFFD3DBD7),
    bordure: Color(0xFF3A4440),
    vertClair: Color(0xFF173B31),
    vertPale: Color(0xFF2C5E4D),
    vertFonce: Color(0xFF8FE3C6),
    orangeClair: Color(0xFF3A2E18),
    orangeFonce: Color(0xFFF3C983),
    rougeClair: Color(0xFF3D1E1E),
    verre: Color(0x16FFFFFF),
    verreBord: Color(0x47FFFFFF),
    verreDense: Color(0x14FFFFFF),
  );

  @override
  PaletteCoach copyWith({
    Color? fond,
    Color? carte,
    Color? texte,
    Color? texteDoux,
    Color? bordure,
    Color? vertClair,
    Color? vertPale,
    Color? vertFonce,
    Color? orangeClair,
    Color? orangeFonce,
    Color? rougeClair,
    Color? verre,
    Color? verreBord,
    Color? verreDense,
  }) => PaletteCoach(
    fond: fond ?? this.fond,
    carte: carte ?? this.carte,
    texte: texte ?? this.texte,
    texteDoux: texteDoux ?? this.texteDoux,
    bordure: bordure ?? this.bordure,
    vertClair: vertClair ?? this.vertClair,
    vertPale: vertPale ?? this.vertPale,
    vertFonce: vertFonce ?? this.vertFonce,
    orangeClair: orangeClair ?? this.orangeClair,
    orangeFonce: orangeFonce ?? this.orangeFonce,
    rougeClair: rougeClair ?? this.rougeClair,
    verre: verre ?? this.verre,
    verreBord: verreBord ?? this.verreBord,
    verreDense: verreDense ?? this.verreDense,
  );

  @override
  PaletteCoach lerp(ThemeExtension<PaletteCoach>? autre, double t) {
    if (autre is! PaletteCoach) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return PaletteCoach(
      fond: m(fond, autre.fond),
      carte: m(carte, autre.carte),
      texte: m(texte, autre.texte),
      texteDoux: m(texteDoux, autre.texteDoux),
      bordure: m(bordure, autre.bordure),
      vertClair: m(vertClair, autre.vertClair),
      vertPale: m(vertPale, autre.vertPale),
      vertFonce: m(vertFonce, autre.vertFonce),
      orangeClair: m(orangeClair, autre.orangeClair),
      orangeFonce: m(orangeFonce, autre.orangeFonce),
      rougeClair: m(rougeClair, autre.rougeClair),
      verre: m(verre, autre.verre),
      verreBord: m(verreBord, autre.verreBord),
      verreDense: m(verreDense, autre.verreDense),
    );
  }
}

extension PaletteDuContexte on BuildContext {
  /// La palette du thème courant (clair si l'appli n'a pas de thème Coach,
  /// par exemple quand on dessine un widget d'écran d'accueil).
  PaletteCoach get palette =>
      Theme.of(this).extension<PaletteCoach>() ?? PaletteCoach.clair;
}

const rayonCarte = 16.0;
const rayonBouton = 14.0;

ThemeData themeCoach({Brightness luminosite = Brightness.light}) {
  final sombre = luminosite == Brightness.dark;
  final p = sombre ? PaletteCoach.sombre : PaletteCoach.clair;
  final couleurs = ColorScheme.fromSeed(
    seedColor: CouleursCoach.vert,
    brightness: luminosite,
    // En sombre, le vert profond serait illisible : on prend le vert vif.
    primary: sombre ? CouleursCoach.vertVif : CouleursCoach.vert,
    onPrimary: sombre ? const Color(0xFF05241C) : Colors.white,
    tertiary: CouleursCoach.orange,
    surface: p.fond,
    onSurface: p.texte,
  );
  final formeBouton = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(rayonBouton),
  );
  const texteBouton = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  final base = ThemeData(
    colorScheme: couleurs,
    useMaterial3: true,
    brightness: luminosite,
  );
  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.fond,
    textTheme: base.textTheme
        .apply(bodyColor: p.texte, displayColor: p.texte)
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: p.texte,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: p.texte,
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
    // Cartes en verre givré : translucides, avec un bord qui capte la lumière.
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: const Color(0x2B0F2A24),
      margin: EdgeInsets.zero,
      color: p.verre,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayonCarte + 4),
        side: BorderSide(color: p.verreBord, width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: p.texte,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: sombre
          ? Colors.white.withValues(alpha: 0.22)
          : CouleursCoach.vert.withValues(alpha: 0.16),
      indicatorShape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.carte,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rayonBouton),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 52),
        selectedBackgroundColor: p.vertClair,
        selectedForegroundColor: p.vertFonce,
        textStyle: texteBouton,
      ),
    ),
  );
}
