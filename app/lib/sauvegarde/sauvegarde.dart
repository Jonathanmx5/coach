import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../bienetre/complements.dart';
import '../journal/modele.dart';
import '../poids/mensurations.dart';

/// Ce que contient une sauvegarde importée.
class ResultatImport {
  const ResultatImport({required this.importes, required this.ignores});

  /// Lignes écrites dans les données du compte.
  final int importes;

  /// Lignes qu'on n'a pas pu lire (date manquante, valeur absurde...).
  final int ignores;
}

/// Le fichier n'est pas une sauvegarde Excel lisible.
class SauvegardeInvalide implements Exception {
  const SauvegardeInvalide();

  @override
  String toString() => 'SauvegardeInvalide';
}

/// Sauvegarde de l'historique au format Excel (.xlsx) et restauration.
abstract class Sauvegarde {
  /// Le classeur Excel de tout l'historique de [uid].
  Future<Uint8List> exporter(String uid, {required DateTime maintenant});

  /// Relit un classeur produit par [exporter] (ou complété à la main) et
  /// l'ajoute aux données de [uid] ; les lignes déjà présentes sont remplacées.
  Future<ResultatImport> importer(String uid, Uint8List octets);
}

typedef _Lire = Object? Function(Map<String, Object?> doc);

class _Colonne {
  const _Colonne(this.titre, this.lire);

  final String titre;
  final _Lire lire;
}

class _Feuille {
  const _Feuille(this.titre, this.colonnes);

  final String titre;
  final List<_Colonne> colonnes;
}

Object? _dans(Object? m, String cle) => m is Map ? m[cle] : null;

/// Les collections sauvegardées, dans l'ordre des feuilles du classeur. Les
/// réglages, le planning et le profil n'en font pas partie.
final _feuilles = <String, _Feuille>{
  'repas': _Feuille('Repas', [
    _Colonne('Moment', (d) => d['moment']),
    _Colonne('Nom', (d) => d['nom']),
    _Colonne('Calories', (d) => _dans(d['macros'], 'kcal')),
    _Colonne('Protéines (g)', (d) => _dans(d['macros'], 'proteines')),
    _Colonne('Glucides (g)', (d) => _dans(d['macros'], 'glucides')),
    _Colonne('Lipides (g)', (d) => _dans(d['macros'], 'lipides')),
    _Colonne('Source', (d) => d['source']),
  ]),
  'activites': _Feuille('Activités', [
    _Colonne('Type', (d) => d['type']),
    _Colonne('Minutes', (d) => d['minutes']),
    _Colonne('Intensité', (d) => d['intensite']),
    _Colonne('Calories', (d) => d['kcal']),
  ]),
  'pesees': _Feuille('Pesées', [
    _Colonne('Poids (kg)', (d) => d['kg']),
    _Colonne('Source', (d) => d['source']),
  ]),
  'mensurations': _Feuille('Mensurations', const []),
  'eau': _Feuille('Eau', [_Colonne('Quantité (ml)', (d) => d['ml'])]),
  'complements': _Feuille('Compléments', [
    _Colonne('Nom', (d) => d['nom']),
    _Colonne('Minutes', (d) => d['minutes']),
    _Colonne('Actif', (d) => d['actif']),
  ]),
  'prises': _Feuille('Prises', [
    _Colonne('Compléments pris', (d) {
      final ids = d['ids'];
      return ids is List ? ids.join(', ') : null;
    }),
  ]),
  'seances': _Feuille('Séances', [
    _Colonne('Lieu', (d) => d['lieu']),
    _Colonne('Minutes', (d) => d['minutes']),
  ]),
  'ressentis': _Feuille('Ressentis', const []),
};

const _titreId = 'Identifiant';
const _titreDate = 'Date';
const _titreJson = 'Données (JSON, ne pas modifier)';

/// Champs que chaque collection importée peut porter : les règles de la base
/// (firebase/firestore.rules) refusent les autres, et un seul document refusé
/// ferait échouer tout un lot d'écritures. Un test compare ces listes aux
/// règles.
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

final _formatDate = DateFormat('yyyy-MM-dd HH:mm');

class SauvegardeFirestore implements Sauvegarde {
  SauvegardeFirestore([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid, String nom) =>
      _db.collection('users').doc(uid).collection(nom);

  @override
  Future<Uint8List> exporter(String uid, {required DateTime maintenant}) async {
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
      final docs = (await _col(uid, e.key).get()).docs;
      final tries = [...docs]
        ..sort((a, b) {
          final da = a.data()['date'];
          final db = b.data()['date'];
          if (da is num && db is num) return da.compareTo(db);
          return a.id.compareTo(b.id);
        });
      for (final d in tries) {
        final data = Map<String, Object?>.from(d.data());
        final date = data['date'];
        feuille.appendRow([
          TextCellValue(d.id),
          date is num
              ? TextCellValue(
                  _formatDate.format(
                    DateTime.fromMillisecondsSinceEpoch(date.toInt()),
                  ),
                )
              : null,
          for (final c in e.value.colonnes) _cellule(c.lire(data)),
          TextCellValue(jsonEncode(data, toEncodable: (o) => o.toString())),
        ]);
      }
      comptes[e.value.titre] = tries.length;
    }

    for (final ligne in [
      ['Sauvegarde Crunch & Go'],
      ['Faite le ${_formatDate.format(maintenant)}'],
      [''],
      ['Une feuille par type de donnée : ${comptes.keys.join(', ')}.'],
      [
        'Pour restaurer, importez ce fichier depuis Réglages > Sauvegarde. '
            'Les lignes déjà présentes sont remplacées, rien n\'est supprimé.',
      ],
      [
        'Ne modifiez pas la colonne « Données (JSON) ». Vous pouvez ajouter '
            'des lignes sans elle dans Repas, Activités, Pesées et Eau : '
            'laissez « Identifiant » vide et remplissez la date '
            '(AAAA-MM-JJ HH:mm) et les colonnes.',
      ],
      [''],
      for (final e in comptes.entries) ['${e.key} : ${e.value} ligne(s)'],
    ]) {
      lisezMoi.appendRow([TextCellValue(ligne.first)]);
    }

    // « Lisez-moi » en premier, et la feuille vide créée par défaut en moins.
    if (defaut != null && defaut != 'Lisez-moi') classeur.delete(defaut);
    classeur.setDefaultSheet('Lisez-moi');
    final octets = classeur.encode();
    if (octets == null) throw const SauvegardeInvalide();
    return Uint8List.fromList(octets);
  }

  static CellValue? _cellule(Object? v) => switch (v) {
    null => null,
    int() => IntCellValue(v),
    double() => DoubleCellValue(v),
    bool() => BoolCellValue(v),
    _ => TextCellValue('$v'),
  };

  @override
  Future<ResultatImport> importer(String uid, Uint8List octets) async {
    final Excel classeur;
    try {
      classeur = Excel.decodeBytes(octets);
    } catch (_) {
      throw const SauvegardeInvalide();
    }
    final trouvees = [
      for (final e in _feuilles.entries)
        if (classeur.tables.containsKey(e.value.titre)) e,
    ];
    if (trouvees.isEmpty) throw const SauvegardeInvalide();

    var importes = 0;
    var ignores = 0;
    final ecritures = <(DocumentReference<Map<String, dynamic>>, Map)>[];

    for (final e in trouvees) {
      final lignes = classeur.tables[e.value.titre]!.rows;
      if (lignes.isEmpty) continue;
      final entete = [for (final c in lignes.first) _texte(c?.value) ?? ''];
      final iId = entete.indexOf(_titreId);
      final iDate = entete.indexOf(_titreDate);
      final iJson = entete.indexOf(_titreJson);
      int? col(String t) {
        final i = entete.indexOf(t);
        return i < 0 ? null : i;
      }

      for (final ligne in lignes.skip(1)) {
        String? cellule(int? i) =>
            i == null || i >= ligne.length ? null : _texte(ligne[i]?.value);
        if (ligne.every((c) => (_texte(c?.value) ?? '').trim().isEmpty)) {
          continue;
        }

        Map<String, Object?>? doc;
        final json = cellule(iJson == -1 ? null : iJson);
        if (json != null && json.trim().isNotEmpty) {
          try {
            final lu = jsonDecode(json);
            if (lu is Map) doc = Map<String, Object?>.from(lu);
          } catch (_) {}
        } else {
          doc = _depuisColonnes(
            e.key,
            date: _date(cellule(iDate == -1 ? null : iDate)),
            texte: (t) => cellule(col(t)),
          );
        }
        if (doc == null || !_valide(e.key, doc)) {
          ignores++;
          continue;
        }
        final champs = champsImportables[e.key];
        if (champs != null) doc.removeWhere((k, _) => !champs.contains(k));
        // Repas et activités repassent par leur modèle : textes et listes
        // ramenés dans les bornes des règles, type inconnu remplacé.
        if (e.key == 'repas') doc = Repas.fromMap('x', doc).toMap();
        if (e.key == 'activites') doc = Activite.fromMap('x', doc).toMap();
        final id = (cellule(iId == -1 ? null : iId) ?? '').trim();
        // Un « / » viserait une sous-collection, que les règles refusent.
        if (id.contains('/')) {
          ignores++;
          continue;
        }
        final ref = id.isEmpty
            ? _col(uid, e.key).doc()
            : _col(uid, e.key).doc(id);
        ecritures.add((ref, doc));
      }
    }

    for (var i = 0; i < ecritures.length; i += 400) {
      final lot = _db.batch();
      for (final (ref, doc) in ecritures.skip(i).take(400)) {
        lot.set(ref, Map<String, dynamic>.from(doc));
      }
      await lot.commit();
      importes += ecritures.skip(i).take(400).length;
    }
    return ResultatImport(importes: importes, ignores: ignores);
  }

  /// Une ligne ajoutée à la main : on reconstruit le document depuis les
  /// colonnes lisibles (seulement pour les feuilles simples).
  static Map<String, Object?>? _depuisColonnes(
    String collection, {
    required DateTime? date,
    required String? Function(String titre) texte,
  }) {
    double? nombre(String t) =>
        double.tryParse((texte(t) ?? '').replaceAll(',', '.').trim());
    final ms = date?.millisecondsSinceEpoch;
    switch (collection) {
      case 'repas':
        final kcal = nombre('Calories');
        final moment = (texte('Moment') ?? '').trim();
        if (ms == null || kcal == null) return null;
        return {
          'date': ms,
          'moment': Moment.values.any((m) => m.name == moment)
              ? moment
              : Moment.collation.name,
          'nom': (texte('Nom') ?? '').trim(),
          'macros': {
            'kcal': kcal,
            'proteines': nombre('Protéines (g)') ?? 0,
            'glucides': nombre('Glucides (g)') ?? 0,
            'lipides': nombre('Lipides (g)') ?? 0,
          },
          'source': SourceRepas.manuel.name,
        };
      case 'activites':
        final minutes = nombre('Minutes');
        final kcal = nombre('Calories');
        if (ms == null || minutes == null || kcal == null) return null;
        final type = (texte('Type') ?? '').trim();
        final intensite = (texte('Intensité') ?? '').trim();
        return {
          'date': ms,
          'type': TypeActivite.values.any((t) => t.name == type)
              ? type
              : TypeActivite.autre.name,
          'minutes': minutes.round(),
          'intensite': Intensite.values.any((t) => t.name == intensite)
              ? intensite
              : Intensite.moderee.name,
          'kcal': kcal,
        };
      case 'pesees':
        final kg = nombre('Poids (kg)');
        if (ms == null || kg == null) return null;
        return {'kg': kg, 'date': ms, 'source': 'manuel'};
      case 'eau':
        final ml = nombre('Quantité (ml)');
        if (ms == null || ml == null) return null;
        return {'date': ms, 'ml': ml.round()};
    }
    return null;
  }

  /// Refuse les lignes absurdes avant de les écrire dans la base.
  static bool _valide(String collection, Map<String, Object?> doc) {
    if (doc.isEmpty || doc.length > 60) return false;
    final date = doc['date'];
    if (date != null && date is! num) return false;
    try {
      switch (collection) {
        case 'repas':
          if (date is! num) return false;
          final id = Repas.fromMap('x', doc);
          return id.macros.kcal >= 0 && id.macros.kcal < 20000;
        case 'activites':
          if (date is! num) return false;
          final a = Activite.fromMap('x', doc);
          return a.minutes >= 0 &&
              a.minutes < 1440 &&
              a.kcal >= 0 &&
              a.kcal < 20000;
        case 'pesees':
          final kg = doc['kg'];
          final source = doc['source'];
          return date is num &&
              kg is num &&
              kg > 20 &&
              kg < 400 &&
              (source == null || (source is String && source.length <= 20));
        case 'eau':
          final ml = doc['ml'];
          return date is num && ml is num && ml > 0 && ml <= 5000;
        case 'mensurations':
          return date is num &&
              TypeMensuration.values.every((t) {
                final v = doc[t.name];
                final max = t == TypeMensuration.masseGrasse ? 100 : 300;
                return v == null || (v is num && v >= 0 && v <= max);
              });
        case 'complements':
          final nom = doc['nom'];
          final minutes = doc['minutes'];
          final actif = doc['actif'];
          return nom is String &&
              nom.length <= Complement.nomMax &&
              minutes is num &&
              minutes >= 0 &&
              minutes < 1440 &&
              (actif == null || actif is bool);
        case 'prises':
          final ids = doc['ids'];
          return ids is List && ids.length <= 50;
        case 'seances':
          final minutes = doc['minutes'];
          final lieu = doc['lieu'];
          return date is num &&
              lieu is String &&
              lieu.length <= 20 &&
              minutes is num &&
              minutes >= 1 &&
              minutes <= 600;
        case 'ressentis':
          final valeur = doc['valeur'];
          return valeur is num && valeur >= 1 && valeur <= 3;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  static String? _texte(CellValue? v) => switch (v) {
    null => null,
    TextCellValue() => v.value.text ?? '',
    IntCellValue() => '${v.value}',
    DoubleCellValue() => '${v.value}',
    BoolCellValue() => v.value ? 'true' : 'false',
    DateCellValue() => _formatDate.format(v.asDateTimeLocal()),
    DateTimeCellValue() => _formatDate.format(v.asDateTimeLocal()),
    _ => null,
  };

  /// « 2026-10-12 07:59 », « 2026-10-12 » ou « 12/10/2026 07:59 ».
  static DateTime? _date(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return null;
    final fr = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:[ T](\d{1,2}):(\d{2}))?$',
    ).firstMatch(t);
    if (fr != null) {
      return DateTime(
        int.parse(fr.group(3)!),
        int.parse(fr.group(2)!),
        int.parse(fr.group(1)!),
        int.tryParse(fr.group(4) ?? '') ?? 0,
        int.tryParse(fr.group(5) ?? '') ?? 0,
      );
    }
    return DateTime.tryParse(t.replaceFirst(' ', 'T'));
  }
}
