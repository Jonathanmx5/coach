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
  });

  final double brulees;
  final double objectifBrule;
  final double mangees;
  final double objectifMange;
  final double proteines;
  final double objectifProteines;
  final int eauMl;
  final int objectifEauMl;

  static double _part(double v, double objectif) =>
      objectif <= 0 ? 0 : v / objectif;

  /// Brûlées, mangées, protéines, eau (comme [Anneaux]).
  List<double> get progres => [
    _part(brulees, objectifBrule),
    _part(mangees, objectifMange),
    _part(proteines, objectifProteines),
    _part(eauMl.toDouble(), objectifEauMl.toDouble()),
  ];

  String get eauTexte => texteEau(eauMl, objectifEauMl);

  /// « 1250 / 2080 kcal ».
  String get repasTexte => '${mangees.round()} / ${objectifMange.round()} kcal';

  /// « Protéines 85 / 128 g ».
  String get proteinesTexte =>
      'Protéines ${proteines.round()} / ${objectifProteines.round()} g';

  String get bilanLigne => 'Bilan ${bilanTexte(mangees - brulees)} kcal';

  @override
  bool operator ==(Object other) =>
      other is DonneesWidget &&
      other.brulees.round() == brulees.round() &&
      other.objectifBrule.round() == objectifBrule.round() &&
      other.mangees.round() == mangees.round() &&
      other.objectifMange.round() == objectifMange.round() &&
      other.proteines.round() == proteines.round() &&
      other.objectifProteines.round() == objectifProteines.round() &&
      other.eauMl == eauMl &&
      other.objectifEauMl == objectifEauMl;

  @override
  int get hashCode => Object.hash(
    brulees.round(),
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
  Future<void> mettre(DonneesWidget donnees);

  /// Action demandée par un bouton d'un widget qui ouvre l'application
  /// (« photo »...), pendant que l'application est ouverte.
  Stream<String> get actions;

  /// Action qui a lancé l'application, s'il y en a une.
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

/// Dessine les anneaux en image (le widget Android ne sait pas dessiner du
/// Flutter) puis met à jour le texte et les boutons.
class WidgetAccueil implements MiseAJourWidget {
  WidgetAccueil([StockageWidget? stockage])
    : _stockage = stockage ?? StockageHomeWidget();

  final StockageWidget _stockage;

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

  @override
  Stream<String> get actions => HomeWidget.widgetClicked
      .map((u) => u?.host ?? '')
      .where((h) => h.isNotEmpty);

  @override
  Future<String?> actionAuLancement() async {
    try {
      return (await HomeWidget.initiallyLaunchedFromHomeWidget())?.host;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> mettre(DonneesWidget donnees) async {
    try {
      await HomeWidget.renderFlutterWidget(
        _rendu(donnees),
        key: 'anneaux',
        logicalSize: const Size(220, 220),
        pixelRatio: 2,
      );
      final maintenant = DateTime.now();
      await _stockage.ecrire('eau_texte', donnees.eauTexte);
      await _stockage.ecrire('bilan_texte', donnees.bilanLigne);
      await _stockage.ecrire('repas_texte', donnees.repasTexte);
      await _stockage.ecrire('proteines_texte', donnees.proteinesTexte);
      await _stockage.ecrire('eau_ml', '${donnees.eauMl}');
      await _stockage.ecrire('eau_objectif_ml', '${donnees.objectifEauMl}');
      await _stockage.ecrire('eau_jour', cleDuJour(maintenant));
      await _stockage.rafraichir();
    } catch (_) {
      // Pas de widget possible (autre plateforme, image impossible) : sans
      // conséquence pour l'application.
    }
  }
}

String cleDuJour(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';
