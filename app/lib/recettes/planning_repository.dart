import 'package:cloud_firestore/cloud_firestore.dart';

import '../bienetre/bienetre_repository.dart' show cleJour;
import 'planning.dart';

/// Planning hebdomadaire (users/{uid}/planning/{lundi}).
abstract class PlanningRepository {
  /// Null tant qu'aucun planning n'existe pour cette semaine.
  Stream<Planning?> planning(String uid, DateTime lundi);

  /// Hors-ligne, ce Future ne se termine qu'à la synchronisation.
  Future<void> enregistrer(String uid, Planning planning);
}

class FirestorePlanningRepository implements PlanningRepository {
  FirestorePlanningRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid, DateTime lundi) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('planning')
          .doc(cleJour(lundi));

  @override
  Stream<Planning?> planning(String uid, DateTime lundi) => _doc(uid, lundi)
      .snapshots()
      .map((d) => d.exists ? Planning.fromMap(lundi, d.data()!) : null);

  @override
  Future<void> enregistrer(String uid, Planning planning) =>
      _doc(uid, planning.lundi).set(planning.toMap());
}
