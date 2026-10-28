import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'preferences_analyse.dart';

/// Où sont gardés, pour un compte, les réglages de l'analyse photo.
abstract class DepotPreferencesAnalyse {
  /// Le document du compte ; null tant qu'il n'existe pas.
  Stream<Map<String, Object?>?> ecouter(String uid);

  Future<void> ecrire(String uid, Map<String, Object?> donnees);
}

/// users/{uid}/reglages/analyse : `assiette` (cm) et `etalonnage`.
class FirestoreDepotPreferencesAnalyse implements DepotPreferencesAnalyse {
  FirestoreDepotPreferencesAnalyse([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('reglages').doc('analyse');

  @override
  Stream<Map<String, Object?>?> ecouter(String uid) => _doc(uid)
      .snapshots(includeMetadataChanges: true)
      // Nos propres écritures, pas encore envoyées, ne sont pas du neuf.
      .where((d) => !d.metadata.hasPendingWrites)
      .map((d) => d.data());

  @override
  Future<void> ecrire(String uid, Map<String, Object?> donnees) =>
      _doc(uid).set(donnees);
}

/// Garde les réglages d'analyse identiques sur tous les appareils d'un compte.
///
/// À la première lecture du compte, ce qui a été appris ici et ailleurs est
/// réuni (la valeur la plus travaillée gagne) ; ensuite le dernier appareil
/// qui change quelque chose l'emporte, y compris pour « tout oublier ».
class SynchroPreferencesAnalyse {
  SynchroPreferencesAnalyse({
    required this.prefs,
    required this.depot,
    required Stream<String?> comptes,
  }) {
    prefs.surModification = _envoyer;
    _abonnement = comptes.listen(_changerDeCompte);
  }

  final PreferencesAnalyseMemoire prefs;
  final DepotPreferencesAnalyse depot;

  StreamSubscription<String?>? _abonnement;
  StreamSubscription<Map<String, Object?>?>? _ecoute;
  String? _uid;
  bool _premiere = true;

  void _changerDeCompte(String? uid) {
    if (uid == _uid) return;
    unawaited(_ecoute?.cancel());
    _ecoute = null;
    _uid = uid;
    _premiere = true;
    if (uid == null) return;
    _ecoute = depot.ecouter(uid).listen(_recevoir, onError: (_) {});
  }

  Future<void> _recevoir(Map<String, Object?>? distant) async {
    final distantAppris = _lireAppris(distant?['etalonnage']);
    final distantCm = distant?['assiette'];
    if (_premiere) {
      _premiere = false;
      final reunis = {...distantAppris};
      for (final e in prefs.appris.entries) {
        final autre = reunis[e.key];
        if (autre == null || e.value.nombre > autre.nombre) {
          reunis[e.key] = e.value;
        }
      }
      final cm = distantCm is int ? distantCm : prefs.assietteCm;
      await prefs.remplacerPar(cm, reunis);
      // Le compte n'avait pas tout : on le complète.
      if (distant == null || reunis.length != distantAppris.length) {
        _envoyer();
      } else if (distantCm == null && cm != null) {
        _envoyer();
      }
      return;
    }
    await prefs.remplacerPar(distantCm is int ? distantCm : null, distantAppris);
  }

  Map<String, Etalonnage> _lireAppris(Object? brut) {
    final appris = <String, Etalonnage>{};
    if (brut is Map) {
      for (final e in brut.entries) {
        final v = Etalonnage.fromMap(e.value);
        if (v != null) appris['${e.key}'] = v;
      }
    }
    return appris;
  }

  void _envoyer() {
    final uid = _uid;
    if (uid == null) return;
    final cm = prefs.assietteCm;
    unawaited(
      depot
          .ecrire(uid, {
            'assiette': ?cm,
            'etalonnage': {
              for (final e in prefs.appris.entries) e.key: e.value.toMap(),
            },
          })
          .catchError((_) {}),
    );
  }

  Future<void> fermer() async {
    await _abonnement?.cancel();
    await _ecoute?.cancel();
    prefs.surModification = null;
  }
}
