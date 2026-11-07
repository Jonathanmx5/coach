import 'package:cloud_firestore/cloud_firestore.dart';

import 'besoins.dart';
import 'modele.dart';

class ProfilEnregistre {
  const ProfilEnregistre({required this.profil, required this.reperes});

  final Profil profil;
  final Reperes reperes;
}

abstract class ProfilRepository {
  Stream<ProfilEnregistre?> observer(String uid);

  /// Avec Firestore hors-ligne, ce Future ne se termine qu'à la
  /// synchronisation : ne jamais l'attendre pour avancer dans l'interface.
  Future<void> enregistrer(String uid, Profil p, Reperes r);
}

class FirestoreProfilRepository implements ProfilRepository {
  FirestoreProfilRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _schema = 1;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<ProfilEnregistre?> observer(String uid) =>
      _doc(uid).snapshots().map((snap) {
        final data = snap.data();
        final profil = data?['profil'];
        final reperes = data?['reperes'];
        if (profil is! Map || reperes is! Map) return null;
        return ProfilEnregistre(
          profil: Profil.fromMap(profil.cast<String, Object?>()),
          reperes: Reperes.fromMap(reperes.cast<String, Object?>()),
        );
      });

  @override
  Future<void> enregistrer(String uid, Profil p, Reperes r) => _doc(uid).set({
    'profil': p.toMap(),
    'reperes': r.toMap(),
    'schema': _schema,
    'majLe': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
