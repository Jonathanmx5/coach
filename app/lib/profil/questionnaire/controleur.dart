import 'package:flutter/foundation.dart';

import '../garde_fous.dart';
import '../modele.dart';
import '../saisie.dart';

enum Etape {
  objectif,
  sexeAge,
  mensurations,
  typeDeVie,
  entrainements,
  niveau,
  disponibilite,
  sante,
  connexion,
}

enum Alerte { mineur, perteRefuseeImc, conseilMedecin }

enum ErreurChamp { nombreInvalide, horsPlage }

const ageMax = 100;
const tailleMin = 120, tailleMax = 230;
const poidsMin = 30, poidsMax = 300;
const joursMin = 2, joursMax = 5;
const durees = [20, 30, 45, 60];

/// État et règles du questionnaire de départ (spec §3), sans interface.
class QuestionnaireControleur extends ChangeNotifier {
  QuestionnaireControleur({
    required this.maintenant,
    required bool avecConnexion,
  }) : etapes = avecConnexion
           ? Etape.values
           : Etape.values.where((e) => e != Etape.connexion).toList();

  /// Questionnaire prérempli pour modifier un profil existant.
  factory QuestionnaireControleur.depuis(
    Profil p, {
    required DateTime maintenant,
  }) {
    return QuestionnaireControleur(maintenant: maintenant, avecConnexion: false)
      .._objectif = p.objectif
      .._sexe = p.sexe
      .._age = p.age(maintenant)
      .._tailleCm = p.tailleCm
      .._poidsKg = p.poidsKg
      .._typeDeVie = p.typeDeVie
      .._types.addAll(p.typesEntrainement)
      .._niveau = p.niveau
      .._jours = p.joursParSemaine
      .._duree = p.dureeSeanceMin
      .._sante = p.problemeSante;
  }

  final DateTime maintenant;
  final List<Etape> etapes;

  int _index = 0;
  Alerte? _alerte;

  Objectif? _objectif;
  Sexe? _sexe;
  int? _age;
  int? _tailleCm;
  double? _poidsKg;
  TypeDeVie? _typeDeVie;
  final Set<TypeEntrainement> _types = {};
  Niveau? _niveau;
  int? _jours;
  int? _duree;
  bool? _sante;

  Etape get etape => etapes[_index];
  Alerte? get alerte => _alerte;
  double get progression => (_index + 1) / etapes.length;
  bool get estDerniereEtape => _index == etapes.length - 1;

  Objectif? get objectif => _objectif;
  Sexe? get sexe => _sexe;
  int? get age => _age;
  int? get tailleCm => _tailleCm;
  double? get poidsKg => _poidsKg;
  TypeDeVie? get typeDeVie => _typeDeVie;
  Set<TypeEntrainement> get typesEntrainement => Set.unmodifiable(_types);
  Niveau? get niveau => _niveau;
  int? get joursParSemaine => _jours;
  int? get dureeSeanceMin => _duree;
  bool? get problemeSante => _sante;

  bool get peutContinuer => switch (etape) {
    Etape.objectif => _objectif != null,
    Etape.sexeAge => _sexe != null && _age != null && !estMineur(_age!),
    Etape.mensurations => _tailleCm != null && _poidsKg != null,
    Etape.typeDeVie => _typeDeVie != null,
    Etape.entrainements => _types.isNotEmpty,
    Etape.niveau => _niveau != null,
    Etape.disponibilite => _jours != null && _duree != null,
    Etape.sante => _sante != null,
    Etape.connexion => true,
  };

  void choisirObjectif(Objectif o) => _maj(() => _objectif = o);
  void choisirSexe(Sexe s) => _maj(() => _sexe = s);
  void choisirTypeDeVie(TypeDeVie t) => _maj(() => _typeDeVie = t);
  void choisirNiveau(Niveau n) => _maj(() => _niveau = n);

  void basculerEntrainement(TypeEntrainement t) =>
      _maj(() => _types.contains(t) ? _types.remove(t) : _types.add(t));

  void choisirJours(int jours) {
    if (jours < joursMin || jours > joursMax) return;
    _maj(() => _jours = jours);
  }

  void choisirDuree(int minutes) {
    if (!durees.contains(minutes)) return;
    _maj(() => _duree = minutes);
  }

  ErreurChamp? saisirAge(String saisie) {
    final v = lireNombre(saisie);
    if (v == null || v != v.roundToDouble()) {
      return _invalide(() => _age = null, ErreurChamp.nombreInvalide);
    }
    final age = v.toInt();
    if (age < 1 || age > ageMax) {
      return _invalide(() => _age = null, ErreurChamp.horsPlage);
    }
    _maj(() {
      _age = age;
      if (estMineur(age)) {
        _alerte = Alerte.mineur;
      } else if (_alerte == Alerte.mineur) {
        _alerte = null;
      }
    });
    return null;
  }

  ErreurChamp? saisirTaille(String saisie) {
    final v = lireNombre(saisie);
    if (v == null) {
      return _invalide(() => _tailleCm = null, ErreurChamp.nombreInvalide);
    }
    if (v < tailleMin || v > tailleMax) {
      return _invalide(() => _tailleCm = null, ErreurChamp.horsPlage);
    }
    _maj(() => _tailleCm = v.round());
    return null;
  }

  ErreurChamp? saisirPoids(String saisie) {
    final v = lireNombre(saisie);
    if (v == null) {
      return _invalide(() => _poidsKg = null, ErreurChamp.nombreInvalide);
    }
    if (v < poidsMin || v > poidsMax) {
      return _invalide(() => _poidsKg = null, ErreurChamp.horsPlage);
    }
    _maj(() => _poidsKg = v);
    return null;
  }

  void repondreSante(bool oui) => _maj(() {
    _sante = oui;
    if (oui) {
      if (_objectif == Objectif.perte) _objectif = Objectif.forme;
      _alerte = Alerte.conseilMedecin;
    } else if (_alerte == Alerte.conseilMedecin) {
      _alerte = null;
    }
  });

  void suivant() {
    if (!peutContinuer || estDerniereEtape) return;
    _maj(() {
      final quittee = etape;
      if (_alerte != Alerte.mineur) _alerte = null;
      if (quittee == Etape.mensurations &&
          _objectif == Objectif.perte &&
          !pertePermise(
            poidsKg: _poidsKg!,
            tailleCm: _tailleCm!,
            problemeSante: false,
          )) {
        _objectif = Objectif.forme;
        _alerte = Alerte.perteRefuseeImc;
      }
      _index++;
    });
  }

  void precedent() {
    if (_index == 0) return;
    _maj(() {
      if (_alerte != Alerte.mineur) _alerte = null;
      _index--;
    });
  }

  /// Profil final, garde-fous toujours réappliqués.
  Profil construireProfil() {
    if (_objectif == null ||
        _sexe == null ||
        _age == null ||
        estMineur(_age!) ||
        _tailleCm == null ||
        _poidsKg == null ||
        _typeDeVie == null ||
        _types.isEmpty ||
        _niveau == null ||
        _jours == null ||
        _duree == null ||
        _sante == null) {
      throw StateError('Questionnaire incomplet');
    }
    return appliquerGardeFous(
      Profil(
        objectif: _objectif!,
        sexe: _sexe!,
        anneeNaissance: maintenant.year - _age!,
        tailleCm: _tailleCm!,
        poidsKg: _poidsKg!,
        typeDeVie: _typeDeVie!,
        typesEntrainement: Set.of(_types),
        niveau: _niveau!,
        joursParSemaine: _jours!,
        dureeSeanceMin: _duree!,
        problemeSante: _sante!,
      ),
    );
  }

  ErreurChamp _invalide(VoidCallback effacer, ErreurChamp erreur) {
    _maj(effacer);
    return erreur;
  }

  void _maj(VoidCallback changement) {
    changement();
    notifyListeners();
  }
}
