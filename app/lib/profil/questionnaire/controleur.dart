import 'package:flutter/foundation.dart';

import '../besoins.dart';
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
  montre,
  appMontre,
  resultat,
  connexion,
}

enum Alerte {
  mineur,
  perteRefuseeImc,

  /// Plancher calorique au-dessus du maintien : pas de déficit possible.
  perteRefuseePlancher,

  /// Grossesse ou allaitement : pas d'objectif de perte.
  perteRefuseeGrossesse,

  /// Objectif muscle avec un IMC de 27 ou plus : recomposition proposée.
  recomposition,
}

enum ErreurChamp { nombreInvalide, horsPlage, cibleTropBasse }

const ageMax = 100;
const tailleMin = 120, tailleMax = 230;
const poidsMin = 30, poidsMax = 300;
const joursMin = 2, joursMax = 5;
const durees = [20, 30, 45, 60];

/// État et règles du questionnaire de départ (spec §3), sans interface.
class QuestionnaireControleur extends ChangeNotifier {
  QuestionnaireControleur({
    required this.maintenant,
    required this.avecConnexion,
  });

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
      .._precautions.addAll(p.precautions)
      // Ancienne réponse « problème de santé » : à préciser.
      .._santeRepondue = !p.santeAPreciser
      .._santeAPreciser = p.santeAPreciser
      .._poidsCible = p.poidsCibleKg
      .._montre = p.montre
      .._appMontre = p.appMontre
      .._profilOrigine = p;
  }

  final DateTime maintenant;
  final bool avecConnexion;

  /// Profil modifié (mode édition) : sert à conserver la date de pesée.
  Profil? _profilOrigine;

  /// Étapes réelles : l'application de la montre seulement si elle existe.
  List<Etape> get etapes => [
    for (final e in Etape.values)
      if ((e != Etape.appMontre || _montre == true) &&
          (e != Etape.connexion || avecConnexion))
        e,
  ];

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
  final Set<Precaution> _precautions = {};
  bool _santeRepondue = false;
  bool _santeAPreciser = false;
  double? _poidsCible;
  bool _cibleErronee = false;
  bool? _montre;
  AppMontre? _appMontre;

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
  Set<Precaution> get precautions => Set.unmodifiable(_precautions);

  /// « Aucun de ces cas » choisi explicitement.
  bool get aucunePrecaution => _santeRepondue && _precautions.isEmpty;

  /// Profil modifié dont la réponse santé date de l'ancienne question.
  bool get santeAPreciser => _santeAPreciser;
  double? get poidsCibleKg => _poidsCible;

  /// Le poids visé n'a de sens que pour perdre du poids ou prendre du muscle.
  bool get demandePoidsCible =>
      _objectif == Objectif.perte || _objectif == Objectif.muscle;

  /// « Enceinte ou allaitante » n'est proposé qu'aux femmes.
  List<Precaution> get precautionsProposees => [
    for (final p in Precaution.values)
      if (p != Precaution.enceinteOuAllaitante || _sexe != Sexe.homme) p,
  ];
  bool? get montre => _montre;
  AppMontre? get appMontre => _appMontre;

  bool get peutContinuer => switch (etape) {
    Etape.objectif => _objectif != null,
    Etape.sexeAge => _sexe != null && _age != null && !estMineur(_age!),
    Etape.mensurations =>
      _tailleCm != null && _poidsKg != null && !_cibleErronee,
    Etape.typeDeVie => _typeDeVie != null,
    Etape.entrainements => _types.isNotEmpty,
    Etape.niveau => _niveau != null,
    Etape.disponibilite => _jours != null && _duree != null,
    Etape.sante => _santeRepondue,
    Etape.montre => _montre != null,
    Etape.appMontre => _appMontre != null,
    Etape.resultat || Etape.connexion => true,
  };

  void choisirObjectif(Objectif o) => _maj(() => _objectif = o);
  void choisirSexe(Sexe s) => _maj(() {
    _sexe = s;
    if (s == Sexe.homme &&
        _precautions.remove(Precaution.enceinteOuAllaitante) &&
        _alerte == Alerte.perteRefuseeGrossesse) {
      _alerte = null;
    }
  });
  void choisirTypeDeVie(TypeDeVie t) => _maj(() => _typeDeVie = t);
  void choisirNiveau(Niveau n) => _maj(() => _niveau = n);
  void choisirAppMontre(AppMontre a) => _maj(() => _appMontre = a);

  void repondreMontre(bool oui) => _maj(() {
    _montre = oui;
    if (!oui) _appMontre = null;
  });

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

  /// Poids visé, facultatif : vide pour s'en passer.
  ErreurChamp? saisirPoidsCible(String saisie) {
    if (saisie.trim().isEmpty) {
      _maj(() {
        _poidsCible = null;
        _cibleErronee = false;
      });
      return null;
    }
    final v = lireNombre(saisie);
    final ErreurChamp? erreur;
    if (v == null) {
      erreur = ErreurChamp.nombreInvalide;
    } else if (v < poidsMin || v > poidsMax) {
      erreur = ErreurChamp.horsPlage;
    } else if (_tailleCm != null && imc(v, _tailleCm!) < imcMinimumPerte) {
      erreur = ErreurChamp.cibleTropBasse;
    } else {
      erreur = null;
    }
    _maj(() {
      _poidsCible = erreur == null ? v : null;
      _cibleErronee = erreur != null;
    });
    return erreur;
  }

  /// Coche ou décoche une précaution de l'étape santé.
  void basculerPrecaution(Precaution p) => _maj(() {
    _santeRepondue = true;
    _santeAPreciser = false;
    if (!_precautions.remove(p)) _precautions.add(p);
    if (_precautions.contains(Precaution.enceinteOuAllaitante)) {
      if (_objectif == Objectif.perte) {
        _objectif = Objectif.forme;
        _alerte = Alerte.perteRefuseeGrossesse;
      }
    } else if (_alerte == Alerte.perteRefuseeGrossesse) {
      _alerte = null;
    }
  });

  /// « Aucun de ces cas » : décoche tout.
  void repondreAucunePrecaution() => _maj(() {
    _santeRepondue = true;
    _santeAPreciser = false;
    _precautions.clear();
    if (_alerte == Alerte.perteRefuseeGrossesse) _alerte = null;
  });

  void suivant() {
    if (!peutContinuer || estDerniereEtape) return;
    _maj(() {
      final quittee = etape;
      if (_alerte != Alerte.mineur) _alerte = null;
      if (quittee == Etape.mensurations) {
        final indice = imc(_poidsKg!, _tailleCm!);
        if (_objectif == Objectif.perte && indice < imcMinimumPerte) {
          _objectif = Objectif.forme;
          _alerte = Alerte.perteRefuseeImc;
        } else if (_objectif == Objectif.muscle && indice >= imcRecomposition) {
          _alerte = Alerte.recomposition;
        }
      }
      if (quittee == Etape.typeDeVie &&
          _objectif == Objectif.perte &&
          plancherAuDessusDuMaintien(
            sexe: _sexe!,
            age: _age!,
            tailleCm: _tailleCm!,
            poidsKg: _poidsKg!,
            typeDeVie: _typeDeVie!,
          )) {
        _objectif = Objectif.forme;
        _alerte = Alerte.perteRefuseePlancher;
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
        !_santeRepondue ||
        _montre == null ||
        (_montre! && _appMontre == null)) {
      throw StateError('Questionnaire incomplet');
    }
    final origine = _profilOrigine;
    final poidsInchange = origine != null && origine.poidsKg == _poidsKg;
    final cible = _poidsCible;
    final cibleRetenue =
        demandePoidsCible &&
        cible != null &&
        imc(cible, _tailleCm!) >= imcMinimumPerte;
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
        precautions: {
          for (final p in _precautions)
            if (precautionsProposees.contains(p)) p,
        },
        santeAPreciser: _santeAPreciser,
        poidsCibleKg: cibleRetenue ? cible : null,
        montre: _montre!,
        appMontre: _appMontre,
        poidsDate: poidsInchange ? origine.poidsDate : maintenant,
      ),
      maintenant: maintenant,
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
