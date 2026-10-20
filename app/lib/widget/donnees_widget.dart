import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../accueil/anneaux.dart';

/// Noms complets des classes Android des widgets (voir WidgetCoach.kt,
/// WidgetEau.kt et WidgetRepas.kt).
const widgetsAndroid = [
  'io.github.jonathanmx5.coach.WidgetCoach',
  'io.github.jonathanmx5.coach.WidgetEau',
  'io.github.jonathanmx5.coach.WidgetRepas',
];

/// Clés des chiffres du jour (hors eau) : textes, description et image des
/// anneaux, et le jour auquel ils se rapportent. Les widgets Android ne les
/// affichent que si `donnees_jour` est le jour courant.
const clesDonneesJour = [
  'bilan_texte',
  'repas_texte',
  'proteines_texte',
  'anneaux_description',
  'donnees_jour',
  'anneaux',
];

/// Clés de l'eau : total, objectif, texte et jour du total (`eau_jour`), tenus
/// à jour aussi par les boutons d'eau du widget.
const clesEau = ['eau_texte', 'eau_ml', 'eau_objectif_ml', 'eau_jour'];

/// Toutes les clés du widget, plus le compte (`uid`) auquel elles
/// appartiennent. Sans elles, les widgets affichent « Connecte-toi dans
/// l'appli ».
const clesWidget = [...clesDonneesJour, ...clesEau, 'uid'];

/// Ce que le widget de l'écran d'accueil affiche : les mêmes chiffres que la
/// carte « Aujourd'hui » de l'application.
@immutable
class DonneesWidget {
  const DonneesWidget({
    required this.brulees,
    required this.objectifBrule,
    required this.mangees,
    required this.objectifMange,
    required this.proteines,
    required this.objectifProteines,
    required this.eauMl,
    required this.objectifEauMl,
    this.description = '',
  });

  final double brulees;
  final double objectifBrule;
  final double mangees;
  final double objectifMange;
  final double proteines;
  final double objectifProteines;
  final int eauMl;
  final int objectifEauMl;

  /// Ce que le lecteur d'écran dit des anneaux, chiffres compris. Tiré des
  /// mêmes chiffres : il n'entre pas dans l'égalité.
  final String description;

  static double _part(double v, double objectif) =>
      objectif <= 0 ? 0 : v / objectif;

  /// Brûlées, mangées, protéines : les trois anneaux de l'image. L'eau est
  /// une barre native du widget, que ses boutons tiennent à jour sans
  /// redessiner l'image.
  List<double> get progres => [
    _part(brulees, objectifBrule),
    _part(mangees, objectifMange),
    _part(proteines, objectifProteines),
  ];

  /// Ce qui se voit sur l'image : les anneaux au pourcent près et le bilan du
  /// centre. L'image n'est redessinée que s'il change.
  String get cleImage => [
    for (final p in progres) (p.clamp(0.0, 1.0) * 100).round(),
    bilanTexte(mangees - brulees),
  ].join('|');

  String get eauTexte => texteEau(eauMl, objectifEauMl);

  /// « 1250 / 2080 kcal ».
  String get repasTexte => '${mangees.round()} / ${objectifMange.round()} kcal';

  /// « Protéines 85 / 128 g ».
  String get proteinesTexte =>
      'Protéines ${proteines.round()} / ${objectifProteines.round()} g';

  String get bilanLigne => 'Bilan ${bilanTexte(mangees - brulees)} kcal';

  /// Sans montre, l'estimation des calories brûlées monte d'environ 1 kcal par
  /// minute : à 10 kcal près, pour ne pas renvoyer le widget chaque minute.
  static int _brulees10(double v) => (v / 10).round();

  @override
  bool operator ==(Object other) =>
      other is DonneesWidget &&
      _brulees10(other.brulees) == _brulees10(brulees) &&
      other.objectifBrule.round() == objectifBrule.round() &&
      other.mangees.round() == mangees.round() &&
      other.objectifMange.round() == objectifMange.round() &&
      other.proteines.round() == proteines.round() &&
      other.objectifProteines.round() == objectifProteines.round() &&
      other.eauMl == eauMl &&
      other.objectifEauMl == objectifEauMl;

  @override
  int get hashCode => Object.hash(
    _brulees10(brulees),
    objectifBrule.round(),
    mangees.round(),
    objectifMange.round(),
    proteines.round(),
    objectifProteines.round(),
    eauMl,
    objectifEauMl,
  );
}

/// « 1,25 / 2,65 L ».
String texteEau(int ml, int objectifMl) {
  String litres(int v) => (v / 1000).toStringAsFixed(2).replaceAll('.', ',');
  return '${litres(ml)} / ${litres(objectifMl)} L';
}

/// Envoie les chiffres du jour au widget de l'écran d'accueil.
abstract class MiseAJourWidget {
  /// [jour] : le jour de ces chiffres (celui qu'affiche la carte, pas l'heure
  /// de l'envoi) ; [uid] : le compte auquel ils appartiennent.
  Future<void> mettre(
    DonneesWidget donnees, {
    required DateTime jour,
    required String uid,
  });

  /// Retire toutes les données du widget (déconnexion, compte supprimé) : il
  /// affiche alors « Connecte-toi dans l'appli ».
  Future<void> effacer();

  /// Action demandée par un bouton d'un widget qui ouvre l'application
  /// (« photo »...), pendant que l'application est ouverte.
  Stream<String> get actions;

  /// Action qui a lancé l'application, s'il y en a une. Rendue une seule
  /// fois : l'accueil recréé (autre compte, questionnaire) ne la rejoue pas.
  Future<String?> actionAuLancement();
}

/// Petit stockage partagé avec le widget Android (SharedPreferences).
abstract class StockageWidget {
  Future<String?> lire(String cle);
  Future<void> ecrire(String cle, String? valeur);

  /// Redessine le widget avec les valeurs enregistrées.
  Future<void> rafraichir();
}

class StockageHomeWidget implements StockageWidget {
  @override
  Future<String?> lire(String cle) => HomeWidget.getWidgetData<String>(cle);

  @override
  Future<void> ecrire(String cle, String? valeur) =>
      HomeWidget.saveWidgetData<String>(cle, valeur);

  @override
  Future<void> rafraichir() => Future.wait([
    for (final nom in widgetsAndroid)
      HomeWidget.updateWidget(qualifiedAndroidName: nom),
  ]).then((_) {});
}

/// Retire [cles] du widget. Pour l'image des anneaux, le fichier est aussi
/// supprimé : home_widget ne retire que son chemin.
Future<void> retirerDuWidget(StockageWidget stockage, List<String> cles) async {
  final image = cles.contains('anneaux')
      ? await stockage.lire('anneaux')
      : null;
  for (final cle in cles) {
    await stockage.ecrire(cle, null);
  }
  if (image != null) {
    try {
      final fichier = File(image);
      if (await fichier.exists()) await fichier.delete();
    } catch (_) {}
  }
}

/// Retire toutes les données du widget puis le redessine.
Future<void> effacerDonneesWidget(StockageWidget stockage) async {
  await retirerDuWidget(stockage, clesWidget);
  await stockage.rafraichir();
}

/// Dessine les anneaux en image (le widget Android ne sait pas dessiner du
/// Flutter) puis met à jour le texte et les boutons.
class WidgetAccueil implements MiseAJourWidget {
  WidgetAccueil({
    StockageWidget? stockage,
    Future<Uri?> Function()? lancement,
    Future<void> Function(DonneesWidget)? dessiner,
  }) : _stockage = stockage ?? StockageHomeWidget(),
       _lancement = lancement ?? HomeWidget.initiallyLaunchedFromHomeWidget,
       _dessinerAutre = dessiner;

  final StockageWidget _stockage;
  final Future<Uri?> Function() _lancement;
  final Future<void> Function(DonneesWidget)? _dessinerAutre;

  /// Valeurs déjà écrites par ce processus : chaque écriture est un accès
  /// disque synchrone côté Android, on n'écrit que ce qui change.
  final _ecrites = <String, String>{};
  String? _imageDessinee;
  String? _uid;
  bool _lancementLu = false;

  Widget _rendu(DonneesWidget d) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: Anneaux(
        taille: 220,
        animer: false,
        progres: d.progres,
        centre: Text(
          bilanTexte(d.mangees - d.brulees),
          style: const TextStyle(
            color: Color(0xFF2C2C2A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    ),
  );

  Future<void> _dessiner(DonneesWidget d) async {
    final autre = _dessinerAutre;
    if (autre != null) return autre(d);
    await HomeWidget.renderFlutterWidget(
      _rendu(d),
      key: 'anneaux',
      logicalSize: const Size(220, 220),
      pixelRatio: 2,
    );
  }

  @override
  Stream<String> get actions =>
      HomeWidget.widgetClicked.map(actionDe).where((a) => a.isNotEmpty);

  @override
  Future<String?> actionAuLancement() async {
    if (_lancementLu) return null;
    _lancementLu = true;
    try {
      final a = actionDe(await _lancement());
      return a.isEmpty ? null : a;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> mettre(
    DonneesWidget donnees, {
    required DateTime jour,
    required String uid,
  }) async {
    try {
      if (uid != _uid) {
        // Autre compte : rien de ce qu'on croit écrit n'est plus sûr.
        _ecrites.clear();
        _imageDessinee = null;
        _uid = uid;
      }
      var change = false;
      final image = donnees.cleImage;
      if (image != _imageDessinee) {
        await _dessiner(donnees);
        _imageDessinee = image;
        change = true;
      }
      final cleJour = cleDuJour(jour);
      final valeurs = {
        'eau_texte': donnees.eauTexte,
        'bilan_texte': donnees.bilanLigne,
        'repas_texte': donnees.repasTexte,
        'proteines_texte': donnees.proteinesTexte,
        'anneaux_description': donnees.description,
        'eau_ml': '${donnees.eauMl}',
        'eau_objectif_ml': '${donnees.objectifEauMl}',
        'eau_jour': cleJour,
        'donnees_jour': cleJour,
        'uid': uid,
      };
      for (final MapEntry(key: cle, value: valeur) in valeurs.entries) {
        if (_ecrites[cle] == valeur) continue;
        await _stockage.ecrire(cle, valeur);
        _ecrites[cle] = valeur;
        change = true;
      }
      if (change) await _stockage.rafraichir();
    } catch (_) {
      // Pas de widget possible (autre plateforme, image impossible) : sans
      // conséquence pour l'application.
    }
  }

  @override
  Future<void> effacer() async {
    _ecrites.clear();
    _imageDessinee = null;
    _uid = null;
    try {
      await effacerDonneesWidget(_stockage);
    } catch (_) {}
  }
}

/// L'action demandée par une adresse de widget : « eau », « photo », ou
/// « photo-appareil » (coach://photo?source=appareil : ouvre l'appareil photo
/// directement). Vide si l'adresse n'en porte pas.
String actionDe(Uri? u) {
  if (u == null || u.host.isEmpty) return '';
  if (u.host == 'photo' && u.queryParameters['source'] == 'appareil') {
    return 'photo-appareil';
  }
  return u.host;
}

String cleDuJour(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';
