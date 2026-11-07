import 'package:cloud_firestore/cloud_firestore.dart';

import 'complements.dart';
import 'hydratation.dart';

String cleJour(DateTime j) =>
    '${j.year}-${j.month.toString().padLeft(2, '0')}-'
    '${j.day.toString().padLeft(2, '0')}';

/// Eau bue, compléments et leurs prises (users/{uid}/eau, complements,
/// prises, reglages/bienetre).
abstract class BienEtreRepository {
  Stream<List<EntreeEau>> eau(String uid, DateTime debut, DateTime fin);
  Stream<bool> meteoActive(String uid);
  Stream<List<Complement>> complements(String uid);

  /// Identifiants des compléments pris ce jour-là.
  Stream<Set<String>> prises(String uid, DateTime jour);

  /// Hors-ligne, les Futures ne se terminent qu'à la synchronisation.
  Future<void> ajouterEau(String uid, EntreeEau entree);
  Future<void> supprimerEau(String uid, String id);
  Future<void> activerMeteo(String uid, bool actif);
  Future<void> ajouterComplement(String uid, Complement c);
  Future<void> modifierComplement(String uid, Complement c);
  Future<void> supprimerComplement(String uid, String id);
  Future<void> marquerPris(String uid, DateTime jour, String id, bool pris);
}

class FirestoreBienEtreRepository implements BienEtreRepository {
  FirestoreBienEtreRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> _col(String uid, String nom) =>
      _user(uid).collection(nom);

  @override
  Stream<List<EntreeEau>> eau(String uid, DateTime debut, DateTime fin) =>
      _col(uid, 'eau')
          .where('date', isGreaterThanOrEqualTo: debut.millisecondsSinceEpoch)
          .where('date', isLessThan: fin.millisecondsSinceEpoch)
          .orderBy('date')
          .snapshots()
          .map(
            (s) => [for (final d in s.docs) EntreeEau.fromMap(d.id, d.data())],
          );

  @override
  Stream<bool> meteoActive(String uid) => _col(
    uid,
    'reglages',
  ).doc('bienetre').snapshots().map((d) => d.data()?['meteo'] == true);

  @override
  Stream<List<Complement>> complements(String uid) => _col(uid, 'complements')
      .orderBy('minutes')
      .snapshots()
      .map((s) => [for (final d in s.docs) Complement.fromMap(d.id, d.data())]);

  @override
  Stream<Set<String>> prises(String uid, DateTime jour) => _col(uid, 'prises')
      .doc(cleJour(jour))
      .snapshots()
      .map((d) => {...?(d.data()?['ids'] as List?)?.cast<String>()});

  @override
  Future<void> ajouterEau(String uid, EntreeEau entree) =>
      _col(uid, 'eau').add(entree.toMap());

  @override
  Future<void> supprimerEau(String uid, String id) =>
      _col(uid, 'eau').doc(id).delete();

  @override
  Future<void> activerMeteo(String uid, bool actif) => _col(
    uid,
    'reglages',
  ).doc('bienetre').set({'meteo': actif}, SetOptions(merge: true));

  @override
  Future<void> ajouterComplement(String uid, Complement c) =>
      _col(uid, 'complements').add(c.toMap());

  @override
  Future<void> modifierComplement(String uid, Complement c) =>
      _col(uid, 'complements').doc(c.id).set(c.toMap());

  @override
  Future<void> supprimerComplement(String uid, String id) =>
      _col(uid, 'complements').doc(id).delete();

  @override
  Future<void> marquerPris(String uid, DateTime jour, String id, bool pris) =>
      _col(uid, 'prises').doc(cleJour(jour)).set({
        'ids': pris
            ? FieldValue.arrayUnion([id])
            : FieldValue.arrayRemove([id]),
      }, SetOptions(merge: true));
}
