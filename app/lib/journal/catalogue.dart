import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'modele.dart';

@immutable
class ProduitOff {
  const ProduitOff({required this.nom, required this.pour100g});

  final String nom;

  /// Valeurs nutritionnelles pour 100 g.
  final Macros pour100g;
}

/// Le réseau ou le serveur n'a pas répondu correctement.
class ErreurCatalogue implements Exception {
  const ErreurCatalogue(this.cause);

  final Object cause;

  @override
  String toString() => 'ErreurCatalogue($cause)';
}

abstract class CatalogueProduits {
  /// Produit pour un code-barres, ou null s'il est inconnu ou sans valeurs
  /// nutritionnelles. Lève [ErreurCatalogue] si le réseau échoue.
  Future<ProduitOff?> chercher(String codeBarres);
}

/// Base collaborative Open Food Facts (gratuite, sans clé).
class CatalogueOpenFoodFacts implements CatalogueProduits {
  CatalogueOpenFoodFacts([http.Client? client])
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _agent =
      'CrunchAndGo/0.9 (https://github.com/Jonathanmx5/coach)';

  @override
  Future<ProduitOff?> chercher(String codeBarres) async {
    final url = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$codeBarres.json',
      {'fields': 'product_name,brands,nutriments'},
    );
    final http.Response reponse;
    try {
      reponse = await _client
          .get(url, headers: {'User-Agent': _agent})
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw ErreurCatalogue(e);
    }
    if (reponse.statusCode != 200) throw ErreurCatalogue(reponse.statusCode);

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(reponse.bodyBytes));
    } catch (e) {
      throw ErreurCatalogue(e);
    }
    if (json is! Map || json['status'] != 1 || json['product'] is! Map) {
      return null;
    }
    final produit = (json['product'] as Map).cast<String, Object?>();
    final n = ((produit['nutriments'] as Map?) ?? const {})
        .cast<String, Object?>();

    double? nombre(String cle) => (n[cle] as num?)?.toDouble();
    final kj = nombre('energy_100g');
    final kcal = nombre('energy-kcal_100g') ?? (kj == null ? null : kj / 4.184);
    if (kcal == null) return null;

    final marque = (produit['brands'] as String?)?.split(',').first.trim();
    final nom = (produit['product_name'] as String?)?.trim() ?? '';
    return ProduitOff(
      nom: nom.isEmpty ? (marque ?? codeBarres) : nom,
      pour100g: Macros(
        kcal: kcal,
        proteines: nombre('proteins_100g') ?? 0,
        glucides: nombre('carbohydrates_100g') ?? 0,
        lipides: nombre('fat_100g') ?? 0,
      ),
    );
  }
}
