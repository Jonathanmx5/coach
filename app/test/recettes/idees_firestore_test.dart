import 'package:coach/app.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/recettes/avis.dart';
import 'package:coach/recettes/avis_repository.dart';
import 'package:coach/recettes/idees_page.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'avec le vrai dépôt Firestore (simulé) : une carte est proposée',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final db = FakeFirebaseFirestore();
      await tester.pumpWidget(
        CoachApp(
          accueil: IdeesPage(
            utilisateur: const Utilisateur(uid: 'u1', prenom: 'Léa'),
            objectif: Objectif.muscle,
            kcalCible: 2040,
            avis: FirestoreAvisRepository(db),
            horloge: () => DateTime(2026, 10, 11, 17),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('kcal pour toi'), findsWidgets);
      expect(find.byTooltip('Je n\'aime pas'), findsOneWidget);

      await tester.tap(find.byTooltip("J'aime, pour une prochaine fois"));
      await tester.pumpAndSettle();
      final doc = await db.doc('users/u1/reglages/recettes').get();
      expect((doc.data()!['avis'] as Map).values.single, Avis.aime.name);
    },
  );
}
