import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coach/bienetre/bienetre_repository.dart';
import 'package:coach/bienetre/complements.dart';
import 'package:coach/bienetre/hydratation.dart';
import 'package:coach/compte/donnees_compte.dart';
import 'package:coach/entrainement/entrainement_repository.dart';
import 'package:coach/entrainement/modele.dart';
import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/journal/journal_repository.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/journal/verdict.dart';
import 'package:coach/poids/mensurations.dart';
import 'package:coach/poids/mensurations_repository.dart';
import 'package:coach/poids/pesees_repository.dart';
import 'package:coach/recettes/avis.dart';
import 'package:coach/recettes/avis_repository.dart';
import 'package:coach/recettes/catalogue.dart';
import 'package:coach/recettes/planning.dart';
import 'package:coach/recettes/planning_repository.dart';
import 'package:coach/sauvegarde/sauvegarde.dart';
import 'package:excel/excel.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Documents réellement écrits par l'application (dépôts Firestore et import
/// d'une sauvegarde Excel), exportés en JSON dans firebase/test/fixtures :
/// les tests des règles (firebase/test/regles.test.js) les rejouent contre
/// l'émulateur. Un champ ajouté au code sans être ajouté aux règles fait
/// ainsi échouer `npm test` au lieu de disparaître en production.
const fichierFixtures = '../firebase/test/fixtures/documents.json';

const uid = 'u';
final midi = DateTime.utc(2026, 10, 12, 12, 30);

/// Un aliment analysé sur une photo, avec tous ses champs facultatifs.
AlimentEstime aliment(String nom, double g) => AlimentEstime(
  nom: nom,
  grammes: g,
  macros: Macros(kcal: g * 1.8, proteines: g * 0.1, glucides: g * 0.2),
  confiance: 0.45,
  sucres: 3.5,
  satures: 1.2,
  grammesMin: g * 0.7,
  grammesMax: g * 1.4,
);

/// Le plus gros repas réaliste : 8 aliments aux noms longs (taille maximale
/// renvoyée par le relais), fourchettes, verdict et longue description.
Repas repasMaximal() {
  final aliments = [
    for (var i = 0; i < 8; i++)
      aliment(
        'Sauce crémeuse aux champignons et échalotes numéro $i'.padRight(
          60,
          '.',
        ),
        150,
      ),
  ];
  return Repas(
    date: midi,
    moment: Moment.petitDejeuner,
    nom: aliments.map((a) => a.nom).join(', '),
    macros: aliments.fold(Macros.zero, (s, a) => s + a.macros),
    source: SourceRepas.photo,
    description: 'Une assiette très garnie. ' * 40,
    aliments: aliments,
    photoId: '1760000000000000',
    verdict: const Verdict(
      feu: Feu.rouge,
      points: [
        '52 g de protéines : un apport correct.',
        'C\'est près de la moitié de ta journée en un seul repas.',
        '40 g de sucres : beaucoup d\'un coup.',
        '18 g de graisses saturées : à limiter.',
      ],
      conclusion: 'À éviter aujourd\'hui.',
    ),
  );
}

/// Le plus petit repas : saisi à la main, sans analyse.
Repas repasMinimal() => Repas(
  date: midi,
  moment: Moment.collation,
  nom: '',
  macros: Macros.zero,
  source: SourceRepas.manuel,
);

/// Un classeur avec des lignes ajoutées à la main et une ligne JSON portant
/// un champ inconnu, comme l'import en reçoit.
Uint8List classeurImport() {
  final x = Excel.createExcel();
  final defaut = x.getDefaultSheet();
  TextCellValue t(String s) => TextCellValue(s);
  void feuille(String nom, List<List<CellValue?>> lignes) {
    for (final l in lignes) {
      x[nom].appendRow(l);
    }
  }

  feuille('Repas', [
    [t('Identifiant'), t('Date'), t('Moment'), t('Nom'), t('Calories')],
    [null, t('2026-10-10 19:30'), t('diner'), t('Pâtes'), t('650')],
  ]);
  feuille('Activités', [
    [
      t('Identifiant'),
      t('Date'),
      t('Type'),
      t('Minutes'),
      t('Intensité'),
      t('Calories'),
    ],
    [null, t('2026-10-10 18:00'), t('???'), t('45'), t('?'), t('420')],
  ]);
  feuille('Pesées', [
    [t('Identifiant'), t('Date'), t('Poids (kg)')],
    [null, t('2026-10-10'), t('80,4')],
  ]);
  feuille('Eau', [
    [t('Identifiant'), t('Date'), t('Quantité (ml)')],
    [null, t('2026-10-10 10:00'), t('5000')],
  ]);
  feuille('Séances', [
    [t('Identifiant'), t('Date'), t('Données (JSON, ne pas modifier)')],
    [
      t('import-seance'),
      null,
      t('{"date":1760000000000,"lieu":"salle","minutes":40,"ancien":1}'),
    ],
  ]);
  feuille('Ressentis', [
    [t('Identifiant'), t('Données (JSON, ne pas modifier)')],
    [t('2026-10-10'), t('{"valeur":2}')],
  ]);
  if (defaut != null) x.delete(defaut);
  return Uint8List.fromList(x.encode()!);
}

/// Écrit dans [db], pour [uid], tout ce que l'application sait écrire.
Future<void> ecrireTout(FakeFirebaseFirestore db) async {
  final journal = FirestoreJournalRepository(db);
  await journal.ajouterRepas(uid, repasMaximal());
  await journal.ajouterRepas(uid, repasMinimal());
  await journal.ajouterActivite(
    uid,
    Activite(
      date: midi,
      type: TypeActivite.natation,
      minutes: 600,
      intensite: Intensite.intense,
      kcal: kcalActiviteMax,
    ),
  );
  await journal.ajouterActivite(
    uid,
    Activite(
      date: midi,
      type: TypeActivite.marche,
      minutes: 1,
      intensite: Intensite.legere,
      kcal: 0,
    ),
  );

  final pesees = FirestorePeseesRepository(db);
  await pesees.ajouter(uid, kg: 30, date: midi);
  await pesees.ajouter(uid, kg: 300, date: midi);

  final mensurations = FirestoreMensurationsRepository(db);
  await mensurations.ajouter(
    uid,
    Mensuration(
      date: midi,
      valeurs: {for (final e in plagesMensuration.entries) e.key: e.value.max},
    ),
  );
  await mensurations.ajouter(
    uid,
    Mensuration(date: midi, valeurs: const {TypeMensuration.taille: 40}),
  );

  final bienetre = FirestoreBienEtreRepository(db);
  await bienetre.ajouterEau(uid, EntreeEau(date: midi, ml: 250));
  // Le plus gros bouton du widget de l'écran d'accueil.
  await bienetre.ajouterEau(uid, EntreeEau(date: midi, ml: 2000));
  await bienetre.activerMeteo(uid, true);
  await bienetre.activerMeteo(uid, false);
  await bienetre.ajouterComplement(
    uid,
    Complement(nom: 'Vitamine D', minutes: 0),
  );
  await bienetre.modifierComplement(
    uid,
    Complement(
      id: 'complement-long',
      nom: 'x' * 120,
      minutes: 1439,
    ).copyWith(actif: false),
  );
  for (var i = 0; i < 50; i++) {
    await bienetre.marquerPris(uid, midi, 'complement-$i', true);
  }
  await bienetre.marquerPris(uid, midi, 'complement-0', false);

  final entrainement = FirestoreEntrainementRepository(db);
  await entrainement.enregistrerReglages(
    uid,
    Reglages(materiel: Materiel.values.toSet()),
  );
  await entrainement.ajouterSeance(
    uid,
    SeanceFaite(date: midi, lieu: Lieu.course, minutes: 600),
  );
  await entrainement.ajouterSeance(
    uid,
    SeanceFaite(date: midi, lieu: Lieu.maison, minutes: 1),
  );
  await entrainement.noterRessenti(uid, midi, 1);
  await entrainement.noterRessenti(uid, midi.add(const Duration(days: 1)), 3);

  final recettes = catalogueRecettes.take(30).toList();
  final lundi = DateTime.utc(2026, 10, 12);
  await FirestorePlanningRepository(db).enregistrer(
    uid,
    Planning(
      lundi: lundi,
      vegetarien: true,
      jours: {
        for (var j = 0; j < 7; j++)
          j: {
            for (final m in Moment.values)
              m: RepasPlanifie(
                recettes[(j * 4 + m.index) % recettes.length].id,
                1.5,
              ),
          },
      },
      coches: {for (var i = 0; i < 80; i++) 'article-$i'},
    ),
  );

  final avis = FirestoreAvisRepository(db);
  for (final r in recettes) {
    await avis.noter(uid, r.id, Avis.aime);
  }
  await avis.noter(uid, recettes.first.id, Avis.refuse);
  await avis.noter(uid, recettes.last.id, null);

  final consentements = FirestoreConsentementsRepository(db);
  await consentements.definir(uid, Consentement.photo, true);
  await consentements.definir(uid, Consentement.meteo, true);
  await consentements.definir(uid, Consentement.meteo, false);

  await SauvegardeFirestore(db).importer(uid, classeurImport());
}

/// Une séance de 600 minutes de natation intense chez une personne lourde.
const kcalActiviteMax = 9000.0;

/// Collections dont l'identifiant des documents a un sens (jour, réglage) :
/// on le garde ; ailleurs, l'identifiant aléatoire est remplacé par un
/// numéro pour que le fichier reste stable d'une exécution à l'autre.
const _idsParlants = {'reglages', 'prises', 'planning', 'ressentis'};

/// La date d'un accord vient de l'horloge du téléphone : elle est fixée pour
/// que le fichier ne change pas à chaque exécution (le type reste le même).
Map<String, Object?> _sansHorloge(String id, Map<String, Object?> data) =>
    id == 'consentements'
    ? data.map((k, v) => MapEntry(k, v is num ? 1760000000000 : v))
    : data;

Future<List<Map<String, Object?>>> documents(FakeFirebaseFirestore db) async {
  final sortie = <Map<String, Object?>>[];
  for (final nom in FirestoreDonneesCompte.collections) {
    final docs = (await db.collection('users/$uid/$nom').get()).docs;
    final lignes = [
      for (final d in docs)
        (id: d.id, json: jsonEncode(_sansHorloge(d.id, d.data()))),
    ]..sort((a, b) => a.json.compareTo(b.json));
    for (final (i, l) in lignes.indexed) {
      final id = _idsParlants.contains(nom) || l.id.startsWith('import-')
          ? l.id
          : '$nom-${i + 1}';
      sortie.add({'chemin': '$nom/$id', 'donnees': jsonDecode(l.json)});
    }
  }
  return sortie;
}

void main() {
  test('les documents écrits par l\'appli sont exportés pour les tests des '
      'règles', () async {
    final db = FakeFirebaseFirestore();
    await ecrireTout(db);
    final docs = await documents(db);

    // Toutes les collections sont représentées.
    expect({
      for (final d in docs) (d['chemin']! as String).split('/').first,
    }, FirestoreDonneesCompte.collections.toSet());
    // Et les quatre documents de réglages.
    expect(
      {
        for (final d in docs)
          if ((d['chemin']! as String).startsWith('reglages/')) d['chemin'],
      },
      {
        'reglages/bienetre',
        'reglages/consentements',
        'reglages/entrainement',
        'reglages/recettes',
      },
    );
    // Le repas maximal a bien été ramené dans les bornes.
    final repas = [
      for (final d in docs)
        if ((d['chemin']! as String).startsWith('repas/')) d['donnees']! as Map,
    ];
    expect(repas.map((r) => (r['nom'] as String).length), contains(400));

    final fichier = File(fichierFixtures);
    fichier.parent.createSync(recursive: true);
    fichier.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(docs)}\n',
    );
  });
}
