import 'package:coach/app.dart';
import 'package:coach/sante/mes_donnees_page.dart';
import 'package:coach/sante/modele.dart';
import 'package:coach/sante/suivi.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../donnees_sante.dart';
import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);

Future<Suivi> suiviCharge(List<PointSante> points) async {
  final suivi = Suivi(
    sante: FauxSante(points: points),
    horloge: () => maintenant,
  );
  await suivi.charger(montre: true);
  return suivi;
}

List<PointSante> avecPasChaqueJour() => [
  ...semaineType(),
  for (var i = 1; i <= 30; i++)
    PointSante(
      type: TypeMesure.pas,
      debut: DateTime(2026, 10, 9 - i, 10),
      fin: DateTime(2026, 10, 9 - i, 11),
      valeur: 5000.0 + i,
    ),
];

Future<void> monter(WidgetTester tester, Suivi suivi) async {
  await tester.pumpWidget(CoachApp(accueil: MesDonneesPage(suivi: suivi)));
  await tester.pumpAndSettle();
}

int nombreDeBarres(WidgetTester tester, String cle) =>
    tester.widget<BarChart>(find.byKey(ValueKey(cle))).data.barGroups.length;

void main() {
  testWidgets('sections présentes et 7 jours par défaut', (tester) async {
    final suivi = await tester.runAsync(() => suiviCharge(avecPasChaqueJour()));
    await monter(tester, suivi!);

    expect(find.text('Mes données'), findsOneWidget);
    expect(find.text('Activité'), findsOneWidget);
    expect(nombreDeBarres(tester, 'graphe-pas'), 7);
  });

  testWidgets('bascule sur 30 jours', (tester) async {
    final suivi = await tester.runAsync(() => suiviCharge(avecPasChaqueJour()));
    await monter(tester, suivi!);

    await taper(tester, '30 jours');

    expect(nombreDeBarres(tester, 'graphe-pas'), 30);
  });

  testWidgets('sommeil et poids affichés quand mesurés', (tester) async {
    final suivi = await tester.runAsync(() => suiviCharge(semaineType()));
    await monter(tester, suivi!);

    await defilerJusqua(tester, find.byKey(const ValueKey('graphe-sommeil')));
    expect(find.byKey(const ValueKey('graphe-sommeil')), findsOneWidget);
    await defilerJusqua(tester, find.byKey(const ValueKey('graphe-poids')));
    expect(find.byKey(const ValueKey('graphe-poids')), findsOneWidget);
  });

  testWidgets('mesure absente sur la période : non affichée', (tester) async {
    final suivi = await tester.runAsync(() => suiviCharge(semaineType()));
    await monter(tester, suivi!);

    await tester.scrollUntilVisible(
      find.text('Corps'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('graphe-spo2')), findsNothing);
    expect(find.text('Oxygène sanguin (%)'), findsNothing);
  });
}
