import 'package:coach/accueil/accueil_page.dart';
import 'package:coach/theme.dart';
import 'package:coach/verre.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'racine_test.dart' as racine;

/// Rapport de contraste WCAG entre deux couleurs.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final haut = la > lb ? la : lb;
  final bas = la > lb ? lb : la;
  return (haut + 0.05) / (bas + 0.05);
}

void main() {
  for (final (nom, p) in [
    ('clair', PaletteCoach.clair),
    ('sombre', PaletteCoach.sombre),
  ]) {
    test('thème $nom : les textes restent lisibles (contraste ≥ 4,5)', () {
      expect(contraste(p.texte, p.fond), greaterThanOrEqualTo(4.5));
      expect(contraste(p.texte, p.carte), greaterThanOrEqualTo(4.5));
      expect(contraste(p.texteDoux, p.fond), greaterThanOrEqualTo(4.5));
      expect(contraste(p.texteDoux, p.carte), greaterThanOrEqualTo(4.5));
      expect(contraste(p.vertFonce, p.vertClair), greaterThanOrEqualTo(4.5));
      expect(
        contraste(p.orangeFonce, p.orangeClair),
        greaterThanOrEqualTo(4.5),
      );
      expect(contraste(p.texte, p.vertClair), greaterThanOrEqualTo(4.5));
      expect(contraste(p.texte, p.orangeClair), greaterThanOrEqualTo(4.5));
      expect(contraste(p.texte, p.rougeClair), greaterThanOrEqualTo(4.5));
    });
  }

  for (final (nom, p, sombre) in [
    ('clair', PaletteCoach.clair, false),
    ('sombre', PaletteCoach.sombre, true),
  ]) {
    test('verre givré $nom : texte lisible sur chaque tache de couleur', () {
      for (final tache in [
        CouleursCoach.vertVif,
        CouleursCoach.orange,
        CouleursCoach.bleu,
      ]) {
        final fond = Color.alphaBlend(
          tache.withValues(alpha: alphaTache(tache, sombre: sombre)),
          p.fond,
        );
        final carte = Color.alphaBlend(p.verre, fond);
        final tuile = Color.alphaBlend(p.verreDense, carte);
        expect(contraste(p.texte, carte), greaterThanOrEqualTo(4.5));
        expect(contraste(p.texteDoux, carte), greaterThanOrEqualTo(4.5));
        expect(contraste(p.texte, tuile), greaterThanOrEqualTo(4.5));
        expect(contraste(p.texte, fond), greaterThanOrEqualTo(4.5));
      }
    });
  }

  test('le thème sombre porte la palette sombre', () {
    final t = themeCoach(luminosite: Brightness.dark);
    expect(t.brightness, Brightness.dark);
    expect(t.extension<PaletteCoach>(), PaletteCoach.sombre);
    expect(t.scaffoldBackgroundColor, PaletteCoach.sombre.fond);
    expect(themeCoach().extension<PaletteCoach>(), PaletteCoach.clair);
  });

  testWidgets('téléphone en mode sombre : l\'accueil s\'affiche en sombre', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await racine.monter(
      tester,
      FauxAuth(connecte: racine.lea),
      racine.depotAvecProfil(),
    );

    expect(find.byType(AccueilPage), findsOneWidget);
    final contexte = tester.element(find.byType(AccueilPage));
    expect(Theme.of(contexte).brightness, Brightness.dark);
    expect(contexte.palette, PaletteCoach.sombre);
    expect(tester.takeException(), isNull);
  });
}
