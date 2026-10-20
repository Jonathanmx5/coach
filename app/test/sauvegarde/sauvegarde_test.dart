import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coach/sauvegarde/sauvegarde.dart';
import 'package:excel/excel.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

final maintenant = DateTime(2026, 10, 12, 8);
final midi = DateTime(2026, 10, 11, 12, 30);

Map<String, Object?> repasR1() => {
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
};

Future<void> garnir(FakeFirebaseFirestore db) async {
  final u = db.collection('users').doc('u1');
  await u.collection('repas').doc('r1').set(repasR1());
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

const titreJson = 'Données (JSON, ne pas modifier)';

/// Une feuille dont chaque ligne n'a que l'identifiant et le JSON.
List<List<CellValue?>> feuilleJson(Map<String, Map<String, Object?>> lignes) =>
    [
      [t('Identifiant'), t('Date'), t(titreJson)],
      for (final e in lignes.entries) [t(e.key), null, t(jsonEncode(e.value))],
    ];

Future<ResultatImport> importer(
  FakeFirebaseFirestore db,
  Uint8List octets, {
  bool remplacer = false,
}) =>
    SauvegardeFirestore(db)
        .importer('u1', octets, maintenant: maintenant, remplacer: remplacer);

Iterable<String> raisons(ResultatImport r) => r.ignores.map((m) => m.raison);

/// Firestore hors ligne : une lecture forcée sur le serveur échoue, une
/// lecture ordinaire rend le cache (vide ici), comme le vrai SDK.
class FirestoreHorsLigne extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _CollectionHorsLigne(super.collection(path));
}

// Comme les faux de fake_cloud_firestore : seul get() est simulé.
// ignore: subtype_of_sealed_class
class _CollectionHorsLigne extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _CollectionHorsLigne(this._vraie);

  final CollectionReference<Map<String, dynamic>> _vraie;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    if (options?.source == Source.server) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return _vraie.get(options);
  }
}

void main() {
  test(
    'exporter puis importer : l\'historique revient à l\'identique',
    () async {
      final source = FakeFirebaseFirestore();
      await garnir(source);
      final octets = await SauvegardeFirestore(source)
          .exporter('u1', maintenant: maintenant);

      final cible = FakeFirebaseFirestore();
      final r = await importer(cible, octets);

      expect(r.importes, 7);
      expect(r.ignores, isEmpty);
      expect(r.erreur, isNull);
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

  test('importer deux fois ne crée pas de doublons ni ne réécrit', () async {
    final source = FakeFirebaseFirestore();
    await garnir(source);
    final octets = await SauvegardeFirestore(source)
        .exporter('u1', maintenant: maintenant);

    final cible = FakeFirebaseFirestore();
    await importer(cible, octets);
    final r = await importer(cible, octets);

    // Les prises fusionnent ; tout le reste est déjà là.
    expect(r.importes, 1);
    expect(r.dejaPresents, 6);
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
    expect(
      x.tables['Prises']!.rows[1][2]?.value.toString(),
      'c1',
      reason: 'compléments pris lisibles',
    );
    final lisezMoi = [
      for (final l in x.tables['Lisez-moi']!.rows) l.first?.value.toString(),
    ].join('\n');
    expect(lisezMoi, contains('Remplacer les lignes existantes'));
    expect(lisezMoi, contains('elles l\'emportent sur le JSON'));
  });

  test('un export hors ligne échoue au lieu d\'être incomplet', () async {
    final db = FirestoreHorsLigne();
    await expectLater(
      SauvegardeFirestore(db).exporter('u1', maintenant: maintenant),
      throwsA(
        isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
      ),
    );
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
          [null, t('2026-10-10 12:00'), t('diner'), t('x' * 500), t('100')],
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
      final r = await importer(cible, octets);

      expect(r.importes, 6);
      expect(r.ignores.map((m) => '$m'), [
        'Repas, ligne 4 : date invalide',
        'Pesées, ligne 3 : poids hors bornes',
      ]);

      final repas = (await cible.collection('users/u1/repas').get()).docs;
      expect(repas, hasLength(3));
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
      // Ligne manuelle : nom coupé à 400 caractères, comme dans l'appli.
      expect(repas.map((d) => (d['nom'] as String).length), contains(400));

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

  test('une ligne ajoutée à la main n\'est pas dupliquée par un 2e import, '
      'même avec « Remplacer »', () async {
    final octets = classeur({
      'Eau': [
        [t('Identifiant'), t('Date'), t('Quantité (ml)')],
        [null, t('2026-10-10'), IntCellValue(250)],
        // Deux verres identiques le même jour : deux lignes distinctes.
        [null, t('2026-10-10'), IntCellValue(250)],
      ],
    });
    final cible = FakeFirebaseFirestore();
    await importer(cible, octets);
    final r = await importer(cible, octets);
    await importer(cible, octets, remplacer: true);

    expect(r.importes, 0);
    expect(r.dejaPresents, 2);
    expect((await cible.collection('users/u1/eau').get()).docs, hasLength(2));
  });

  test('dates impossibles ou futures : ignorées, pas décalées', () async {
    final octets = classeur({
      'Eau': [
        [t('Identifiant'), t('Date'), t('Quantité (ml)')],
        [null, t('31/09/2026'), IntCellValue(100)],
        [null, t('10/13/2026 19:30'), IntCellValue(100)],
        [null, t('2026-02-31 08:00'), IntCellValue(100)],
        [null, t('2026-10-11 25:00'), IntCellValue(100)],
        [null, t('2026-10-11 12:60'), IntCellValue(100)],
        [null, t('2027-01-01'), IntCellValue(100)],
        [null, t('1999-12-31 23:59'), IntCellValue(100)],
        [null, t('30/09/2026 07:15'), IntCellValue(300)],
        [null, t('2026-10-13 07:00'), IntCellValue(200)], // demain : permis
      ],
    });
    final cible = FakeFirebaseFirestore();
    final r = await importer(cible, octets);

    expect(r.ignores.map((m) => m.ligne), [2, 3, 4, 5, 6, 7, 8]);
    expect(raisons(r).toSet(), {'date invalide'});
    expect(r.importes, 2);
    final eau = (await cible.collection('users/u1/eau').get()).docs;
    expect(
      eau.map((d) => d['date']),
      containsAll([
        DateTime(2026, 9, 30, 7, 15).millisecondsSinceEpoch,
        DateTime(2026, 10, 13, 7).millisecondsSinceEpoch,
      ]),
    );
  });

  test(
    'date absurde dans le JSON : ignorée, l\'export reste possible',
    () async {
      final octets = classeur({
        'Pesées': feuilleJson({
          'p1': {'kg': 80, 'date': 1e17},
          'p2': {'kg': 80, 'date': DateTime(1999).millisecondsSinceEpoch},
          'p3': {'kg': 80, 'date': 'hier'},
          'p4': {'kg': 80, 'date': midi.millisecondsSinceEpoch},
        }),
      });
      final cible = FakeFirebaseFirestore();
      final r = await importer(cible, octets);

      expect(r.importes, 1);
      expect(raisons(r), ['date invalide', 'date invalide', 'date invalide']);
      // Une date hors de portée déjà en base ne casse plus l'export.
      await cible.doc('users/u1/eau/vieux').set({'date': 1e17, 'ml': 250});
      final export = await SauvegardeFirestore(cible)
          .exporter('u1', maintenant: maintenant);
      expect(Excel.decodeBytes(export).tables['Eau']!.rows, hasLength(2));
    },
  );

  test('identifiant avec des « / » : un nouvel identifiant est créé', () async {
    final octets = classeur({
      'Eau': feuilleJson({
        '2026/10/12': {'date': midi.millisecondsSinceEpoch, 'ml': 250},
        '__reserve__': {'date': midi.millisecondsSinceEpoch, 'ml': 300},
      }),
    });
    final cible = FakeFirebaseFirestore();
    final r = await importer(cible, octets);

    expect(r.importes, 2);
    final ids = [
      for (final d in (await cible.collection('users/u1/eau').get()).docs) d.id,
    ];
    expect(ids, hasLength(2));
    for (final id in ids) {
      expect(id, matches(RegExp(r'^excel-[0-9a-f]{16}$')));
    }
  });

  test('import : seuls les champs et les valeurs acceptés par les règles sont '
      'écrits', () async {
    final octets = classeur({
      'Repas': feuilleJson({
        'long': {
          'date': 1760000000000,
          'moment': 'diner',
          'nom': 'x' * 500,
          'macros': {'kcal': 100},
          'source': 'manuel',
        },
        'sansSource': {
          'date': 1760000000000,
          'moment': 'diner',
          'nom': 'Soupe',
          'macros': {'kcal': 100},
        },
        'verdict': {
          'date': 1760000000000,
          'moment': 'diner',
          'nom': 'Soupe',
          'macros': {'kcal': 100},
          'source': 'manuel',
          'verdict': 'ok',
        },
        'bon': {
          'date': 1760000000000,
          'moment': 'diner',
          'nom': 'Soupe',
          'macros': {'kcal': 100},
          'source': 'manuel',
          'description': 'Une soupe',
        },
      }),
      'Activités': feuilleJson({
        'a1': {
          'date': 1760000000000,
          'type': 'z' * 50,
          'minutes': 30,
          'intensite': 'moderee',
          'kcal': 200,
          'ancien': true,
        },
      }),
      'Compléments': feuilleJson({
        'c1': {'nom': 'Zinc', 'minutes': 480, 'ancien': 'x'},
        'c2': {'nom': 'z' * 200, 'minutes': 480},
        'c3': {'nom': 'Fer', 'minutes': 2000},
        'c4': {'nom': '  ', 'minutes': 480},
        'c5': {'nom': 'Fer', 'minutes': 480, 'actif': 'oui'},
        'c6': {'nom': 'Fer', 'minutes': 480.5},
      }),
      'Séances': feuilleJson({
        's1': {'date': 1760000000000, 'lieu': 'salle', 'minutes': 0},
        's2': {'date': 1760000000000, 'lieu': 'salle', 'minutes': '45 min'},
        's3': {'date': 1760000000000, 'lieu': 'piscine', 'minutes': 45},
        's4': {'date': 1760000000000, 'lieu': 'salle', 'minutes': 45},
      }),
      'Ressentis': feuilleJson({
        '2026-10-10': {'valeur': 7},
        '2026-10-11': {'valeur': 2},
        'hier': {'valeur': 2},
        '2026-02-30': {'valeur': 2},
      }),
      'Mensurations': feuilleJson({
        'm1': {'date': 1760000000000, 'taille': 500},
        'm2': {'date': 1760000000000},
        'm3': {'date': 1760000000000, 'taille': 82.5, 'bras': 31},
      }),
      'Prises': feuilleJson({
        '2026-10-10': {
          'ids': [1, 2],
        },
        '2026-10-11': {
          'ids': ['c1'],
        },
      }),
    });
    final cible = FakeFirebaseFirestore();
    final r = await importer(cible, octets);

    expect(r.ignores.map((m) => '$m'), [
      'Repas, ligne 2 : nom trop long (400 caractères au plus)',
      'Repas, ligne 3 : champ « source » manquant',
      'Repas, ligne 4 : verdict invalide',
      'Mensurations, ligne 2 : mesure hors bornes : taille',
      'Mensurations, ligne 3 : aucune mesure',
      'Compléments, ligne 3 : nom trop long (80 caractères au plus)',
      'Compléments, ligne 4 : heure invalide',
      'Compléments, ligne 5 : nom manquant',
      'Compléments, ligne 6 : actif doit valoir vrai ou faux',
      'Compléments, ligne 7 : heure invalide',
      'Prises, ligne 2 : liste de compléments invalide',
      'Séances, ligne 2 : minutes hors bornes',
      'Séances, ligne 3 : minutes hors bornes',
      'Séances, ligne 4 : lieu inconnu',
      'Ressentis, ligne 2 : valeur hors de 1 à 3',
      'Ressentis, ligne 4 : identifiant AAAA-MM-JJ attendu',
      'Ressentis, ligne 5 : identifiant AAAA-MM-JJ attendu',
    ]);
    expect(r.importes, 7);

    final repas = (await cible.doc('users/u1/repas/bon').get()).data()!;
    expect(repas['description'], 'Une soupe');
    expect((await cible.collection('users/u1/repas').get()).docs, hasLength(1));
    final activite = (await cible.doc('users/u1/activites/a1').get()).data()!;
    expect(activite['type'], 'autre');
    expect(activite.containsKey('ancien'), isFalse);
    final zinc = (await cible.doc('users/u1/complements/c1').get()).data()!;
    expect(zinc, {'nom': 'Zinc', 'minutes': 480});
    expect(
      (await cible.doc('users/u1/mensurations/m3').get()).data()!['bras'],
      31,
    );
  });

  test('les colonnes lisibles modifiées l\'emportent sur le JSON', () async {
    final json = repasR1()
      // Des secondes, que la colonne Date (à la minute) n'affiche pas.
      ..['date'] = midi.millisecondsSinceEpoch + 45000;
    final octets = classeur({
      'Repas': [
        [
          t('Identifiant'),
          t('Date'),
          t('Moment'),
          t('Nom'),
          t('Calories'),
          t('Protéines (g)'),
          t('Glucides (g)'),
          t(titreJson),
        ],
        // Nom et calories corrigés, date inchangée, glucides vidés.
        [
          t('r1'),
          t('2026-10-11 12:30'),
          t('dejeuner'),
          t('Riz au poulet'),
          t('310,5'),
          DoubleCellValue(34.0),
          null,
          t(jsonEncode(json)),
        ],
        // Date et moment corrigés.
        [
          t('r2'),
          t('12/10/2026 07:45'),
          t('petitDejeuner'),
          t('Riz, Poulet'),
          null,
          null,
          null,
          t(jsonEncode(repasR1())),
        ],
        // Moment inconnu : la ligne est signalée, pas devinée.
        [
          t('r3'),
          null,
          t('brunch'),
          null,
          null,
          null,
          null,
          t(jsonEncode(repasR1())),
        ],
        [
          t('r4'),
          null,
          null,
          null,
          t('beaucoup'),
          null,
          null,
          t(jsonEncode(repasR1())),
        ],
      ],
      'Pesées': [
        [t('Identifiant'), t('Date'), t('Poids (kg)'), t(titreJson)],
        [
          t('p1'),
          null,
          t('78,2'),
          t(
            jsonEncode({
              'kg': 79.5,
              'date': midi.millisecondsSinceEpoch,
              'source': 'manuel',
            }),
          ),
        ],
      ],
      'Eau': [
        [t('Identifiant'), t('Date'), t('Quantité (ml)'), t(titreJson)],
        [
          t('e1'),
          null,
          IntCellValue(500),
          t(jsonEncode({'date': midi.millisecondsSinceEpoch, 'ml': 250})),
        ],
      ],
      'Compléments': [
        [t('Identifiant'), t('Date'), t('Nom'), t('Actif'), t(titreJson)],
        [
          t('c1'),
          null,
          t('Créatine'),
          t('faux'),
          t(jsonEncode({'nom': 'Créatine', 'minutes': 480, 'actif': true})),
        ],
      ],
      'Prises': [
        [t('Identifiant'), t('Date'), t('Compléments pris'), t(titreJson)],
        [
          t('2026-10-11'),
          null,
          t('c1, c2'),
          t(
            jsonEncode({
              'ids': ['c1'],
            }),
          ),
        ],
      ],
    });
    final cible = FakeFirebaseFirestore();
    final r = await importer(cible, octets);

    expect(r.ignores.map((m) => '$m'), [
      'Repas, ligne 4 : valeur inconnue : Moment',
      'Repas, ligne 5 : valeur illisible : Calories',
    ]);
    expect(r.importes, 6);

    final r1 = (await cible.doc('users/u1/repas/r1').get()).data()!;
    expect(r1['nom'], 'Riz au poulet');
    expect((r1['macros'] as Map)['kcal'], 310.5);
    expect((r1['macros'] as Map)['glucides'], 28, reason: 'cellule vidée');
    expect(r1['date'], midi.millisecondsSinceEpoch + 45000);
    expect(r1['photoId'], '123', reason: 'champs du JSON gardés');
    expect((r1['aliments'] as List).single['nom'], 'Riz');

    final r2 = (await cible.doc('users/u1/repas/r2').get()).data()!;
    expect(r2['date'], DateTime(2026, 10, 12, 7, 45).millisecondsSinceEpoch);
    expect(r2['moment'], 'petitDejeuner');

    expect((await cible.doc('users/u1/pesees/p1').get()).data()!['kg'], 78.2);
    expect((await cible.doc('users/u1/eau/e1').get()).data()!['ml'], 500);
    expect(
      (await cible.doc('users/u1/complements/c1').get()).data()!['actif'],
      isFalse,
    );
    expect(
      (await cible.doc('users/u1/prises/2026-10-11').get()).data()!['ids'],
      ['c1', 'c2'],
    );
  });

  test('une formule est signalée : coller les valeurs', () async {
    final octets = classeur({
      'Repas': [
        [t('Identifiant'), t('Date'), t('Nom'), t('Calories')],
        [null, t('2026-10-10 12:00'), t('Pâtes'), FormulaCellValue('350+120')],
        [null, t('2026-10-10 19:00'), t('Soupe'), IntCellValue(200)],
      ],
    });
    final cible = FakeFirebaseFirestore();
    final r = await importer(cible, octets);

    expect(r.importes, 1);
    expect(r.ignores.single.ligne, 2);
    expect(r.ignores.single.raison, startsWith('formule'));
  });

  group('lignes déjà présentes', () {
    Future<(FakeFirebaseFirestore, Uint8List)> preparer() async {
      final source = FakeFirebaseFirestore();
      await garnir(source);
      final octets = await SauvegardeFirestore(source)
          .exporter('u1', maintenant: maintenant);
      // Depuis la sauvegarde : un repas corrigé, des prises cochées.
      final cible = FakeFirebaseFirestore();
      await garnir(cible);
      await cible.doc('users/u1/repas/r1').update({'nom': 'Corrigé'});
      await cible.doc('users/u1/prises/2026-10-11').set({
        'ids': ['c2'],
      });
      return (cible, octets);
    }

    test('par défaut : gardées telles quelles, prises fusionnées', () async {
      final (cible, octets) = await preparer();
      final r = await importer(cible, octets);

      expect(r.dejaPresents, 6);
      expect(r.importes, 1);
      expect(
        (await cible.doc('users/u1/repas/r1').get()).data()!['nom'],
        'Corrigé',
      );
      expect(
        (await cible.doc('users/u1/prises/2026-10-11').get()).data()!['ids'],
        ['c2', 'c1'],
      );
    });

    test(
      '« Remplacer » : le fichier l\'emporte, prises toujours fusionnées',
      () async {
        final (cible, octets) = await preparer();
        final r = await importer(cible, octets, remplacer: true);

        expect(r.dejaPresents, 0);
        expect(r.importes, 7);
        expect(
          (await cible.doc('users/u1/repas/r1').get()).data()!['nom'],
          'Riz, Poulet',
        );
        expect(
          (await cible.doc('users/u1/prises/2026-10-11').get()).data()!['ids'],
          ['c2', 'c1'],
        );
      },
    );
  });

  test(
    'un document refusé par le serveur ne fait pas échouer son lot',
    () async {
      final cible = FakeFirebaseFirestore();
      whenCalling(Invocation.method(#set, null))
          .on(cible.doc('users/u1/eau/e2'))
          .thenThrow(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );
      final octets = classeur({
        'Eau': feuilleJson({
          for (final id in ['e1', 'e2', 'e3'])
            id: {'date': midi.millisecondsSinceEpoch, 'ml': 250},
        }),
      });
      final r = await importer(cible, octets);

      expect(r.erreur, isNull);
      expect(r.importes, 2);
      expect(r.ignores.map((m) => '$m'), [
        'Eau, ligne 3 : refusée par le serveur',
      ]);
      expect([
        for (final d in (await cible.collection('users/u1/eau').get()).docs)
          d.id,
      ], unorderedEquals(['e1', 'e3']));
    },
  );

  test('import coupé en route : le résultat partiel est rendu', () async {
    final cible = FakeFirebaseFirestore();
    whenCalling(Invocation.method(#set, null))
        .on(cible.doc('users/u1/eau/e2'))
        .thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );
    final octets = classeur({
      'Eau': feuilleJson({
        for (final id in ['e1', 'e2', 'e3'])
          id: {'date': midi.millisecondsSinceEpoch, 'ml': 250},
      }),
    });
    final r = await importer(cible, octets);

    expect(r.erreur, ErreurImport.interruption);
    expect(r.importes, 1);
  });

  test('un fichier qui n\'est pas une sauvegarde est refusé', () async {
    final cible = FakeFirebaseFirestore();
    await expectLater(
      importer(cible, Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<SauvegardeInvalide>()),
    );
    await expectLater(
      importer(
        cible,
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
    final r = await importer(FakeFirebaseFirestore(), octets);
    expect(r.importes, 0);
    expect(r.ignores, isEmpty);
  });
}
