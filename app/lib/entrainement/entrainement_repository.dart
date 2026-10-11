import 'package:cloud_firestore/cloud_firestore.dart';

import 'modele.dart';

/// Réglages (users/{uid}/reglages/entrainement) et séances terminées
/// (users/{uid}/seances).
abstract class EntrainementRepository {
  Stream<Reglages> reglages(String uid);
  Stream<List<SeanceFaite>> seances(String uid);

  /// Hors-ligne, ces Futures ne se terminent qu'à la synchronisation.
  Future<void> enregistrerReglages(String uid, Reglages reglages);
  Future<void> ajouterSeance(String uid, SeanceFaite seance);
}

class FirestoreEntrainementRepository implements EntrainementRepository {
  FirestoreEntrainementRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _reglages(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('reglages')
      .doc('entrainement');

  CollectionReference<Map<String, dynamic>> _seances(String uid) =>
      _db.collection('users').doc(uid).collection('seances');

  @override
  Stream<Reglages> reglages(String uid) => _reglages(uid)
      .snapshots()
      .map((d) => d.exists ? Reglages.fromMap(d.data()!) : const Reglages());

  @override
  Stream<List<SeanceFaite>> seances(String uid) => _seances(uid)
      .orderBy('date')
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) SeanceFaite.fromMap(d.id, d.data())],
      );

  @override
  Future<void> enregistrerReglages(String uid, Reglages reglages) =>
      _reglages(uid).set(reglages.toMap());

  @override
  Future<void> ajouterSeance(String uid, SeanceFaite seance) =>
      _seances(uid).add(seance.toMap());
}
