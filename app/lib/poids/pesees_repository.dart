import 'package:cloud_firestore/cloud_firestore.dart';

import 'pesees.dart';

/// Pesées saisies dans Coach (spec §2.2 : users/{uid}/pesees).
abstract class PeseesRepository {
  /// Pesées manuelles, triées par date croissante. Avec [depuis], seulement
  /// celles faites à partir de cette date (l'accueil ne lit que les deux
  /// dernières semaines).
  Stream<List<Pesee>> observer(String uid, {DateTime? depuis});

  /// Hors-ligne, ce Future ne se termine qu'à la synchronisation.
  Future<void> ajouter(
    String uid, {
    required double kg,
    required DateTime date,
  });
  Future<void> supprimer(String uid, String id);
}

class FirestorePeseesRepository implements PeseesRepository {
  FirestorePeseesRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _pesees(String uid) =>
      _db.collection('users').doc(uid).collection('pesees');

  @override
  Stream<List<Pesee>> observer(String uid, {DateTime? depuis}) {
    Query<Map<String, dynamic>> requete = _pesees(uid);
    if (depuis != null) {
      requete = requete.where(
        'date',
        isGreaterThanOrEqualTo: depuis.millisecondsSinceEpoch,
      );
    }
    return requete
        .orderBy('date')
        .snapshots()
        .map(
          (snap) => [
            for (final d in snap.docs)
              Pesee(
                id: d.id,
                date: DateTime.fromMillisecondsSinceEpoch(
                  (d.data()['date'] as num).toInt(),
                ),
                kg: (d.data()['kg'] as num).toDouble(),
                source: SourcePesee.manuel,
              ),
          ],
        );
  }

  @override
  Future<void> ajouter(
    String uid, {
    required double kg,
    required DateTime date,
  }) => _pesees(uid).add({
    'kg': kg,
    'date': date.millisecondsSinceEpoch,
    'source': SourcePesee.manuel.name,
  });

  @override
  Future<void> supprimer(String uid, String id) =>
      _pesees(uid).doc(id).delete();
}
