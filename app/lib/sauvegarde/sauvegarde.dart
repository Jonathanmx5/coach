import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../bienetre/complements.dart';
import '../bienetre/hydratation.dart';
import '../entrainement/modele.dart' show Lieu, SeanceFaite;
import '../format.dart';
import '../journal/modele.dart';
import '../poids/mensurations.dart';

/// Une ligne du classeur laissée de côté, et pourquoi.
@immutable
class Motif {
  const Motif(this.feuille, this.ligne, this.raison);

  /// Titre de la feuille (« Repas », « Eau »...).
  final String feuille;

  /// Numéro de la ligne dans Excel : l'en-tête est la ligne 1.
  final int ligne;

  final String raison;

  @override
  String toString() => '$feuille, ligne $ligne : $raison';
}

/// Pourquoi un import s'est arrêté avant la fin.
enum ErreurImport {
  /// Le serveur a refusé l'accès au compte (déconnexion, droits).
  refus,

  /// Coupure du réseau ou autre panne en cours de route.
  interruption,
}

/// Ce que contient une sauvegarde importée. Même interrompu, l'import rend
/// ce qu'il a déjà écrit.
class ResultatImport {
  const ResultatImport({
    required this.importes,
    this.dejaPresents = 0,
    this.ignores = const [],
    this.erreur,
  });

  /// Lignes écrites dans les données du compte.
  final int importes;

  /// Lignes déjà présentes dans le compte, laissées telles quelles (import
  /// sans « Remplacer les lignes existantes »).
  final int dejaPresents;

  /// Lignes qu'on n'a pas pu lire ou que le serveur a refusées, avec la
  /// raison.
  final List<Motif> ignores;

  /// Null si l'import est allé au bout.
  final ErreurImport? erreur;
}

/// Le fichier n'est pas une sauvegarde Excel lisible.
class SauvegardeInvalide implements Exception {
  const SauvegardeInvalide();

  @override
  String toString() => 'SauvegardeInvalide';
}

/// Sauvegarde de l'historique au format Excel (.xlsx) et restauration.
abstract class Sauvegarde {
  /// Le classeur Excel de tout l'historique de [uid], lu sur le serveur :
  /// hors ligne, l'export échoue au lieu de produire un fichier partiel.
  Future<Uint8List> exporter(String uid, {required DateTime maintenant});

  /// Relit un classeur produit par [exporter] (ou complété à la main) et
  /// l'ajoute aux données de [uid]. Rien n'est supprimé ; une ligne dont
  /// l'identifiant existe déjà est gardée telle quelle, sauf si [remplacer].
  /// Les dates postérieures à [maintenant] + 1 jour sont refusées.
  Future<ResultatImport> importer(
    String uid,
    Uint8List octets, {
    required DateTime maintenant,
    bool remplacer = false,
  });
}

/// Comment lire le texte d'une colonne lisible.
enum _Genre { texte, nombre, entier, booleen, liste }

class _Colonne {
  const _Colonne(this.titre, this.champ, this.genre, {this.valeurs, this.max});

  final String titre;

  /// Chemin du champ dans le document : `['macros', 'kcal']`.
  final List<String> champ;
  final _Genre genre;

  /// Valeurs permises (noms d'une énumération), si la liste est fermée.
  final Set<String>? valeurs;

  /// Longueur maximale d'un texte : au-delà, il est coupé.
  final int? max;

  Object? lire(Map<String, Object?> doc) {
    Object? v = doc;
    for (final cle in champ) {
      v = v is Map ? v[cle] : null;
    }
    return v;
  }

  void ecrire(Map<String, Object?> doc, Object valeur) {
    if (champ.length == 1) {
      doc[champ.first] = valeur;
      return;
    }
    final sous = doc[champ.first];
    doc[champ.first] = {
      if (sous is Map) ...sous.cast<String, Object?>(),
      champ[1]: valeur,
    };
  }

  /// La valeur d'une cellule modifiée à la main, ou null si illisible.
  Object? depuisTexte(String brut) => switch (genre) {
    _Genre.texte => max == null ? brut : tronquer(brut, max!),
    _Genre.nombre => _nombre(brut),
    _Genre.entier => switch (_nombre(brut)) {
      final n? when n == n.truncateToDouble() => n.toInt(),
      _ => null,
    },
    _Genre.booleen => switch (brut.toLowerCase()) {
      'true' || 'vrai' || 'oui' || '1' => true,
      'false' || 'faux' || 'non' || '0' => false,
      _ => null,
    },
    _Genre.liste => [
      for (final s in brut.split(','))
        if (s.trim().isNotEmpty) s.trim(),
    ],
  };

  CellValue? cellule(Map<String, Object?> doc) {
    final v = lire(doc);
    return switch (v) {
      null => null,
      List() => TextCellValue(v.join(', ')),
      int() => IntCellValue(v),
      double() => DoubleCellValue(v),
      bool() => BoolCellValue(v),
      _ => TextCellValue('$v'),
    };
  }
}

/// « 22,5 », « 1 200 » ou « 80.4 » ; null si ce n'est pas un nombre.
double? _nombre(String brut) {
  final n = double.tryParse(
    brut.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.'),
  );
  return n != null && n.isFinite ? n : null;
}

class _Feuille {
  const _Feuille(this.titre, this.colonnes);

  final String titre;
  final List<_Colonne> colonnes;
}

Set<String> _noms(List<Enum> valeurs) => {for (final v in valeurs) v.name};

/// Les collections sauvegardées, dans l'ordre des feuilles du classeur. Les
/// réglages, le planning et le profil n'en font pas partie.
final _feuilles = <String, _Feuille>{
  'repas': _Feuille('Repas', [
    _Colonne('Moment', ['moment'], _Genre.texte, valeurs: _noms(Moment.values)),
    const _Colonne('Nom', ['nom'], _Genre.texte, max: Repas.nomMax),
    const _Colonne('Calories', ['macros', 'kcal'], _Genre.nombre),
    const _Colonne('Protéines (g)', ['macros', 'proteines'], _Genre.nombre),
    const _Colonne('Glucides (g)', ['macros', 'glucides'], _Genre.nombre),
    const _Colonne('Lipides (g)', ['macros', 'lipides'], _Genre.nombre),
    _Colonne(
      'Source',
      ['source'],
      _Genre.texte,
      valeurs: _noms(SourceRepas.values),
    ),
  ]),
  'activites': _Feuille('Activités', [
    _Colonne(
      'Type',
      ['type'],
      _Genre.texte,
      valeurs: _noms(TypeActivite.values),
    ),
    const _Colonne('Minutes', ['minutes'], _Genre.entier),
    _Colonne(
      'Intensité',
      ['intensite'],
      _Genre.texte,
      valeurs: _noms(Intensite.values),
    ),
    const _Colonne('Calories', ['kcal'], _Genre.nombre),
  ]),
  'pesees': const _Feuille('Pesées', [
    _Colonne('Poids (kg)', ['kg'], _Genre.nombre),
    _Colonne('Source', ['source'], _Genre.texte, max: 20),
  ]),
  'mensurations': const _Feuille('Mensurations', [
    _Colonne('Taille (cm)', ['taille'], _Genre.nombre),
    _Colonne('Poitrine (cm)', ['poitrine'], _Genre.nombre),
    _Colonne('Bras (cm)', ['bras'], _Genre.nombre),
    _Colonne('Masse grasse (%)', ['masseGrasse'], _Genre.nombre),
  ]),
  'eau': const _Feuille('Eau', [
    _Colonne('Quantité (ml)', ['ml'], _Genre.entier),
  ]),
  'complements': const _Feuille('Compléments', [
    _Colonne('Nom', ['nom'], _Genre.texte, max: Complement.nomMax),
    _Colonne('Minutes', ['minutes'], _Genre.entier),
    _Colonne('Actif', ['actif'], _Genre.booleen),
  ]),
  'prises': const _Feuille('Prises', [
    _Colonne('Compléments pris', ['ids'], _Genre.liste),
  ]),
  'seances': _Feuille('Séances', [
    _Colonne('Lieu', ['lieu'], _Genre.texte, valeurs: _noms(Lieu.values)),
    const _Colonne('Minutes', ['minutes'], _Genre.entier),
  ]),
  'ressentis': const _Feuille('Ressentis', [
    _Colonne('Valeur (1 à 3)', ['valeur'], _Genre.entier),
  ]),
};

const _titreId = 'Identifiant';
const _titreDate = 'Date';
const _titreJson = 'Données (JSON, ne pas modifier)';

/// Champs que chaque collection importée peut porter : les règles de la base
/// (firebase/firestore.rules) refusent les autres. Un test compare ces listes
/// aux règles.
const champsImportables = <String, Set<String>>{
  'repas': {
    'date',
    'moment',
    'nom',
    'macros',
    'source',
    'description',
    'aliments',
    'photoId',
    'verdict',
  },
  'activites': {'date', 'type', 'minutes', 'intensite', 'kcal'},
  'pesees': {'kg', 'date', 'source'},
  'mensurations': {'date', 'taille', 'poitrine', 'bras', 'masseGrasse'},
  'eau': {'date', 'ml'},
  'complements': {'nom', 'minutes', 'actif'},
  'prises': {'ids'},
  'seances': {'date', 'lieu', 'minutes'},
  'ressentis': {'valeur'},
};

/// Collections dont l'identifiant est le jour (AAAA-MM-JJ).
const _idsJour = {'prises', 'ressentis'};

/// Identifiant de document accepté tel quel ; sinon on en crée un.
final _idValide = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// Taille maximale d'un lot d'écritures Firestore (500), avec de la marge.
const _tailleLot = 400;

final _formatDate = DateFormat('yyyy-MM-dd HH:mm');

/// Date la plus ancienne acceptée à l'import.
final _dateMin = DateTime(2000);

/// Marque une cellule contenant une formule, dont la valeur calculée est
/// perdue à la lecture.
const _formule = '\u0000formule';

/// La date d'un document, à la minute ; null si elle est absurde.
String? _dateLisible(Object? ms) {
  if (ms is! num || !ms.isFinite) return null;
  try {
    return _formatDate.format(DateTime.fromMillisecondsSinceEpoch(ms.toInt()));
  } catch (_) {
    return null;
  }
}

/// Le classeur, construit loin du fil de l'interface. [lignes] : pour chaque
/// collection, l'identifiant et le JSON de chaque document.
Future<Uint8List?> _encoderEnFond(
  Map<String, List<(String, String)>> lignes,
  DateTime maintenant,
) => Isolate.run(() => _construireClasseur(lignes, maintenant));

Uint8List? _construireClasseur(
  Map<String, List<(String, String)>> lignes,
  DateTime maintenant,
) {
  final classeur = Excel.createExcel();
  final defaut = classeur.getDefaultSheet();
  final lisezMoi = classeur['Lisez-moi'];

  final comptes = <String, int>{};
  for (final e in _feuilles.entries) {
    final feuille = classeur[e.value.titre];
    feuille.appendRow([
      TextCellValue(_titreId),
      TextCellValue(_titreDate),
      for (final c in e.value.colonnes) TextCellValue(c.titre),
      TextCellValue(_titreJson),
    ]);
    final docs = [
      for (final (id, json) in lignes[e.key] ?? const <(String, String)>[])
        (id, json, Map<String, Object?>.from(jsonDecode(json) as Map)),
    ];
    docs.sort((a, b) {
      final da = a.$3['date'];
      final db = b.$3['date'];
      if (da is num && db is num) return da.compareTo(db);
      return a.$1.compareTo(b.$1);
    });
    for (final (id, json, data) in docs) {
      final date = _dateLisible(data['date']);
      feuille.appendRow([
        TextCellValue(id),
        date == null ? null : TextCellValue(date),
        for (final c in e.value.colonnes) c.cellule(data),
        TextCellValue(json),
      ]);
    }
    comptes[e.value.titre] = docs.length;
  }

  for (final ligne in [
    'Sauvegarde Crunch & Go',
    'Faite le ${_formatDate.format(maintenant)}',
    '',
    'Une feuille par type de donnée : ${comptes.keys.join(', ')}.',
    'Pour restaurer, importez ce fichier depuis Réglages > Sauvegarde. Rien '
        'n\'est supprimé. Par défaut, seules les lignes absentes du compte '
        'sont ajoutées : une ligne déjà présente (même identifiant) est gardée '
        'telle quelle. Cochez « Remplacer les lignes existantes » pour que le '
        'fichier l\'emporte. Les compléments pris s\'ajoutent toujours à ceux '
        'déjà cochés.',
    'Ne modifiez pas la colonne « Données (JSON) ». Pour corriger une ligne, '
        'changez les colonnes lisibles (date, nom, calories, protéines, '
        'glucides, lipides, poids, ml...) : elles l\'emportent sur le JSON '
        'pour ces champs. Une cellule vidée garde la valeur du JSON.',
    'Vous pouvez ajouter des lignes sans JSON dans Repas, Activités, Pesées '
        'et Eau : laissez « Identifiant » vide et remplissez la date '
        '(AAAA-MM-JJ HH:mm ou JJ/MM/AAAA HH:mm) et les colonnes.',
    'Pas de formules : collez les valeurs (Collage spécial > Valeurs). Les '
        'lignes illisibles sont ignorées et listées à la fin de l\'import.',
    '',
    for (final e in comptes.entries) '${e.key} : ${e.value} ligne(s)',
  ]) {
    lisezMoi.appendRow([TextCellValue(ligne)]);
  }

  // « Lisez-moi » en premier, et la feuille vide créée par défaut en moins.
  if (defaut != null && defaut != 'Lisez-moi') classeur.delete(defaut);
  classeur.setDefaultSheet('Lisez-moi');
  final octets = classeur.encode();
  return octets == null ? null : Uint8List.fromList(octets);
}

/// Les feuilles connues du classeur, réduites à du texte (null pour une
/// cellule vide), décodées loin du fil de l'interface. Null si le fichier
/// n'est pas un classeur lisible.
Future<Map<String, List<List<String?>>>?> _lireEnFond(Uint8List octets) =>
    Isolate.run(() => _lireClasseur(octets));

Map<String, List<List<String?>>>? _lireClasseur(Uint8List octets) {
  final Excel classeur;
  try {
    classeur = Excel.decodeBytes(octets);
  } catch (_) {
    return null;
  }
  return {
    for (final f in _feuilles.values)
      if (classeur.tables[f.titre] case final table?)
        f.titre: [
          for (final l in table.rows) [for (final c in l) _texte(c?.value)],
        ],
  };
}

String? _texte(CellValue? v) => switch (v) {
  null => null,
  TextCellValue() => v.value.text ?? '',
  IntCellValue() => '${v.value}',
  DoubleCellValue() => '${v.value}',
  BoolCellValue() => v.value ? 'true' : 'false',
  DateCellValue() => _formatDate.format(v.asDateTimeLocal()),
  DateTimeCellValue() => _formatDate.format(v.asDateTimeLocal()),
  FormulaCellValue() => _formule,
  TimeCellValue() =>
    '${v.hour.toString().padLeft(2, '0')}:'
        '${v.minute.toString().padLeft(2, '0')}',
};

/// Une ligne prête à écrire, et sa place dans le classeur.
class _Ecriture {
  _Ecriture(this.collection, this.ref, this.doc, this.feuille, this.ligne);

  final String collection;
  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> doc;
  final String feuille;
  final int ligne;

  /// Les prises du jour s'ajoutent à celles déjà cochées, comme dans l'appli.
  bool get fusion => collection == 'prises';

  Map<String, dynamic> get _donnees =>
      fusion ? {'ids': FieldValue.arrayUnion(doc['ids'] as List)} : doc;

  void ajouter(WriteBatch lot) => fusion
      ? lot.set(ref, _donnees, SetOptions(merge: true))
      : lot.set(ref, _donnees);

  Future<void> ecrire() =>
      fusion ? ref.set(_donnees, SetOptions(merge: true)) : ref.set(_donnees);
}

class SauvegardeFirestore implements Sauvegarde {
  SauvegardeFirestore([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid, String nom) =>
      _db.collection('users/$uid/$nom');

  @override
  Future<Uint8List> exporter(String uid, {required DateTime maintenant}) async {
    // Lu sur le serveur : hors ligne, le cache ne contient que les semaines
    // déjà affichées, et la sauvegarde serait incomplète sans le dire.
    final lignes = <String, List<(String, String)>>{};
    for (final nom in _feuilles.keys) {
      final docs = (await _col(
        uid,
        nom,
      ).get(const GetOptions(source: Source.server))).docs;
      lignes[nom] = [
        for (final d in docs)
          (d.id, jsonEncode(d.data(), toEncodable: (o) => o.toString())),
      ];
    }
    final octets = await _encoderEnFond(lignes, maintenant);
    if (octets == null) throw const SauvegardeInvalide();
    return octets;
  }

  @override
  Future<ResultatImport> importer(
    String uid,
    Uint8List octets, {
    required DateTime maintenant,
    bool remplacer = false,
  }) async {
    final tableau = await _lireEnFond(octets);
    if (tableau == null || tableau.isEmpty) throw const SauvegardeInvalide();

    final ignores = <Motif>[];
    final ecritures = <_Ecriture>[];
    final vus = <String>{};
    for (final e in _feuilles.entries) {
      final lignes = tableau[e.value.titre];
      if (lignes == null || lignes.isEmpty) continue;
      final entete = [for (final c in lignes.first) (c ?? '').trim()];

      for (var n = 1; n < lignes.length; n++) {
        final ligne = lignes[n];
        if (ligne.every((c) => (c ?? '').trim().isEmpty)) continue;
        final numero = n + 1;
        String? cellule(String titre) {
          final i = entete.indexOf(titre);
          return i < 0 || i >= ligne.length ? null : ligne[i];
        }

        void ignorer(String raison) =>
            ignores.add(Motif(e.value.titre, numero, raison));

        final lu = _lireLigne(e.key, e.value, cellule, ligne, maintenant);
        final doc = lu.doc;
        if (doc == null) {
          ignorer(lu.motif!);
          continue;
        }
        final id = (cellule(_titreId) ?? '').trim();
        final String cle;
        if (_idsJour.contains(e.key)) {
          // Le document du jour : l'identifiant est la date elle-même.
          if (_jour(id) == null) {
            ignorer('identifiant AAAA-MM-JJ attendu');
            continue;
          }
          cle = id;
        } else {
          // Un « / » viserait une sous-collection ; une ligne ajoutée à la
          // main reçoit un identifiant tiré de son contenu, pour qu'un nouvel
          // import ne la duplique pas.
          cle = _idValide.hasMatch(id) && !id.startsWith('__')
              ? id
              : _idStable(e.key, numero, doc);
        }
        final ref = _col(uid, e.key).doc(cle);
        if (!vus.add(ref.path)) {
          ignorer('identifiant en double dans le fichier');
          continue;
        }
        ecritures.add(_Ecriture(e.key, ref, doc, e.value.titre, numero));
      }
    }

    var importes = 0;
    var dejaPresents = 0;
    try {
      var aEcrire = ecritures;
      if (!remplacer) {
        final existants = await _existants(ecritures);
        aEcrire = [
          for (final w in ecritures)
            if (w.fusion || !existants.contains(w.ref.path)) w,
        ];
        dejaPresents = ecritures.length - aEcrire.length;
      }
      for (var i = 0; i < aEcrire.length; i += _tailleLot) {
        final paquet = aEcrire.skip(i).take(_tailleLot).toList();
        final lot = _db.batch();
        for (final w in paquet) {
          w.ajouter(lot);
        }
        try {
          await lot.commit();
          importes += paquet.length;
        } on FirebaseException {
          // Un seul document refusé fait tomber tout le lot : on réécrit un
          // par un pour isoler les lignes refusées et garder les autres.
          for (final w in paquet) {
            try {
              await w.ecrire();
              importes++;
            } on FirebaseException catch (e) {
              if (e.code != 'permission-denied' &&
                  e.code != 'invalid-argument') {
                rethrow;
              }
              ignores.add(Motif(w.feuille, w.ligne, 'refusée par le serveur'));
            }
          }
        }
      }
    } on FirebaseException catch (e) {
      return ResultatImport(
        importes: importes,
        dejaPresents: dejaPresents,
        ignores: ignores,
        erreur: e.code == 'permission-denied'
            ? ErreurImport.refus
            : ErreurImport.interruption,
      );
    } catch (_) {
      return ResultatImport(
        importes: importes,
        dejaPresents: dejaPresents,
        ignores: ignores,
        erreur: ErreurImport.interruption,
      );
    }
    return ResultatImport(
      importes: importes,
      dejaPresents: dejaPresents,
      ignores: ignores,
    );
  }

  /// Chemins des documents de [ecritures] qui existent déjà sur le serveur.
  Future<Set<String>> _existants(List<_Ecriture> ecritures) async {
    final parCollection = <String, List<_Ecriture>>{};
    for (final w in ecritures) {
      if (!w.fusion) parCollection.putIfAbsent(w.collection, () => []).add(w);
    }
    // Une requête « in » accepte au plus 30 valeurs ; les requêtes partent
    // ensemble pour qu'un gros historique ne se lise pas au compte-gouttes.
    final requetes = [
      for (final paquet in parCollection.values)
        for (var i = 0; i < paquet.length; i += 30)
          paquet.first.ref.parent
              .where(
                FieldPath.documentId,
                whereIn: [
                  for (final w in paquet.sublist(
                    i,
                    math.min(i + 30, paquet.length),
                  ))
                    w.ref.id,
                ],
              )
              .get(const GetOptions(source: Source.server)),
    ];
    final chemins = <String>{
      for (final s in await Future.wait(requetes))
        for (final d in s.docs) d.reference.path,
    };
    return chemins;
  }

  /// Le document d'une ligne, prêt à écrire, ou la raison de l'ignorer.
  static ({Map<String, dynamic>? doc, String? motif}) _lireLigne(
    String collection,
    _Feuille feuille,
    String? Function(String titre) cellule,
    List<String?> ligne,
    DateTime maintenant,
  ) {
    ({Map<String, dynamic>? doc, String? motif}) refus(String motif) =>
        (doc: null, motif: motif);

    if (ligne.contains(_formule)) {
      return refus('formule : collez les valeurs (Collage spécial > Valeurs)');
    }
    final texteDate = (cellule(_titreDate) ?? '').trim();
    final date = _date(texteDate);
    if (texteDate.isNotEmpty && date == null) return refus('date invalide');

    Map<String, Object?> doc;
    final json = (cellule(_titreJson) ?? '').trim();
    if (json.isNotEmpty) {
      Object? lu;
      try {
        lu = jsonDecode(json);
      } catch (_) {}
      if (lu is! Map) return refus('données JSON illisibles');
      doc = Map<String, Object?>.from(lu);
      final motif = _appliquerColonnes(collection, feuille, doc, date, cellule);
      if (motif != null) return refus(motif);
    } else {
      final lu = _depuisColonnes(collection, date: date, texte: cellule);
      if (lu.doc == null) return refus(lu.motif!);
      doc = lu.doc!;
    }

    final champs = champsImportables[collection]!;
    doc.removeWhere((k, _) => !champs.contains(k));
    final motif = _motifInvalide(collection, doc, maintenant);
    if (motif != null) return refus(motif);
    // Repas et activités repassent par leur modèle : type inconnu remplacé,
    // verdict et aliments remis en forme.
    if (collection == 'repas') doc = Repas.fromMap('x', doc).toMap();
    if (collection == 'activites') doc = Activite.fromMap('x', doc).toMap();
    return (doc: Map<String, dynamic>.from(doc), motif: null);
  }

  /// Une ligne qui a un JSON et des colonnes lisibles modifiées : les
  /// colonnes l'emportent pour leurs champs. Une cellule vide garde la valeur
  /// du JSON. Renvoie la raison d'ignorer la ligne, ou null.
  static String? _appliquerColonnes(
    String collection,
    _Feuille feuille,
    Map<String, Object?> doc,
    DateTime? date,
    String? Function(String titre) cellule,
  ) {
    // La date affichée est à la minute : on ne la reprend que si elle a
    // changé, pour garder les secondes du JSON.
    if (date != null &&
        champsImportables[collection]!.contains('date') &&
        _dateLisible(doc['date']) != _formatDate.format(date)) {
      doc['date'] = date.millisecondsSinceEpoch;
    }
    for (final c in feuille.colonnes) {
      final brut = (cellule(c.titre) ?? '').trim();
      if (brut.isEmpty) continue;
      final valeur = c.depuisTexte(brut);
      if (valeur == null) return 'valeur illisible : ${c.titre}';
      if (c.valeurs != null && !c.valeurs!.contains(valeur)) {
        return 'valeur inconnue : ${c.titre}';
      }
      if (!_pareil(c.lire(doc), valeur)) c.ecrire(doc, valeur);
    }
    return null;
  }

  static bool _pareil(Object? a, Object b) => switch ((a, b)) {
    (final num x, final num y) => (x - y).abs() < 1e-9,
    (final List x, final List y) =>
      x.length == y.length && {...x.map((e) => '$e')}.containsAll(y),
    _ => a == b,
  };

  /// Une ligne ajoutée à la main : on reconstruit le document depuis les
  /// colonnes lisibles (seulement pour les feuilles simples).
  static ({Map<String, Object?>? doc, String? motif}) _depuisColonnes(
    String collection, {
    required DateTime? date,
    required String? Function(String titre) texte,
  }) {
    ({Map<String, Object?>? doc, String? motif}) refus(String motif) =>
        (doc: null, motif: motif);
    ({Map<String, Object?>? doc, String? motif}) ok(Map<String, Object?> d) =>
        (doc: d, motif: null);
    double? nombre(String t) => _nombre(texte(t) ?? '');

    if (!const {'repas', 'activites', 'pesees', 'eau'}.contains(collection)) {
      return refus(
        'ligne sans données JSON : seules Repas, Activités, Pesées et Eau '
        'acceptent des lignes ajoutées à la main',
      );
    }
    if (date == null) return refus('date manquante');
    final ms = date.millisecondsSinceEpoch;
    switch (collection) {
      case 'repas':
        final kcal = nombre('Calories');
        if (kcal == null) return refus('calories manquantes ou illisibles');
        final moment = (texte('Moment') ?? '').trim();
        return ok({
          'date': ms,
          'moment': Moment.values.any((m) => m.name == moment)
              ? moment
              : Moment.collation.name,
          'nom': tronquer((texte('Nom') ?? '').trim(), Repas.nomMax),
          'macros': {
            'kcal': kcal,
            'proteines': nombre('Protéines (g)') ?? 0,
            'glucides': nombre('Glucides (g)') ?? 0,
            'lipides': nombre('Lipides (g)') ?? 0,
          },
          'source': SourceRepas.manuel.name,
        });
      case 'activites':
        final minutes = nombre('Minutes');
        final kcal = nombre('Calories');
        if (minutes == null || kcal == null) {
          return refus('minutes ou calories manquantes');
        }
        final type = (texte('Type') ?? '').trim();
        final intensite = (texte('Intensité') ?? '').trim();
        return ok({
          'date': ms,
          'type': TypeActivite.values.any((t) => t.name == type)
              ? type
              : TypeActivite.autre.name,
          'minutes': minutes.round(),
          'intensite': Intensite.values.any((t) => t.name == intensite)
              ? intensite
              : Intensite.moderee.name,
          'kcal': kcal,
        });
      case 'pesees':
        final kg = nombre('Poids (kg)');
        if (kg == null) return refus('poids manquant ou illisible');
        return ok({'kg': kg, 'date': ms, 'source': 'manuel'});
      default: // eau
        final ml = nombre('Quantité (ml)');
        if (ml == null) return refus('quantité manquante ou illisible');
        return ok({'date': ms, 'ml': ml.round()});
    }
  }

  /// Reprend les règles Firestore (firebase/firestore.rules) et ce que les
  /// écrans savent lire : un document qui passe ici est accepté par le
  /// serveur et ne casse aucune liste. Renvoie la raison du refus, ou null.
  static String? _motifInvalide(
    String collection,
    Map<String, Object?> d,
    DateTime maintenant,
  ) {
    bool texte(Object? v, int max) => v is String && v.length <= max;
    bool entre(Object? v, num min, num max) =>
        v is num && v.isFinite && v >= min && v <= max;
    bool entier(Object? v, int min, int max) =>
        entre(v, min, max) && v == (v! as num).truncate();
    String? manque(List<String> cles) {
      for (final c in cles) {
        if (!d.containsKey(c)) return 'champ « $c » manquant';
      }
      return null;
    }

    if (d.isEmpty || d.length > 60) return 'données vides ou trop nombreuses';
    if (champsImportables[collection]!.contains('date')) {
      final date = d['date'];
      if (date == null) return 'date manquante';
      final max = maintenant.add(const Duration(days: 1));
      if (!entre(
        date,
        _dateMin.millisecondsSinceEpoch,
        max.millisecondsSinceEpoch,
      )) {
        return 'date invalide';
      }
    }
    try {
      switch (collection) {
        case 'repas':
          final m = manque(['moment', 'nom', 'macros', 'source']);
          if (m != null) return m;
          if (!texte(d['moment'], Repas.texteCourtMax)) {
            return 'moment invalide';
          }
          if (!texte(d['nom'], Repas.nomMax)) {
            return 'nom trop long (${Repas.nomMax} caractères au plus)';
          }
          if (!texte(d['source'], Repas.texteCourtMax)) {
            return 'source invalide';
          }
          final macros = d['macros'];
          if (macros is! Map || macros.length > 10) return 'macros invalides';
          if (d.containsKey('description') &&
              !texte(d['description'], Repas.descriptionMax)) {
            return 'description trop longue';
          }
          final aliments = d['aliments'];
          if (d.containsKey('aliments') &&
              (aliments is! List || aliments.length > Repas.alimentsMax)) {
            return 'aliments invalides';
          }
          if (d.containsKey('photoId') &&
              !texte(d['photoId'], Repas.photoIdMax)) {
            return 'photo invalide';
          }
          final verdict = d['verdict'];
          if (d.containsKey('verdict') &&
              (verdict is! Map || verdict.length > 10)) {
            return 'verdict invalide';
          }
          final kcal = Repas.fromMap('x', d).macros.kcal;
          if (kcal < 0 || kcal >= 20000) return 'calories hors bornes';
        case 'activites':
          final m = manque(['type', 'minutes', 'intensite', 'kcal']);
          if (m != null) return m;
          if (d['type'] is! String || d['intensite'] is! String) {
            return 'type ou intensité invalide';
          }
          if (!entre(d['minutes'], 0, 1440)) return 'minutes hors bornes';
          if (!entre(d['kcal'], 0, 20000)) return 'calories hors bornes';
          Activite.fromMap('x', d);
        case 'pesees':
          if (!entre(d['kg'], 20, 400)) return 'poids hors bornes';
          if (d.containsKey('source') && !texte(d['source'], 20)) {
            return 'source invalide';
          }
        case 'mensurations':
          var mesures = 0;
          for (final e in plagesMensuration.entries) {
            if (!d.containsKey(e.key.name)) continue;
            mesures++;
            if (!entre(d[e.key.name], e.value.min, e.value.max)) {
              return 'mesure hors bornes : ${e.key.name}';
            }
          }
          if (mesures == 0) return 'aucune mesure';
          Mensuration.fromMap('x', d);
        case 'eau':
          final ml = d['ml'];
          if (!entre(ml, 0, 5000) || ml == 0) {
            return 'quantité hors bornes';
          }
          EntreeEau.fromMap('x', d);
        case 'complements':
          final nom = d['nom'];
          if (nom is! String || nom.trim().isEmpty) return 'nom manquant';
          if (!texte(nom, Complement.nomMax)) {
            return 'nom trop long (${Complement.nomMax} caractères au plus)';
          }
          if (!entier(d['minutes'], 0, 1439)) return 'heure invalide';
          if (d.containsKey('actif') && d['actif'] is! bool) {
            return 'actif doit valoir vrai ou faux';
          }
          Complement.fromMap('x', d);
        case 'prises':
          final ids = d['ids'];
          if (ids is! List || ids.length > 50 || ids.any((i) => i is! String)) {
            return 'liste de compléments invalide';
          }
        case 'seances':
          final m = manque(['lieu', 'minutes']);
          if (m != null) return m;
          if (!_noms(Lieu.values).contains(d['lieu'])) return 'lieu inconnu';
          if (!entier(d['minutes'], 1, 600)) return 'minutes hors bornes';
          SeanceFaite.fromMap('x', d);
        case 'ressentis':
          if (!entier(d['valeur'], 1, 3)) return 'valeur hors de 1 à 3';
      }
    } catch (_) {
      return 'données illisibles';
    }
    return null;
  }

  /// Un identifiant stable pour une ligne sans identifiant utilisable :
  /// importer deux fois le même fichier ne la duplique pas.
  static String _idStable(
    String collection,
    int ligne,
    Map<String, Object?> doc,
  ) {
    final octets = utf8.encode('$collection|$ligne|${jsonEncode(doc)}');
    // FNV-1a 32 bits, avec deux graines.
    var a = 0x811c9dc5;
    var b = 0x9747b28c;
    for (final o in octets) {
      a = ((a ^ o) * 0x01000193) & 0xffffffff;
      b = ((b ^ o) * 0x01000193) & 0xffffffff;
    }
    String hex(int h) => h.toRadixString(16).padLeft(8, '0');
    return 'excel-${hex(a)}${hex(b)}';
  }

  /// Le jour d'un identifiant AAAA-MM-JJ, ou null s'il n'existe pas.
  static DateTime? _jour(String id) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(id);
    if (m == null) return null;
    return _construire(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      0,
      0,
      0,
    );
  }

  /// Une date qui existe vraiment : pas de 31 septembre décalé au
  /// 1er octobre, pas de 25 h.
  static DateTime? _construire(int a, int mo, int j, int h, int mi, int s) {
    if (h > 23 || mi > 59 || s > 59) return null;
    final d = DateTime(a, mo, j, h, mi, s);
    return d.year == a && d.month == mo && d.day == j ? d : null;
  }

  /// « 2026-10-12 07:59 », « 2026-10-12 » ou « 12/10/2026 07:59 » ; null
  /// si la date est illisible ou n'existe pas.
  static DateTime? _date(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return null;
    int nb(String? g) => int.tryParse(g ?? '') ?? 0;
    final fr = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:[ T](\d{1,2})[:h](\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(t);
    if (fr != null) {
      return _construire(
        nb(fr.group(3)),
        nb(fr.group(2)),
        nb(fr.group(1)),
        nb(fr.group(4)),
        nb(fr.group(5)),
        nb(fr.group(6)),
      );
    }
    final iso = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})'
      r'(?:[ T](\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?)?$',
    ).firstMatch(t);
    if (iso != null) {
      return _construire(
        nb(iso.group(1)),
        nb(iso.group(2)),
        nb(iso.group(3)),
        nb(iso.group(4)),
        nb(iso.group(5)),
        nb(iso.group(6)),
      );
    }
    return null;
  }
}
