// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'bienetre_repository.dart';
import 'meteo.dart';

/// Température du jour, partagée par l'Accueil et l'onglet Bien-être pour
/// que l'objectif d'eau soit le même partout. Elle n'est cherchée que si
/// l'utilisateur a activé « Adapter à la météo ».
class SuiviMeteo extends ChangeNotifier {
  SuiviMeteo({
    required Meteo meteo,
    required BienEtreRepository bienetre,
    required String uid,
  }) : _meteo = meteo {
    _abonnement = bienetre.meteoActive(uid).listen(_changement);
  }

  final Meteo _meteo;
  late final StreamSubscription<bool> _abonnement;
  bool _demandee = false;

  /// Température maximale d'aujourd'hui, ou null (désactivé, refusé, hors-ligne).
  double? temperature;

  /// Réglage « Adapter à la météo » : l'onglet Bien-être le lit ici plutôt
  /// que d'ouvrir une seconde écoute du même document.
  bool actif = false;

  void _changement(bool actif) {
    final change = actif != this.actif;
    this.actif = actif;
    if (!actif) {
      _demandee = false;
      if (temperature != null || change) {
        temperature = null;
        notifyListeners();
      }
      return;
    }
    if (change) notifyListeners();
    if (_demandee) return;
    _demandee = true;
    unawaited(_charger());
  }

  Future<void> _charger() async {
    final t = await _meteo.temperatureMax();
    temperature = t;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_abonnement.cancel());
    super.dispose();
  }
}
