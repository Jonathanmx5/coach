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

  /// Au-delà, les données sont rechargées à la reprise de l'appli.
  static const fraicheur = Duration(minutes: 10);

  /// Les mesures réellement utilisées par l'appli, et elles seules.
  static const typesLus = {
    TypeMesure.pas,
    TypeMesure.distance,
    TypeMesure.etages,
    TypeMesure.kcalActives,
    TypeMesure.kcalTotales,
    TypeMesure.fcRepos,
    TypeMesure.variabilite,
    TypeMesure.spo2,
    TypeMesure.freqResp,
    TypeMesure.poids,
    TypeMesure.masseGrasse,
    TypeMesure.sommeilProfond,
    TypeMesure.sommeilLeger,
    TypeMesure.sommeilParadoxal,
    TypeMesure.sommeilEveil,
    TypeMesure.sommeilEndormi,
    TypeMesure.sommeilSession,
    TypeMesure.seance,
  };

  EtatSuivi etat = EtatSuivi.inactif;
  List<JourSante> jours = const [];
  List<Mesure> pesees = const [];
  List<Mesure> masseGrasse = const [];

  /// Vrai si la dernière lecture a échoué alors que des données déjà lues
  /// restent affichées (spec santé connectée §6 : message discret).
  bool erreurLecture = false;

  bool? _montre;
  DateTime? _dernierChargement;
  Future<void>? _enCours;

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

  /// Repères du jour pour [profil], avec le maintien mesuré s'il existe : la
  /// même cible pour tous les écrans (journal, accueil, idées, planning).
  Reperes reperesDuJour(Profil profil) => calculerReperes(
    profil,
    maintenant: horloge(),
    maintienMesure: maintienPour(profil),
  );

  /// Le jour en cours, s'il a été lu ; jamais la veille après minuit.
  JourSante? get aujourdhui {
    final jour = jourDe(horloge());
    return jours.where((j) => j.jour == jour).firstOrNull;
  }

  bool get sansDonnees => etat == EtatSuivi.pret && _points == 0;
  int _points = 0;

  /// Relit les données si le dernier chargement date de plus de [fraicheur]
  /// ou d'un autre jour (à la reprise de l'appli).
  Future<void> rechargerSiNecessaire() async {
    final montre = _montre;
    final dernier = _dernierChargement;
    if (montre == null || dernier == null) return;
    final maintenant = horloge();
    if (maintenant.difference(dernier) < fraicheur &&
        jourDe(maintenant) == jourDe(dernier)) {
      return;
    }
    await charger(montre: montre);
  }

  Future<void> charger({required bool montre}) {
    _montre = montre;
    if (!montre) {
      _dernierChargement = horloge();
      _vider(EtatSuivi.inactif);
      return Future.value();
    }
    return _enCours ??= _lire().whenComplete(() => _enCours = null);
  }

  Future<void> _lire() async {
    // Les données déjà lues restent affichées pendant la relecture.
    if (jours.isEmpty) {
      etat = EtatSuivi.chargement;
      notifyListeners();
    }
    final maintenant = horloge();
    _dernierChargement = maintenant;
    try {
      if (await sante.disponibilite() != DispoSante.disponible) {
        _vider(EtatSuivi.inactif);
        return;
      }
      final aujourdhui = jourDe(maintenant);
      final debut = DateTime(
        aujourdhui.year,
        aujourdhui.month,
        aujourdhui.day - joursLus,
      );
      final points = await sante.lire(debut, maintenant, types: typesLus);
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
      erreurLecture = false;
    } catch (_) {
      // Les données déjà lues restent affichées ; sans elles, l'erreur est
      // montrée (souvent un accès retiré).
      if (jours.isEmpty) {
        etat = EtatSuivi.erreur;
      } else {
        etat = EtatSuivi.pret;
        erreurLecture = true;
      }
    }
    notifyListeners();
  }

  void _vider(EtatSuivi nouvelEtat) {
    etat = nouvelEtat;
    jours = const [];
    pesees = const [];
    masseGrasse = const [];
    erreurLecture = false;
    _points = 0;
    notifyListeners();
  }
}
