import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'modele.dart';

/// Un aliment repéré sur la photo, avec sa portion estimée.
@immutable
class AlimentEstime {
  const AlimentEstime({
    required this.nom,
    required this.grammes,
    required this.macros,
  });

  final String nom;
  final double grammes;

  /// Apports pour [grammes].
  final Macros macros;

  /// Même aliment avec une autre portion (macros proportionnelles).
  AlimentEstime avecGrammes(double g) => AlimentEstime(
    nom: nom,
    grammes: g,
    macros: grammes <= 0 ? macros : macros.multiplie(g / grammes),
  );
}

enum CauseAnalyse { reseau, auth, quota, illisible, indisponible }

class AnalyseEchouee implements Exception {
  const AnalyseEchouee(this.cause);

  final CauseAnalyse cause;

  @override
  String toString() => 'AnalyseEchouee($cause)';
}

abstract class AnalysePhoto {
  /// Faux si le relais n'est pas configuré : la fonction est alors masquée.
  bool get disponible;

  /// Lève [AnalyseEchouee].
  Future<List<AlimentEstime>> analyser(Uint8List jpeg);
}

/// Appelle le relais Cloudflare (dossier `relais/`) avec le jeton Firebase.
class AnalysePhotoRelais implements AnalysePhoto {
  AnalysePhotoRelais({
    required this.url,
    required this.jeton,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String url;
  final Future<String?> Function() jeton;
  final http.Client _client;

  @override
  bool get disponible => url.isNotEmpty;

  @override
  Future<List<AlimentEstime>> analyser(Uint8List jpeg) async {
    final token = await jeton();
    if (token == null) throw const AnalyseEchouee(CauseAnalyse.auth);
    final http.Response r;
    try {
      r = await _client
          .post(
            Uri.parse('$url/analyse'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'image/jpeg',
            },
            body: jpeg,
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const AnalyseEchouee(CauseAnalyse.reseau);
    } on http.ClientException {
      throw const AnalyseEchouee(CauseAnalyse.reseau);
    }
    switch (r.statusCode) {
      case 200:
        break;
      case 401:
        throw const AnalyseEchouee(CauseAnalyse.auth);
      case 429:
        throw const AnalyseEchouee(CauseAnalyse.quota);
      case 413 || 422:
        throw const AnalyseEchouee(CauseAnalyse.illisible);
      default:
        throw const AnalyseEchouee(CauseAnalyse.indisponible);
    }
    try {
      final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return [
        for (final a in json['aliments'] as List)
          AlimentEstime(
            nom: (a['nom'] as String).trim(),
            grammes: (a['grammes'] as num).toDouble(),
            macros: Macros(
              kcal: (a['kcal'] as num).toDouble(),
              proteines: (a['proteines'] as num?)?.toDouble() ?? 0,
              glucides: (a['glucides'] as num?)?.toDouble() ?? 0,
              lipides: (a['lipides'] as num?)?.toDouble() ?? 0,
            ),
          ),
      ];
    } catch (_) {
      throw const AnalyseEchouee(CauseAnalyse.illisible);
    }
  }
}

/// Prend une photo avec l'appareil ; null si l'utilisateur annule.
typedef PrisePhoto = Future<Uint8List?> Function();

Future<Uint8List?> prisePhotoCamera() async {
  final f = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1024,
    imageQuality: 80,
  );
  return f?.readAsBytes();
}
