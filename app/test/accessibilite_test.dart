import 'package:coach/accueil/anneaux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'racine_test.dart' as racine;

void main() {
  testWidgets('les anneaux ont une description pour le lecteur d\'écran', (
    tester,
  ) async {
    final poignee = tester.ensureSemantics();
    await racine.monter(
      tester,
      FauxAuth(connecte: racine.lea),
      racine.depotAvecProfil(),
    );

    final etiquette = tester.getSemantics(find.byType(Anneaux)).label;
    expect(etiquette, contains('Anneaux du jour'));
    expect(etiquette, contains('Calories brûlées'));
    expect(etiquette, contains('Eau'));
    expect(etiquette, contains('Bilan'));
    poignee.dispose();
  });

  for (final echelle in [1.3, 2.0]) {
    testWidgets('texte agrandi ×$echelle : aucun onglet ne déborde', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = echelle;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await racine.monter(
        tester,
        FauxAuth(connecte: racine.lea),
        racine.depotAvecProfil(),
      );
      expect(tester.takeException(), isNull, reason: 'accueil');

      for (final onglet in ['Repas', 'Sport', 'Poids', 'Bien-être']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(onglet),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: onglet);
      }
    });
  }
}
