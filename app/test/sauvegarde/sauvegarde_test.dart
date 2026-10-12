import 'dart:typed_data';

import 'package:coach/sauvegarde/sauvegarde.dart';
import 'package:excel/excel.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final maintenant = DateTime(2026, 10, 12, 8);
final midi = DateTime(2026, 10, 11, 12, 30);

Future<void> garnir(FakeFirebaseFirestore db) async {
  final u = db.collection('users').doc('u1');
  await u.collection('repas').doc('r1').set({
    'date': midi.millisecondsSinceEpoch,
    'moment': 'dejeuner',
    'nom': 'Riz, Poulet',
    'macros': {
      'kcal': 295.0,
      'proteines': 34.0,
      'glucides': 28.0,
      'lipides': 4.0,
    },
    'source': 'photo',
    'description': 'Poulet au riz',
    'photoId': '123',
    'aliments': [
      {
        'nom': 'Riz',
        'grammes': 100.0,
        'macros': {'kcal': 130.0},
      },
    ],
    'verdict': {
      'feu': 'vert',
      'points': ['ok'],
      'conclusion': 'bien',
    },
  });
  await u.collection('activites').doc('a1').set({
    'date': midi.millisecondsSinceEpoch,
    'type': 'course',
    'minutes': 30,
    'intensite': 'moderee',
    'kcal': 300.0,
  });
  await u.collection('pesees').doc('p1').set({
    'kg': 79.5,
    'date': midi.millisecondsSinceEpoch,
    'source': 'manuel',
  });
  await u.collection('eau').doc('e1').set({
    'date': midi.millisecondsSinceEpoch,
    'ml': 250,
  });
  await u.collection('complements').doc('c1').set({
    'nom': 'Créatine',
    'minutes': 480,
    'actif': true,
  });
  await u.collection('prises').doc('2026-10-11').set({
    'ids': ['c1'],
  });
  await u.collection('seances').doc('s1').set({
    'date': midi.millisecondsSinceEpoch,
    'lieu': 'maison',
    'minutes': 40,
  });
  // Hors de la sauvegarde : ne doit pas sortir.
  await u.collection('reglages').doc('consentements').set({'photo': 1});
}

/// Un classeur écrit à la main, comme le ferait quelqu'un dans Excel.
Uint8List classeur(Map<String, List<List<CellValue?>>> feuilles) {
  final x = Excel.createExcel();
  final defaut = x.getDefaultSheet();
  for (final e in feuilles.entries) {
    final f = x[e.key];
    for (final l in e.value) {
      f.appendRow(l);
    }
  }
  if (defaut != null && !feuilles.containsKey(defaut)) x.delete(defaut);
  return Uint8List.fromList(x.encode()!);
}

TextCellValue t(String s) => TextCellValue(s);

void main() {
  test(
    'exporter puis importer : l\'historique revient à l\'identique',
    () async {
      final source = FakeFirebaseFirestore();
      await garnir(source);
      final octets = await SauvegardeFirestore(source)
          .exporter('u1', maintenant: maintenant);

      final cible = FakeFirebaseFirestore();
      final r = await SauvegardeFirestore(cible).importer('u1', octets);

      expect(r.importes, 7);
      expect(r.ignores, 0);
      final repas = (await cible.collection('users/u1/repas').doc('r1').get())
          .data()!;
      expect(repas['nom'], 'Riz, Poulet');
      expect(repas['date'], midi.millisecondsSinceEpoch);
      expect((repas['macros'] as Map)['kcal'], 295);
      expect(repas['photoId'], '123');
      expect((repas['aliments'] as List).single['nom'], 'Riz');
      expect((repas['verdict'] as Map)['feu'], 'vert');
      expect(
        (await cible.collection('users/u1/prises').doc('2026-10-11').get())
            .data()!['ids'],
        ['c1'],
      );
      expect(
        (await cible.collection('users/u1/pesees').doc('p1').get())
            .data()!['kg'],
        79.5,
      );
      // Les réglages ne font pas partie de la sauvegarde.
      expect((await cible.collection('users/u1/reglages').get()).docs, isEmpty);
    },
  );

  test('importer deux fois ne crée pas de doublons', () async {
    final source = FakeFirebaseFirestore();
    await garnir(source);
    final octets = await SauvegardeFirestore(source)
        .exporter('u1', maintenant: maintenant);

    final cible = FakeFirebaseFirestore();
    final service = SauvegardeFirestore(cible);
    await service.importer('u1', octets);
    await service.importer('u1', octets);

    expect((await cible.collection('users/u1/repas').get()).docs, hasLength(1));
    expect((await cible.collection('users/u1/eau').get()).docs, hasLength(1));
  });

  test('l\'export est lisible : feuilles, colonnes et date', () async {
    final source = FakeFirebaseFirestore();
    await garnir(source);
    final octets = await SauvegardeFirestore(source)
        .exporter('u1', maintenant: maintenant);

    final x = Excel.decodeBytes(octets);
    expect(x.tables.keys, containsAll(['Lisez-moi', 'Repas', 'Pesées', 'Eau']));
    final ligne = x.tables['Repas']!.rows;
    final entete = [for (final c in ligne.first) c?.value.toString()];
    expect(
      entete,
      containsAll(['Identifiant', 'Date', 'Moment', 'Nom', 'Calories']),
    );
    expect(ligne[1][0]?.value.toString(), 'r1');
    expect(ligne[1][1]?.value.toString(), '2026-10-11 12:30');
    expect(x.tables['Pesées']!.rows[1][2]?.value.toString(), '79.5');
  });

  test(
    'lignes ajoutées à la main dans Excel : repas, activité, pesée, eau',
    () async {
      final octets = classeur({
        'Repas': [
          [
            t('Identifiant'),
            t('Date'),
            t('Moment'),
            t('Nom'),
            t('Calories'),
            t('Protéines (g)'),
          ],
          [
            null,
            t('2026-10-10 19:30'),
            t('diner'),
            t('Pâtes'),
            t('650'),
            t('22,5'),
          ],
          [null, t('10/10/2026 08:00'), t('inconnu'), t('Café'), t('5'), null],
          [null, t('pas une date'), t('diner'), t('Raté'), t('100'), null],
        ],
        'Activités': [
          [
            t('Identifiant'),
            t('Date'),
            t('Type'),
            t('Minutes'),
            t('Intensité'),
            t('Calories'),
          ],
          [
            null,
            t('2026-10-10 18:00'),
            t('velo'),
            IntCellValue(45),
            t('intense'),
            IntCellValue(420),
          ],
        ],
        'Pesées': [
          [t('Identifiant'), t('Date'), t('Poids (kg)')],
          [null, t('2026-10-10'), DoubleCellValue(80.4)],
          [null, t('2026-10-11'), DoubleCellValue(5000)],
        ],
        'Eau': [
          [t('Identifiant'), t('Date'), t('Quantité (ml)')],
          [null, t('2026-10-10 10:00'), IntCellValue(500)],
        ],
      });
      final cible = FakeFirebaseFirestore();
      final r = await SauvegardeFirestore(cible).importer('u1', octets);

      expect(r.importes, 5);
      expect(r.ignores, 2); // une date illisible, un poids absurde

      final repas = (await cible.collection('users/u1/repas').get()).docs;
      expect(repas, hasLength(2));
      final pates = repas.firstWhere((d) => d['nom'] == 'Pâtes').data();
      expect(pates['moment'], 'diner');
      expect(pates['source'], 'manuel');
      expect((pates['macros'] as Map)['kcal'], 650);
      expect((pates['macros'] as Map)['proteines'], 22.5);
      expect(
        pates['date'],
        DateTime(2026, 10, 10, 19, 30).millisecondsSinceEpoch,
      );
      final cafe = repas.firstWhere((d) => d['nom'] == 'Café').data();
      expect(cafe['moment'], 'collation'); // moment inconnu : repli
      expect(cafe['date'], DateTime(2026, 10, 10, 8).millisecondsSinceEpoch);

      final velo = (await cible.collection('users/u1/activites').get())
          .docs
          .single
          .data();
      expect(velo['type'], 'velo');
      expect(velo['minutes'], 45);
      expect(velo['kcal'], 420);
      expect(
        (await cible.collection('users/u1/pesees').get()).docs,
        hasLength(1),
      );
      expect(
        (await cible.collection('users/u1/eau').get()).docs.single['ml'],
        500,
      );
    },
  );

  test(
    'un repas avec des champs inconnus est nettoyé avant l\'écriture',
    () async {
      final octets = classeur({
        'Repas': [
          [t('Identifiant'), t('Date'), t('Données (JSON, ne pas modifier)')],
          [
            t('r9'),
            null,
            t(
              '{"date":1760000000000,"moment":"diner","nom":"X","macros":{"kcal":100},'
              '"source":"manuel","intrus":"oui","admin":true}',
            ),
          ],
        ],
      });
      final cible = FakeFirebaseFirestore();
      final r = await SauvegardeFirestore(cible).importer('u1', octets);

      expect(r.importes, 1);
      final doc = (await cible.collection('users/u1/repas').doc('r9').get())
          .data()!;
      expect(doc.containsKey('intrus'), isFalse);
      expect(doc.containsKey('admin'), isFalse);
      expect(doc['nom'], 'X');
    },
  );

  test('un fichier qui n\'est pas une sauvegarde est refusé', () async {
    final cible = FakeFirebaseFirestore();
    final service = SauvegardeFirestore(cible);
    await expectLater(
      service.importer('u1', Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<SauvegardeInvalide>()),
    );
    await expectLater(
      service.importer(
        'u1',
        classeur({
          'Autre': [
            [t('a')],
          ],
        }),
      ),
      throwsA(isA<SauvegardeInvalide>()),
    );
  });

  test('un export sans aucune donnée reste un fichier valide', () async {
    final octets = await SauvegardeFirestore(FakeFirebaseFirestore())
        .exporter('u1', maintenant: maintenant);
    final r = await SauvegardeFirestore(FakeFirebaseFirestore())
        .importer('u1', octets);
    expect(r.importes, 0);
    expect(r.ignores, 0);
  });
}
