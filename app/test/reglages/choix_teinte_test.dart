import 'package:coach/app.dart';
import 'package:coach/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => teinteActive = Teinte.foret);

  testWidgets('premier lancement : on choisit sa teinte, puis l\'accueil', (
    tester,
  ) async {
    final teinte = ValueNotifier<Teinte?>(null);
    await tester.pumpWidget(
      CoachApp(
        teinte: teinte,
        choisirTeinte: (t) async => teinte.value = t,
        accueil: const Scaffold(body: Text('Accueil')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choisis tes couleurs'), findsOneWidget);
    expect(find.text('Accueil'), findsNothing);

    // Toucher un aperçu l'essaie aussitôt, sans l'enregistrer.
    await tester.tap(find.text('Aurore'));
    await tester.pumpAndSettle();
    expect(teinteActive, Teinte.aurore);
    expect(teinte.value, isNull);

    await tester.ensureVisible(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(teinte.value, Teinte.aurore);
    expect(find.text('Accueil'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Accueil'))).colorScheme.primary,
      const Color(0xFF6A3FB5),
    );
  });

  testWidgets('teinte déjà choisie : pas d\'écran de choix', (tester) async {
    await tester.pumpWidget(
      CoachApp(
        teinte: ValueNotifier(Teinte.foret),
        choisirTeinte: (_) async {},
        accueil: const Scaffold(body: Text('Accueil')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accueil'), findsOneWidget);
  });
}
