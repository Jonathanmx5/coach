import 'package:coach/app.dart';
import 'package:coach/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CoachApp fournit les textes français', (tester) async {
    await tester.pumpWidget(
      CoachApp(
        accueil: Builder(
          builder: (c) => Text(AppLocalizations.of(c)!.boutonCommencer),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commencer'), findsOneWidget);
  });
}
