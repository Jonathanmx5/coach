import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../image_propre.dart';
import 'modele.dart';

/// Sous ce seuil de certitude, l'aliment est signalé « à vérifier ».
const seuilConfiance = 0.6;

/// Un aliment repéré sur la photo, avec sa portion estimée.
@immutable
class AlimentEstime {
  const AlimentEstime({
    required this.nom,
    required this.grammes,
    required this.macros,
    this.confiance,
    this.sucres,
    this.satures,
    this.grammesMin,
    this.grammesMax,
  });

  final String nom;
  final double grammes;

  /// Apports pour [grammes].
  final Macros macros;

  /// Certitude de l'IA, de 0 à 1 ; null pour un aliment ajouté à la main.
  final double? confiance;

  /// Part des glucides qui est du sucre, et part des lipides saturée, pour
  /// [grammes] ; null si inconnues.
  final double? sucres;
  final double? satures;

  /// Fourchette de quantité donnée par l'IA (la vraie valeur y a de bonnes
  /// chances d'être) ; null si elle n'en a pas donné.
  final double? grammesMin;
  final double? grammesMax;

  /// Vrai si la fourchette est assez large pour valoir la peine d'être montrée.
  bool get aFourchette =>
      grammesMin != null &&
      grammesMax != null &&
      grammes > 0 &&
      (grammesMax! - grammesMin!) / grammes >= 0.1;

  Map<String, Object?> toMap() => {
    'nom': nom,
    'grammes': grammes,
    'macros': macros.toMap(),
    if (confiance != null) 'confiance': confiance,
    if (sucres != null) 'sucres': sucres,
    if (satures != null) 'satures': satures,
    if (grammesMin != null) 'grammesMin': grammesMin,
    if (grammesMax != null) 'grammesMax': grammesMax,
  };

  static AlimentEstime fromMap(Map<String, Object?> m) => AlimentEstime(
    nom: m['nom'] as String? ?? '',
    grammes: (m['grammes'] as num?)?.toDouble() ?? 0,
    macros: Macros.fromMap((m['macros']! as Map).cast<String, Object?>()),
    confiance: (m['confiance'] as num?)?.toDouble(),
    sucres: (m['sucres'] as num?)?.toDouble(),
    satures: (m['satures'] as num?)?.toDouble(),
    grammesMin: (m['grammesMin'] as num?)?.toDouble(),
    grammesMax: (m['grammesMax'] as num?)?.toDouble(),
  );

  bool get aVerifier => confiance != null && confiance! < seuilConfiance;

  /// Même aliment avec une autre portion (apports proportionnels).
  AlimentEstime avecGrammes(double g) {
    final f = grammes <= 0 ? 1.0 : g / grammes;
    return AlimentEstime(
      nom: nom,
      grammes: g,
      confiance: confiance,
      sucres: sucres == null ? null : sucres! * f,
      satures: satures == null ? null : satures! * f,
      grammesMin: grammesMin == null ? null : grammesMin! * f,
      grammesMax: grammesMax == null ? null : grammesMax! * f,
      macros: grammes <= 0 ? macros : macros.multiplie(f),
    );
  }

  AlimentEstime avecNom(String n) => AlimentEstime(
    nom: n,
    grammes: grammes,
    macros: macros,
    confiance: confiance,
    sucres: sucres,
    satures: satures,
    grammesMin: grammesMin,
    grammesMax: grammesMax,
  );

  /// Même aliment, vérifié par l'utilisateur (nom ou portion corrigés) : il
  /// n'est plus « à vérifier », quelle que soit la certitude de l'IA.
  AlimentEstime valideParUtilisateur() => AlimentEstime(
    nom: nom,
    grammes: grammes,
    macros: macros,
    sucres: sucres,
    satures: satures,
    grammesMin: grammesMin,
    grammesMax: grammesMax,
  );
}

/// Calories du repas entre deux bornes, d'après les fourchettes de quantité de
/// l'IA (un aliment sans fourchette compte pour sa valeur). Null si aucun
/// aliment n'a de fourchette utile.
({int min, int max})? fourchetteKcal(Iterable<AlimentEstime> aliments) {
  var min = 0.0;
  var max = 0.0;
  var une = false;
  for (final a in aliments) {
    if (a.aFourchette) {
      une = true;
      min += a.macros.kcal * a.grammesMin! / a.grammes;
      max += a.macros.kcal * a.grammesMax! / a.grammes;
    } else {
      min += a.macros.kcal;
      max += a.macros.kcal;
    }
  }
  return une ? (min: min.round(), max: max.round()) : null;
}

/// Ce que l'IA a compris de la photo : de quoi il s'agit (plat, produit et
/// marque) et les aliments avec leurs apports.
@immutable
class ResultatAnalyse {
  const ResultatAnalyse({
    required this.description,
    required this.aliments,
    this.restantes,
  });

  final String description;
  final List<AlimentEstime> aliments;

  /// Analyses photo encore possibles aujourd'hui, si le relais le dit.
  final int? restantes;
}

/// Le nombre d'analyses restantes renvoyé par le relais : un entier positif
/// ou nul, sinon rien (ancien relais, valeur inattendue).
int? lireRestantes(Object? valeur) =>
    valeur is num && valeur.isFinite && valeur >= 0 ? valeur.floor() : null;

/// [tropGros] : la photo dépasse la taille acceptée par le relais (413).
enum CauseAnalyse { reseau, auth, quota, illisible, tropGros, indisponible }

class AnalyseEchouee implements Exception {
  const AnalyseEchouee(this.cause);

  final CauseAnalyse cause;

  @override
  String toString() => 'AnalyseEchouee($cause)';
}

abstract class AnalysePhoto {
  /// Faux si le relais n'est pas configuré : l'analyse n'est alors pas proposée.
  bool get disponible;

  /// [indice] : précision libre de l'utilisateur (« sauce à part »…). Elle
  /// part dans le corps de la requête, jamais dans l'adresse (qui peut finir
  /// dans des journaux). Lève [AnalyseEchouee].
  Future<ResultatAnalyse> analyser(Uint8List jpeg, {String? indice});
}

/// Appelle le relais Cloudflare (dossier `relais/`) avec le jeton Firebase.
class AnalysePhotoRelais implements AnalysePhoto {
  AnalysePhotoRelais({
    required this.url,
    required this.jeton,
    this.preuve,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String url;
  final Future<String?> Function() jeton;

  /// Jeton App Check (preuve que l'appel vient de l'application), s'il existe.
  final Future<String?> Function()? preuve;
  final http.Client _client;

  @override
  bool get disponible => url.isNotEmpty;

  @override
  Future<ResultatAnalyse> analyser(Uint8List jpeg, {String? indice}) async {
    // Le jeton Firebase peut devoir être renouvelé en ligne : hors réseau,
    // getIdToken lève une exception.
    final String? token;
    try {
      token = await jeton();
    } catch (_) {
      throw const AnalyseEchouee(CauseAnalyse.reseau);
    }
    if (token == null) throw const AnalyseEchouee(CauseAnalyse.auth);
    String? preuveAppCheck;
    try {
      preuveAppCheck = await preuve?.call();
    } catch (_) {
      // Sans preuve, le relais décide (il ne l'impose pas encore).
    }
    final entetes = {
      'authorization': 'Bearer $token',
      if (preuveAppCheck != null && preuveAppCheck.isNotEmpty)
        'x-firebase-appcheck': preuveAppCheck,
    };
    final precision = indice?.trim() ?? '';
    var r = await _envoyer(jpeg, precision, entetes);
    // Repli tant que le relais n'accepte pas le multipart : l'ancien relais
    // lit tout le corps comme une image et échoue. On renvoie alors la photo
    // seule, sans la précision. À retirer une fois le relais à jour.
    if (precision.isNotEmpty &&
        const {400, 415, 422, 502}.contains(r.statusCode)) {
      r = await _envoyer(jpeg, '', entetes);
    }
    switch (r.statusCode) {
      case 200:
        break;
      case 401:
        throw const AnalyseEchouee(CauseAnalyse.auth);
      case 429:
        throw const AnalyseEchouee(CauseAnalyse.quota);
      case 413:
        throw const AnalyseEchouee(CauseAnalyse.tropGros);
      case 422:
        throw const AnalyseEchouee(CauseAnalyse.illisible);
      default:
        throw const AnalyseEchouee(CauseAnalyse.indisponible);
    }
    try {
      final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return ResultatAnalyse(
        description: ((json['description'] as String?) ?? '').trim(),
        restantes: lireRestantes(json['restantes']),
        aliments: [
          for (final a in json['aliments'] as List)
            AlimentEstime(
              nom: (a['nom'] as String).trim(),
              grammes: (a['grammes'] as num).toDouble(),
              confiance: (a['confiance'] as num?)?.toDouble(),
              sucres: (a['sucres'] as num?)?.toDouble(),
              satures: (a['satures'] as num?)?.toDouble(),
              grammesMin: (a['grammes_min'] as num?)?.toDouble(),
              grammesMax: (a['grammes_max'] as num?)?.toDouble(),
              macros: Macros(
                kcal: (a['kcal'] as num).toDouble(),
                proteines: (a['proteines'] as num?)?.toDouble() ?? 0,
                glucides: (a['glucides'] as num?)?.toDouble() ?? 0,
                lipides: (a['lipides'] as num?)?.toDouble() ?? 0,
              ),
            ),
        ],
      );
    } catch (_) {
      throw const AnalyseEchouee(CauseAnalyse.illisible);
    }
  }

  /// Sans précision : le JPEG brut. Avec : multipart/form-data (parties
  /// `image` et `indice`). Délai dépassé : service indisponible ; pas de
  /// connexion : réseau.
  Future<http.Response> _envoyer(
    Uint8List jpeg,
    String precision,
    Map<String, String> entetes,
  ) async {
    final adresse = Uri.parse('$url/analyse');
    final http.BaseRequest requete;
    if (precision.isEmpty) {
      requete = http.Request('POST', adresse)
        ..headers.addAll(entetes)
        ..headers['content-type'] = 'image/jpeg'
        ..bodyBytes = jpeg;
    } else {
      requete = http.MultipartRequest('POST', adresse)
        ..headers.addAll(entetes)
        ..fields['indice'] = precision
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            jpeg,
            filename: 'repas.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
    }
    try {
      return await _client
          .send(requete)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const AnalyseEchouee(CauseAnalyse.indisponible);
    } on SocketException {
      throw const AnalyseEchouee(CauseAnalyse.reseau);
    } on http.ClientException {
      throw const AnalyseEchouee(CauseAnalyse.reseau);
    }
  }
}

/// D'où vient la photo.
enum SourcePhoto { appareil, galerie }

/// Prend ou choisit une photo ; null si l'utilisateur annule.
typedef PrisePhoto = Future<Uint8List?> Function(SourcePhoto source);

/// Les octets rendus sont un JPEG ré-encodé sans métadonnées (ni position
/// GPS, ni numéro de série) : ce sont eux qui partent à l'analyse et qui sont
/// gardés dans photos_repas. La copie d'image_picker est effacée du cache.
/// Null aussi si le fichier choisi n'est pas une image lisible.
Future<Uint8List?> prisePhotoCamera(SourcePhoto source) async {
  final f = await ImagePicker().pickImage(
    source: source == SourcePhoto.appareil
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: 1024,
    imageQuality: 80,
  );
  if (f == null) return null;
  return lirePriseNettoyee(f);
}
