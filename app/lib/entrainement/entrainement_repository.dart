import 'package:cloud_firestore/cloud_firestore.dart';

import 'modele.dart';

/// Réglages (users/{uid}/reglages/entrainement) et séances terminées
/// (users/{uid}/seances).
abstract class EntrainementRepository {
  Stream<Reglages> reglages(String uid);
  Stream<List<SeanceFaite>> seances(String uid);

  /// Ressenti du matin (1 fatigué, 2 moyen, 3 en forme) pour ce jour, ou null.
  Stream<int?> ressenti(String uid, DateTime jour);

  /// Hors-ligne, ces Futures ne se terminent qu'à la synchronisation.
  Future<void> enregistrerReglages(String uid, Reglages reglages);
  Future<void> ajouterSeance(String uid, SeanceFaite seance);
  Future<void> noterRessenti(String uid, DateTime jour, int valeur);
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

  DocumentReference<Map<String, dynamic>> _ressenti(String uid, DateTime j) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('ressentis')
          .doc(
            '${j.year}-${j.month.toString().padLeft(2, '0')}-'
            '${j.day.toString().padLeft(2, '0')}',
          );

  @override
  Stream<int?> ressenti(String uid, DateTime jour) => _ressenti(uid, jour)
      .snapshots()
      .map((d) => d.exists ? (d.data()!['valeur'] as num).toInt() : null);

  @override
  Future<void> noterRessenti(String uid, DateTime jour, int valeur) =>
      _ressenti(uid, jour).set({'valeur': valeur});

  @override
  Future<void> enregistrerReglages(String uid, Reglages reglages) =>
      _reglages(uid).set(reglages.toMap());

  @override
  Future<void> ajouterSeance(String uid, SeanceFaite seance) =>
      _seances(uid).add(seance.toMap());
}
