import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Adresse à partager (QR code) : la dernière version publiée. Remplacée par
/// la fiche du Play Store une fois l'application publiée.
const lienPartage = 'https://github.com/Jonathanmx5/coach/releases/latest';

const lienConfidentialite =
    'https://github.com/Jonathanmx5/coach/blob/main/CONFIDENTIALITE.md';

@immutable
class InfoMiseAJour {
  const InfoMiseAJour({required this.version, required this.page});

  final String version;

  /// Page de la version, où se trouve l'APK à télécharger.
  final Uri page;
}

/// Numéro de version installé.
abstract class VersionAppli {
  Future<String> version();
}

class VersionAppliReelle implements VersionAppli {
  @override
  Future<String> version() async => (await PackageInfo.fromPlatform()).version;
}

abstract class MisesAJour {
  /// Une version plus récente que [versionActuelle] est-elle publiée ?
  /// Null si non, ou si on ne peut pas le savoir (hors-ligne…).
  Future<InfoMiseAJour?> verifier(String versionActuelle);
}

/// Cherche la dernière version publiée (hors brouillons) sur GitHub.
class MisesAJourGithub implements MisesAJour {
  MisesAJourGithub([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<InfoMiseAJour?> verifier(String versionActuelle) async {
    try {
      final r = await _client
          .get(
            Uri.https('api.github.com', '/repos/Jonathanmx5/coach/releases', {
              'per_page': '10',
            }),
            headers: {'accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      InfoMiseAJour? meilleure;
      for (final rel in jsonDecode(utf8.decode(r.bodyBytes)) as List) {
        if (rel['draft'] == true) continue;
        final version = '${rel['tag_name']}'.replaceFirst(RegExp('^v'), '');
        if (!versionPlusRecente(version, versionActuelle)) continue;
        if (meilleure == null ||
            versionPlusRecente(version, meilleure.version)) {
          meilleure = InfoMiseAJour(
            version: version,
            page: Uri.parse('${rel['html_url']}'),
          );
        }
      }
      return meilleure;
    } catch (_) {
      return null;
    }
  }
}

/// Compare deux numéros « 1.2.3 » (le suffixe « +build » et les lettres sont
/// ignorés). Faux si l'un des deux est illisible.
bool versionPlusRecente(String distante, String locale) {
  List<int>? lire(String v) {
    final nombres = v.split('+').first.split('-').first.split('.');
    final liste = [for (final n in nombres) int.tryParse(n)];
    return liste.contains(null) ? null : [for (final n in liste) n!];
  }

  final d = lire(distante);
  final l = lire(locale);
  if (d == null || l == null) return false;
  for (var i = 0; i < 3; i++) {
    final a = i < d.length ? d[i] : 0;
    final b = i < l.length ? l[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}
