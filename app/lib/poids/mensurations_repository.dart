import 'package:cloud_firestore/cloud_firestore.dart';

import 'mensurations.dart';

/// Mensurations saisies (users/{uid}/mensurations).
abstract class MensurationsRepository {
  /// Triées par date croissante.
  Stream<List<Mensuration>> observer(String uid);

  /// Hors-ligne, ces Futures ne se terminent qu'à la synchronisation.
  Future<void> ajouter(String uid, Mensuration mensuration);
  Future<void> supprimer(String uid, String id);
}

class FirestoreMensurationsRepository implements MensurationsRepository {
  FirestoreMensurationsRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('mensurations');

  @override
  Stream<List<Mensuration>> observer(String uid) => _col(uid)
      .orderBy('date')
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) Mensuration.fromMap(d.id, d.data())],
      );

  @override
  Future<void> ajouter(String uid, Mensuration mensuration) =>
      _col(uid).add(mensuration.toMap());

  @override
  Future<void> supprimer(String uid, String id) => _col(uid).doc(id).delete();
}
