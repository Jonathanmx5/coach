import 'package:flutter/foundation.dart';

import '../profil/besoins.dart';
import '../profil/modele.dart';
import 'agregation.dart';
import 'ajustements.dart' as ajustements;
import 'modele.dart';
import 'sante_service.dart';

enum EtatSuivi { inactif, chargement, pret, erreur }

/// Données Health Connect des 30 derniers jours, lues à la demande et gardées
/// en mémoire seulement (spec santé connectée §2).
class Suivi extends ChangeNotifier {
  Suivi({required this.sante, required this.horloge});

  final SanteService sante;
  final DateTime Function() horloge;

  static const joursLus = 30;

  EtatSuivi etat = EtatSuivi.inactif;
  List<JourSante> jours = const [];
  List<Mesure> pesees = const [];
  List<Mesure> masseGrasse = const [];

  /// Maintien mesuré pour [profil] (moyenne des journées complètes et
  /// vraisemblables par rapport à son métabolisme de base), ou null si
  /// insuffisant.
  double? maintienPour(Profil profil) {
    if (jours.isEmpty) return null;
    final maintenant = horloge();
    return ajustements.maintienMesure(
      jours,
      aujourdhui: maintenant,
      depenseBase: calculerReperes(profil, maintenant: maintenant).depenseBase,
    );
  }

  JourSante? get aujourdhui => jours.isEmpty ? null : jours.last;

  bool get sansDonnees => etat == EtatSuivi.pret && _points == 0;
  int _points = 0;

  Future<void> charger({required bool montre}) async {
    if (!montre) {
      _vider(EtatSuivi.inactif);
      return;
    }
    etat = EtatSuivi.chargement;
    notifyListeners();
    try {
      if (await sante.disponibilite() != DispoSante.disponible) {
        _vider(EtatSuivi.inactif);
        return;
      }
      final maintenant = horloge();
      final aujourdhui = jourDe(maintenant);
      final debut = DateTime(
        aujourdhui.year,
        aujourdhui.month,
        aujourdhui.day - joursLus,
      );
      final points = await sante.lire(debut, maintenant);
      _points = points.length;
      jours = agregerParJour(
        points,
        debut: debut,
        fin: maintenant,
        maintenant: maintenant,
      );
      pesees = mesures(points, TypeMesure.poids);
      masseGrasse = mesures(points, TypeMesure.masseGrasse);
      etat = EtatSuivi.pret;
    } catch (_) {
      _vider(EtatSuivi.erreur);
      return;
    }
    notifyListeners();
  }

  void _vider(EtatSuivi nouvelEtat) {
    etat = nouvelEtat;
    jours = const [];
    pesees = const [];
    masseGrasse = const [];
    _points = 0;
    notifyListeners();
  }
}
