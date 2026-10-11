import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Suppression des données d'un compte (droit à l'effacement).
abstract class DonneesCompte {
  /// Efface tout ce que l'application a enregistré pour [uid] dans Firestore.
  /// Hors-ligne, ce Future ne se termine qu'au retour du réseau : l'appelant
  /// vérifie la connexion avant.
  Future<void> supprimerTout(String uid);
}

class FirestoreDonneesCompte implements DonneesCompte {
  FirestoreDonneesCompte([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Sous-collections de users/{uid}. Une nouvelle collection ajoutée à
  /// l'application doit l'être ici (un test compare avec le code).
  static const collections = [
    'repas',
    'activites',
    'pesees',
    'mensurations',
    'eau',
    'complements',
    'prises',
    'seances',
    'ressentis',
    'planning',
    'reglages',
  ];

  @override
  Future<void> supprimerTout(String uid) async {
    final utilisateur = _db.collection('users').doc(uid);
    for (final nom in collections) {
      while (true) {
        final lot = await utilisateur.collection(nom).limit(400).get();
        if (lot.docs.isEmpty) break;
        final batch = _db.batch();
        for (final d in lot.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await utilisateur.delete();
  }
}

/// Données que l'utilisateur accepte d'envoyer à un service extérieur.
enum Consentement { photo, meteo }

abstract class ConsentementsRepository {
  Stream<Set<Consentement>> accordes(String uid);

  Future<void> definir(String uid, Consentement c, bool accorde);
}

class FirestoreConsentementsRepository implements ConsentementsRepository {
  FirestoreConsentementsRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('reglages')
      .doc('consentements');

  @override
  Stream<Set<Consentement>> accordes(String uid) =>
      _doc(uid).snapshots().map((d) {
        final data = d.data() ?? const {};
        return {
          for (final c in Consentement.values)
            if (data[c.name] is num) c,
        };
      });

  /// Garde la date de l'accord (preuve du consentement) ; la retire si refusé.
  @override
  Future<void> definir(String uid, Consentement c, bool accorde) => _doc(uid)
      .set({
        c.name: accorde
            ? DateTime.now().millisecondsSinceEpoch
            : FieldValue.delete(),
      }, SetOptions(merge: true));
}

/// Demande l'accord de l'utilisateur la première fois (et l'enregistre).
/// Rend vrai s'il est donné, maintenant ou avant.
Future<bool> assurerConsentement(
  BuildContext context,
  ConsentementsRepository depot,
  String uid,
  Consentement c,
) async {
  final deja = await depot
      .accordes(uid)
      .first
      .timeout(const Duration(seconds: 3), onTimeout: () => <Consentement>{});
  if (deja.contains(c)) return true;
  if (!context.mounted) return false;
  final t = AppLocalizations.of(context)!;
  final accepte = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(
        c == Consentement.photo ? t.consentPhotoTitre : t.consentMeteoTitre,
      ),
      content: Text(
        c == Consentement.photo ? t.consentPhotoTexte : t.consentMeteoTexte,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.refuser),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.accepter),
        ),
      ],
    ),
  );
  if (accepte != true) return false;
  // Hors-ligne, l'écriture ne se termine qu'à la synchronisation.
  unawaited(depot.definir(uid, c, true));
  return true;
}
