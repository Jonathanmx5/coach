import 'package:cloud_firestore/cloud_firestore.dart';

import 'avis.dart';

/// Avis sur les recettes (users/{uid}/reglages/recettes, champ `avis`).
abstract class AvisRepository {
  Stream<Map<String, Avis>> avis(String uid);

  /// [avis] null efface l'avis. Hors-ligne, le Future ne se termine qu'à la
  /// synchronisation.
  Future<void> noter(String uid, String recetteId, Avis? avis);
}

class FirestoreAvisRepository implements AvisRepository {
  FirestoreAvisRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('reglages').doc('recettes');

  @override
  Stream<Map<String, Avis>> avis(String uid) => _doc(uid).snapshots().map((d) {
    final brut = (d.data()?['avis'] as Map?) ?? const {};
    return {
      for (final e in brut.entries)
        if (Avis.values.asNameMap()['${e.value}'] != null)
          '${e.key}': Avis.values.asNameMap()['${e.value}']!,
    };
  });

  @override
  Future<void> noter(String uid, String recetteId, Avis? avis) =>
      _doc(uid).set({
        'avis': {recetteId: avis?.name ?? FieldValue.delete()},
      }, SetOptions(merge: true));
}
