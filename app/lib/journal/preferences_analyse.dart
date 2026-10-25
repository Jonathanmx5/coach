import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analyse_photo.dart';
import 'modele.dart';

/// Diamètres d'assiette proposés dans les Réglages, en centimètres.
const diametresAssiette = [20, 22, 24, 26, 28, 30];

/// Précision envoyée à l'IA : la taille de l'assiette d'abord (le relais ne
/// garde que 200 caractères), puis ce que la personne a écrit.
String indiceAvecAssiette(String precision, int? assietteCm) {
  final p = precision.trim();
  if (assietteCm == null) return p;
  final assiette = 'Assiette de $assietteCm cm de diamètre.';
  return p.isEmpty ? assiette : '$assiette $p';
}

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'ô': 'o',
  'ö': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

/// Clé d'un aliment pour l'apprentissage : minuscules, sans accents, sans
/// précision entre parenthèses (« Riz (basmati) » et « riz » se rejoignent).
String cleAliment(String nom) {
  final sans = nom.replaceAll(RegExp(r'\([^)]*\)'), ' ').toLowerCase();
  final buffer = StringBuffer();
  for (final c in sans.split('')) {
    buffer.write(_accents[c] ?? c);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Ce que l'appli a appris des corrections d'une personne pour un aliment :
/// le rapport moyen entre la portion gardée et celle estimée par l'IA.
@immutable
class Etalonnage {
  const Etalonnage(this.facteur, this.nombre);

  final double facteur;
  final int nombre;

  Map<String, Object> toMap() => {'f': facteur, 'n': nombre};

  static Etalonnage? fromMap(Object? m) {
    if (m is! Map) return null;
    final f = m['f'];
    final n = m['n'];
    if (f is! num || n is! num || f <= 0) return null;
    return Etalonnage(f.toDouble(), n.toInt());
  }
}

/// Nombre de repas après lequel un écart appris est appliqué.
const etalonnageMinimum = 2;

/// Ajoute une correction (portion gardée / portion estimée) à l'étalonnage :
/// moyenne géométrique glissante sur les 10 dernières, chaque rapport borné
/// entre 0,5 et 2 pour qu'une erreur de saisie ne fausse pas tout.
Etalonnage etalonner(Etalonnage? avant, double rapport) {
  final r = rapport.clamp(0.5, 2.0);
  final poids = math.min(avant?.nombre ?? 0, 9);
  final log = avant == null
      ? math.log(r)
      : (math.log(avant.facteur) * poids + math.log(r)) / (poids + 1);
  return Etalonnage(math.exp(log), (avant?.nombre ?? 0) + 1);
}

/// Facteur à appliquer à une portion estimée : 1 tant qu'il n'y a pas assez de
/// corrections ou que l'écart est faible (moins de 5 %), sinon entre 0,6 et 1,6.
double facteurAppris(Etalonnage? e) {
  if (e == null || e.nombre < etalonnageMinimum) return 1;
  final f = e.facteur.clamp(0.6, 1.6);
  return (f - 1).abs() < 0.05 ? 1 : f;
}

/// Réglages et apprentissages de l'analyse photo, gardés sur le téléphone.
abstract class PreferencesAnalyse {
  /// Diamètre des assiettes habituelles, en cm ; null si non renseigné.
  int? get assietteCm;

  Future<void> definirAssiette(int? cm);

  /// Facteur appris pour cet aliment (1 si rien d'appris).
  double facteurPour(String nom);

  /// Note la portion estimée par l'IA et celle que la personne a gardée.
  Future<void> apprendre(
    String nom, {
    required double estime,
    required double retenu,
  });

  /// Oublie tout ce qui a été appris.
  Future<void> oublier();
}

/// Rien de réglé, rien d'appris (tests, repli).
class PreferencesAnalyseNeutres implements PreferencesAnalyse {
  const PreferencesAnalyseNeutres();

  @override
  int? get assietteCm => null;

  @override
  Future<void> definirAssiette(int? cm) async {}

  @override
  double facteurPour(String nom) => 1;

  @override
  Future<void> apprendre(
    String nom, {
    required double estime,
    required double retenu,
  }) async {}

  @override
  Future<void> oublier() async {}
}

/// En mémoire : sert de base à la version gardée sur le téléphone et aux tests.
class PreferencesAnalyseMemoire implements PreferencesAnalyse {
  PreferencesAnalyseMemoire({int? assietteCm, Map<String, Etalonnage>? appris})
    : _assiette = assietteCm,
      _appris = {...?appris};

  /// Au-delà, les aliments les moins récents sont oubliés.
  static const maxAliments = 200;

  int? _assiette;
  final Map<String, Etalonnage> _appris;

  Map<String, Etalonnage> get appris => Map.unmodifiable(_appris);

  @override
  int? get assietteCm => _assiette;

  @override
  Future<void> definirAssiette(int? cm) async {
    _assiette = cm;
    await enregistrer();
  }

  @override
  double facteurPour(String nom) => facteurAppris(_appris[cleAliment(nom)]);

  @override
  Future<void> apprendre(
    String nom, {
    required double estime,
    required double retenu,
  }) async {
    final cle = cleAliment(nom);
    if (cle.isEmpty || estime <= 0 || retenu <= 0) return;
    final suivant = etalonner(_appris.remove(cle), retenu / estime);
    _appris[cle] = suivant; // en dernier : le plus récent
    while (_appris.length > maxAliments) {
      _appris.remove(_appris.keys.first);
    }
    await enregistrer();
  }

  @override
  Future<void> oublier() async {
    _appris.clear();
    await enregistrer();
  }

  /// Rien à faire en mémoire ; la version locale écrit sur le téléphone.
  @protected
  Future<void> enregistrer() async {}
}

class PreferencesAnalyseLocales extends PreferencesAnalyseMemoire {
  PreferencesAnalyseLocales._(this._prefs, {super.assietteCm, super.appris});

  static const _cleAssiette = 'analyse_assiette_cm';
  static const _cleAppris = 'analyse_etalonnage';

  final SharedPreferences _prefs;

  static Future<PreferencesAnalyseLocales> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final appris = <String, Etalonnage>{};
    try {
      final brut = jsonDecode(prefs.getString(_cleAppris) ?? '{}');
      if (brut is Map) {
        for (final e in brut.entries) {
          final v = Etalonnage.fromMap(e.value);
          if (v != null) appris['${e.key}'] = v;
        }
      }
    } catch (_) {
      // Données illisibles : on repart de zéro.
    }
    final cm = prefs.getInt(_cleAssiette);
    return PreferencesAnalyseLocales._(
      prefs,
      assietteCm: diametresAssiette.contains(cm) ? cm : null,
      appris: appris,
    );
  }

  @override
  Future<void> enregistrer() async {
    final cm = assietteCm;
    if (cm == null) {
      await _prefs.remove(_cleAssiette);
    } else {
      await _prefs.setInt(_cleAssiette, cm);
    }
    await _prefs.setString(
      _cleAppris,
      jsonEncode({for (final e in appris.entries) e.key: e.value.toMap()}),
    );
  }
}

/// Quantité de matière grasse peu visible sur la photo.
enum QuantiteGras { aucune, unPeu, beaucoup }

/// Huile de cuisson et sauce que la photo ne montre pas bien, ajoutées comme
/// des aliments (valeurs moyennes : 1 cuillère à café d'huile = 5 g, 1 cuillère
/// à soupe = 15 g ; sauce type vinaigrette ou mayonnaise allégée).
List<AlimentEstime> grasAjoutes({
  required QuantiteGras huile,
  required QuantiteGras sauce,
  required String nomHuile,
  required String nomSauce,
}) => [
  if (huile != QuantiteGras.aucune)
    AlimentEstime(
      nom: nomHuile,
      grammes: huile == QuantiteGras.unPeu ? 5 : 15,
      macros: huile == QuantiteGras.unPeu
          ? const Macros(kcal: 45, lipides: 5)
          : const Macros(kcal: 135, lipides: 15),
      satures: huile == QuantiteGras.unPeu ? 0.7 : 2.1,
      sucres: 0,
    ),
  if (sauce != QuantiteGras.aucune)
    AlimentEstime(
      nom: nomSauce,
      grammes: sauce == QuantiteGras.unPeu ? 15 : 40,
      macros: sauce == QuantiteGras.unPeu
          ? const Macros(kcal: 75, glucides: 1.5, lipides: 7.5)
          : const Macros(kcal: 200, glucides: 4, lipides: 20),
      satures: sauce == QuantiteGras.unPeu ? 1.2 : 3.2,
      sucres: sauce == QuantiteGras.unPeu ? 1 : 2.5,
    ),
];
