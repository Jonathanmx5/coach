import 'package:cloud_firestore/cloud_firestore.dart';

import 'modele.dart';

/// Repas et activités saisis (users/{uid}/repas et users/{uid}/activites).
abstract class JournalRepository {
  /// Repas de [debut] (inclus) à [fin] (exclu), triés par date.
  Stream<List<Repas>> repas(String uid, DateTime debut, DateTime fin);
  Stream<List<Activite>> activites(String uid, DateTime debut, DateTime fin);

  /// Hors-ligne, ces Futures ne se terminent qu'à la synchronisation.
  Future<void> ajouterRepas(String uid, Repas repas);
  Future<void> supprimerRepas(String uid, String id);

  /// Remplace le repas portant l'identifiant de [repas].
  Future<void> modifierRepas(String uid, Repas repas);
  Future<void> ajouterActivite(String uid, Activite activite);
  Future<void> supprimerActivite(String uid, String id);
}

class FirestoreJournalRepository implements JournalRepository {
  FirestoreJournalRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid, String nom) =>
      _db.collection('users').doc(uid).collection(nom);

  Stream<QuerySnapshot<Map<String, dynamic>>> _fenetre(
    String uid,
    String nom,
    DateTime debut,
    DateTime fin,
  ) => _col(uid, nom)
      .where('date', isGreaterThanOrEqualTo: debut.millisecondsSinceEpoch)
      .where('date', isLessThan: fin.millisecondsSinceEpoch)
      .orderBy('date')
      .snapshots();

  @override
  Stream<List<Repas>> repas(String uid, DateTime debut, DateTime fin) =>
      _fenetre(
        uid,
        'repas',
        debut,
        fin,
      ).map((s) => [for (final d in s.docs) Repas.fromMap(d.id, d.data())]);

  @override
  Stream<List<Activite>> activites(String uid, DateTime debut, DateTime fin) =>
      _fenetre(
        uid,
        'activites',
        debut,
        fin,
      ).map((s) => [for (final d in s.docs) Activite.fromMap(d.id, d.data())]);

  @override
  Future<void> ajouterRepas(String uid, Repas repas) =>
      _col(uid, 'repas').add(repas.toMap());

  @override
  Future<void> modifierRepas(String uid, Repas repas) =>
      _col(uid, 'repas').doc(repas.id).set(repas.toMap());

  @override
  Future<void> supprimerRepas(String uid, String id) =>
      _col(uid, 'repas').doc(id).delete();

  @override
  Future<void> ajouterActivite(String uid, Activite activite) =>
      _col(uid, 'activites').add(activite.toMap());

  @override
  Future<void> supprimerActivite(String uid, String id) =>
      _col(uid, 'activites').doc(id).delete();
}
