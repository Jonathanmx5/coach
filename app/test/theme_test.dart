import 'package:coach/accueil/accueil_page.dart';
import 'package:coach/theme.dart';
import 'package:coach/verre.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Fonds réels des cartes de verre : le dégradé de FondVerre en clair (le
  /// fond de la palette en sombre), sans tache puis sous chaque tache.
  List<(String, Color)> cartesDeVerre(PaletteCoach p, {required bool sombre}) {
    final degrade = sombre
        ? [p.fond]
        : const [Color(0xFFBFDDCF), Color(0xFFCCDDEA), Color(0xFFDDD8CB)];
    return [
      for (final base in degrade) ...[
        ('sans tache', Color.alphaBlend(p.verre, base)),
        for (final tache in [
          CouleursCoach.vertVif,
          CouleursCoach.orange,
          CouleursCoach.bleu,
        ])
          (
            'tache ${tache.toARGB32().toRadixString(16)}',
            Color.alphaBlend(
              p.verre,
              Color.alphaBlend(
                tache.withValues(alpha: alphaTache(tache, sombre: sombre)),
                base,
              ),
            ),
          ),
      ],
    ];
  }

  for (final (nom, p, sombre) in [
    ('clair', PaletteCoach.clair, false),
    ('sombre', PaletteCoach.sombre, true),
  ]) {
    test(
      'thème $nom : les chiffres en couleur restent lisibles sur le verre',
      () {
        for (final (fond, carte) in cartesDeVerre(p, sombre: sombre)) {
          for (final (teinte, couleur) in [
            ('orange', p.texteOrange),
            ('vert', p.texteVert),
            ('bleu', p.texteBleu),
          ]) {
            // Chiffres des anneaux : texte large en gras, 3:1 partout.
            expect(
              contraste(couleur, carte),
              greaterThanOrEqualTo(3),
              reason: '$teinte, $fond',
            );
            // Texte normal : 4,5:1 sur la carte (hors tache en sombre, où les
            // taches sont plus marquées).
            if (!sombre || fond == 'sans tache') {
              expect(
                contraste(couleur, carte),
                greaterThanOrEqualTo(4.5),
                reason: '$teinte, $fond',
              );
            }
          }
          // Icônes et tracés : 3:1 sur la carte sans tache.
          if (fond == 'sans tache') {
            expect(contraste(p.accent, carte), greaterThanOrEqualTo(3));
          }
        }
        // L'icône « Ton programme » sur sa pastille vert clair.
        expect(contraste(p.accent, p.vertClair), greaterThanOrEqualTo(3));
      },
    );
  }

  test('les couleurs vives écrites telles quelles seraient illisibles', () {
    // La raison d'être de texteOrange : l'orange des anneaux sur le verre clair.
    final carte = Color.alphaBlend(
      PaletteCoach.clair.verre,
      const Color(0xFFBFDDCF),
    );
    expect(contraste(CouleursCoach.orange, carte), lessThan(3));
    expect(
      contraste(PaletteCoach.clair.texteOrange, carte),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('texte foncé sur un bandeau orange : lisible', () {
    expect(
      contraste(CouleursCoach.texte, CouleursCoach.orange),
      greaterThanOrEqualTo(4.5),
    );
  });

  test("barre d'état : icônes foncées en clair, claires en sombre", () {
    final clair = themeCoach().appBarTheme.systemOverlayStyle!;
    expect(clair.statusBarIconBrightness, Brightness.dark);
    expect(clair.statusBarColor, Colors.transparent);
    final sombre = themeCoach(luminosite: Brightness.dark)
        .appBarTheme
        .systemOverlayStyle!;
    expect(sombre.statusBarIconBrightness, Brightness.light);
    expect(sombre.statusBarColor, Colors.transparent);
  });

  testWidgets("AppBar en clair : icônes de la barre d'état foncées", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeCoach(),
        home: Scaffold(appBar: AppBar(title: const Text('Poids'))),
      ),
    );
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .descendant(
            of: find.byType(AppBar),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first,
    );
    expect(region.value.statusBarIconBrightness, Brightness.dark);
  });

  test('le thème sombre porte la palette sombre', () {
    final t = themeCoach(luminosite: Brightness.dark);
    expect(t.brightness, Brightness.dark);
    expect(t.extension<PaletteCoach>(), PaletteCoach.sombre);
    expect(t.scaffoldBackgroundColor, PaletteCoach.sombre.fond);
    expect(themeCoach().extension<PaletteCoach>(), PaletteCoach.clair);
  });

  for (final (nom, luminosite, icones) in [
    ('clair', Brightness.light, Brightness.dark),
    ('sombre', Brightness.dark, Brightness.light),
  ]) {
    testWidgets("accueil en $nom : icônes de la barre d'état lisibles", (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = luminosite;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await racine.monter(
        tester,
        FauxAuth(connecte: racine.lea),
        racine.depotAvecProfil(),
      );

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .ancestor(
              of: find.byType(Scaffold),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      expect(region.value.statusBarIconBrightness, icones);
    });
  }

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
