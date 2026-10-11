import 'dart:io';

import 'package:coach/compte/auth_service.dart';
import 'package:coach/compte/donnees_compte.dart';
import 'package:coach/journal/calculs.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/sante/modele.dart' as sante;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import '../parcours.dart';
import '../racine_test.dart' as racine;

Activite activite(DateTime date, int minutes, double kcal) => Activite(
  date: date,
  type: TypeActivite.course,
  minutes: minutes,
  intensite: Intensite.moderee,
  kcal: kcal,
);

sante.Seance montre(DateTime debut, int minutes) => sante.Seance(
  type: 'course',
  debut: debut,
  duree: Duration(minutes: minutes),
);

void main() {
  group('calories des activités déjà comptées par la montre', () {
    final midi = DateTime(2026, 10, 9, 12);

    test('sans séance de la montre : tout compte', () {
      expect(
        kcalActivitesNonComptees([
          activite(midi, 30, 300),
          activite(midi, 20, 100),
        ], const []),
        400,
      );
    });

    test('séance de la montre au même moment : pas comptée deux fois', () {
      // La séance Coach finit à 12 h 00 après 30 min ; la montre a mesuré
      // 11 h 30 – 12 h 00.
      expect(
        kcalActivitesNonComptees(
          [activite(midi, 30, 300)],
          [montre(DateTime(2026, 10, 9, 11, 30), 30)],
        ),
        0,
      );
    });

    test('séance de la montre à un autre moment : l\'activité compte', () {
      expect(
        kcalActivitesNonComptees(
          [activite(midi, 30, 300)],
          [montre(DateTime(2026, 10, 9, 18), 45)],
        ),
        300,
      );
    });

    test('on ne retire que ce qui chevauche', () {
      expect(
        kcalActivitesNonComptees(
          [
            activite(midi, 30, 300),
            activite(DateTime(2026, 10, 9, 20), 30, 200),
          ],
          [montre(DateTime(2026, 10, 9, 11, 40), 20)],
        ),
        200,
      );
    });
  });

  test('l\'effacement vide toutes les collections, puis le profil', () async {
    final db = FakeFirebaseFirestore();
    for (final nom in FirestoreDonneesCompte.collections) {
      for (var i = 0; i < 3; i++) {
        await db.collection('users/u1/$nom').add({'x': i});
      }
    }
    await db.doc('users/u1').set({'profil': 1});
    await db.collection('users/u2/repas').add({'x': 1});

    await FirestoreDonneesCompte(db).supprimerTout('u1');

    for (final nom in FirestoreDonneesCompte.collections) {
      expect((await db.collection('users/u1/$nom').get()).docs, isEmpty);
    }
    expect((await db.doc('users/u1').get()).exists, isFalse);
    expect((await db.collection('users/u2/repas').get()).docs, hasLength(1));
  });

  test('l\'effacement gère plus de 400 documents', () async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 950; i++) {
      await db.collection('users/u1/eau').add({'ml': i});
    }
    await FirestoreDonneesCompte(db).supprimerTout('u1');
    expect((await db.collection('users/u1/eau').get()).docs, isEmpty);
  });

  test('toute collection utilisée par l\'appli est effacée avec le compte', () {
    final trouvees = <String>{};
    final motif = RegExp(r"(?:_col\(uid, |\.collection\()'(\w+)'");
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in motif.allMatches(f.readAsStringSync())) {
        trouvees.add(m.group(1)!);
      }
    }
    trouvees.remove('users');
    expect(trouvees, isNotEmpty);
    expect(
      FirestoreDonneesCompte.collections.toSet(),
      containsAll(trouvees),
      reason: 'collection oubliée dans FirestoreDonneesCompte.collections',
    );
  });

  test('consentements : enregistrés avec la date, retirables', () async {
    final db = FakeFirebaseFirestore();
    final depot = FirestoreConsentementsRepository(db);
    expect(await depot.accordes('u1').first, isEmpty);

    await depot.definir('u1', Consentement.photo, true);
    expect(await depot.accordes('u1').first, {Consentement.photo});
    final doc = await db.doc('users/u1/reglages/consentements').get();
    expect(doc.data()!['photo'], isA<num>());

    await depot.definir('u1', Consentement.photo, false);
    expect(await depot.accordes('u1').first, isEmpty);
  });

  group('réglages', () {
    Future<void> ouvrir(
      WidgetTester tester, {
      FauxAuth? auth,
      FauxDonnees? donnees,
      FauxConsentements? consentements,
      FauxReseau? reseau,
    }) async {
      await racine.monter(
        tester,
        auth ?? FauxAuth(connecte: racine.lea),
        racine.depotAvecProfil(),
        donnees: donnees,
        consentements: consentements,
        reseau: reseau,
      );
      await tester.tap(find.byTooltip('Réglages'));
      await tester.pumpAndSettle();
    }

    testWidgets('retirer son accord pour la photo', (tester) async {
      final consentements = FauxConsentements({Consentement.photo});
      await ouvrir(tester, consentements: consentements);

      await defilerJusqua(tester, find.text('Photo de repas analysée par IA'));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(consentements.accordesMaintenant, isEmpty);
    });

    testWidgets('supprimer le compte : données, compte, retour à l\'accueil', (
      tester,
    ) async {
      final auth = FauxAuth(connecte: racine.lea);
      final donnees = FauxDonnees();
      await ouvrir(tester, auth: auth, donnees: donnees);

      await taper(tester, 'Supprimer mon compte et mes données');
      expect(
        find.text('Supprimer définitivement ton compte ?'),
        findsOneWidget,
      );
      await taper(tester, 'Tout supprimer');

      expect(donnees.supprimes, ['u1']);
      expect(auth.compteSupprime, isTrue);
      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('annuler : rien n\'est supprimé', (tester) async {
      final auth = FauxAuth(connecte: racine.lea);
      final donnees = FauxDonnees();
      await ouvrir(tester, auth: auth, donnees: donnees);

      await taper(tester, 'Supprimer mon compte et mes données');
      await taper(tester, 'Annuler');

      expect(donnees.supprimes, isEmpty);
      expect(auth.compteSupprime, isFalse);
    });

    testWidgets('hors-ligne : message, rien n\'est supprimé', (tester) async {
      final auth = FauxAuth(connecte: racine.lea);
      final donnees = FauxDonnees();
      await ouvrir(
        tester,
        auth: auth,
        donnees: donnees,
        reseau: FauxReseau(false),
      );

      await taper(tester, 'Supprimer mon compte et mes données');
      await taper(tester, 'Tout supprimer');

      expect(find.textContaining('Connecte-toi à internet'), findsOneWidget);
      expect(donnees.supprimes, isEmpty);
      expect(auth.compteSupprime, isFalse);
    });

    testWidgets('échec : message, on reste sur les réglages', (tester) async {
      final auth = FauxAuth(connecte: racine.lea)
        ..echecSuppression = const ConnexionEchouee('trop ancienne');
      await ouvrir(tester, auth: auth);

      await taper(tester, 'Supprimer mon compte et mes données');
      await taper(tester, 'Tout supprimer');

      expect(find.textContaining('La suppression a échoué'), findsOneWidget);
      expect(find.text('Réglages'), findsOneWidget);
    });
  });
}
