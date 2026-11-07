import 'package:coach/profil/modele.dart';
import 'package:coach/profil/questionnaire/controleur.dart';
import 'package:flutter_test/flutter_test.dart';

final maintenant = DateTime(2026, 10, 9);

QuestionnaireControleur nouveau() =>
    QuestionnaireControleur(maintenant: maintenant, avecConnexion: true);

/// Remplit tout le questionnaire jusqu'à l'étape santé incluse.
void remplir(
  QuestionnaireControleur c, {
  Objectif objectif = Objectif.perte,
  String taille = '180',
  String poids = '80',
  Sexe sexe = Sexe.homme,
  Set<Precaution> precautions = const {},
}) {
  c.choisirObjectif(objectif);
  c.suivant();
  c.choisirSexe(sexe);
  c.saisirAge('30');
  c.suivant();
  c.saisirTaille(taille);
  c.saisirPoids(poids);
  c.suivant();
  c.choisirTypeDeVie(TypeDeVie.peuActif);
  c.suivant();
  c.basculerEntrainement(TypeEntrainement.salle);
  c.basculerEntrainement(TypeEntrainement.course);
  c.suivant();
  c.choisirNiveau(Niveau.debutant);
  c.suivant();
  c.choisirJours(3);
  c.choisirDuree(45);
  c.suivant();
  if (precautions.isEmpty) {
    c.repondreAucunePrecaution();
  } else {
    precautions.forEach(c.basculerPrecaution);
  }
  c.repondreMontre(false); // répondu d'avance : l'étape suivante est prête
}

final profilAttendu = Profil(
  objectif: Objectif.perte,
  sexe: Sexe.homme,
  anneeNaissance: 1996,
  tailleCm: 180,
  poidsKg: 80,
  typeDeVie: TypeDeVie.peuActif,
  typesEntrainement: {TypeEntrainement.salle, TypeEntrainement.course},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 45,
  poidsDate: maintenant,
);

void main() {
  test('parcours complet : profil construit', () {
    final c = nouveau();
    remplir(c);
    expect(c.peutContinuer, isTrue);
    c.suivant();
    expect(c.etape, Etape.montre);
    c.suivant();
    expect(c.etape, Etape.resultat);
    expect(c.peutContinuer, isTrue);
    c.suivant();
    expect(c.etape, Etape.connexion);
    expect(c.construireProfil(), profilAttendu);
  });

  test('poids avec virgule accepté', () {
    final c = nouveau();
    expect(c.saisirPoids('72,5'), isNull);
    remplir(c, poids: '72,5');
    expect(c.construireProfil().poidsKg, 72.5);
  });

  test('17 ans : alerte mineur et blocage', () {
    final c = nouveau()
      ..choisirObjectif(Objectif.forme)
      ..suivant()
      ..choisirSexe(Sexe.femme);
    expect(c.saisirAge('17'), isNull);
    expect(c.alerte, Alerte.mineur);
    expect(c.peutContinuer, isFalse);
    c.suivant();
    expect(c.etape, Etape.sexeAge);
  });

  test('âge corrigé à 18 : alerte levée', () {
    final c = nouveau()
      ..choisirObjectif(Objectif.forme)
      ..suivant()
      ..choisirSexe(Sexe.femme)
      ..saisirAge('17')
      ..saisirAge('18');
    expect(c.alerte, isNull);
    expect(c.peutContinuer, isTrue);
  });

  test('âge 101 hors plage, taille non numérique invalide', () {
    final c = nouveau();
    expect(c.saisirAge('101'), ErreurChamp.horsPlage);
    expect(c.saisirTaille('abc'), ErreurChamp.nombreInvalide);
    expect(c.saisirPoids('25'), ErreurChamp.horsPlage);
  });

  test('entraînements : au moins un choix, second tap retire', () {
    final c = nouveau();
    remplir(c);
    while (c.etape != Etape.entrainements) {
      c.precedent();
    }
    c.basculerEntrainement(TypeEntrainement.salle);
    c.basculerEntrainement(TypeEntrainement.course);
    expect(c.peutContinuer, isFalse);
    c.basculerEntrainement(TypeEntrainement.marche);
    expect(c.peutContinuer, isTrue);
  });

  test('perte avec IMC bas : passe à forme avec alerte', () {
    final c = nouveau()
      ..choisirObjectif(Objectif.perte)
      ..suivant()
      ..choisirSexe(Sexe.femme)
      ..saisirAge('30')
      ..suivant()
      ..saisirTaille('170')
      ..saisirPoids('50')
      ..suivant();
    expect(c.etape, Etape.typeDeVie);
    expect(c.alerte, Alerte.perteRefuseeImc);
    c.suivant(); // ne peut pas avancer mais l'alerte n'est pas en jeu ici
    c.choisirTypeDeVie(TypeDeVie.actif);
    c.suivant();
    expect(c.alerte, isNull);
  });

  test('enceinte ou allaitante : objectif forme avec message', () {
    final c = nouveau();
    remplir(
      c,
      sexe: Sexe.femme,
      precautions: {Precaution.enceinteOuAllaitante},
    );
    expect(c.alerte, Alerte.perteRefuseeGrossesse);
    final p = c.construireProfil();
    expect(p.objectif, Objectif.forme);
    expect(p.precautions, {Precaution.enceinteOuAllaitante});
    expect(p.santeAPreciser, isFalse);
    // Décochée : le message disparaît (l'objectif reste forme).
    c.basculerPrecaution(Precaution.enceinteOuAllaitante);
    expect(c.alerte, isNull);
    expect(c.aucunePrecaution, isTrue);
  });

  test('perte suivie par un médecin et douleurs : perte gardée', () {
    final c = nouveau();
    remplir(
      c,
      precautions: {
        Precaution.perteSuivieMedecin,
        Precaution.douleursArticulaires,
      },
    );
    expect(c.alerte, isNull);
    final p = c.construireProfil();
    expect(p.objectif, Objectif.perte);
    expect(p.precautions, {
      Precaution.perteSuivieMedecin,
      Precaution.douleursArticulaires,
    });
    expect(p.sansImpact, isTrue);
  });

  test('étape santé : une réponse est exigée, « aucun » décoche tout', () {
    final vierge = nouveau();
    expect(vierge.aucunePrecaution, isFalse);
    final c = nouveau();
    remplir(c);
    c.basculerPrecaution(Precaution.douleursArticulaires);
    expect(c.aucunePrecaution, isFalse);
    expect(c.peutContinuer, isTrue);
    c.repondreAucunePrecaution();
    expect(c.precautions, isEmpty);
    expect(c.aucunePrecaution, isTrue);
  });

  test('« enceinte » proposé aux femmes seulement', () {
    final c = nouveau()..choisirSexe(Sexe.femme);
    expect(c.precautionsProposees, contains(Precaution.enceinteOuAllaitante));
    c.basculerPrecaution(Precaution.enceinteOuAllaitante);
    c.choisirSexe(Sexe.homme);
    expect(
      c.precautionsProposees,
      isNot(contains(Precaution.enceinteOuAllaitante)),
    );
    expect(c.precautions, isEmpty);
  });

  test('ancienne réponse santé : à préciser avant de continuer', () {
    final ancien = profilAttendu.copyWith(
      objectif: Objectif.forme,
      santeAPreciser: true,
    );
    final c = QuestionnaireControleur.depuis(ancien, maintenant: maintenant);
    expect(c.santeAPreciser, isTrue);
    while (c.etape != Etape.sante) {
      c.suivant();
    }
    expect(c.peutContinuer, isFalse);
    expect(c.construireProfil, throwsStateError);
    c.basculerPrecaution(Precaution.douleursArticulaires);
    expect(c.santeAPreciser, isFalse);
    expect(c.peutContinuer, isTrue);
    final p = c.construireProfil();
    expect(p.santeAPreciser, isFalse);
    expect(p.precautions, {Precaution.douleursArticulaires});
  });

  test('garde-fou non contournable en revenant choisir perte', () {
    final c = nouveau();
    remplir(
      c,
      objectif: Objectif.forme,
      sexe: Sexe.femme,
      precautions: {Precaution.enceinteOuAllaitante},
    );
    while (c.etape != Etape.objectif) {
      c.precedent();
    }
    c.choisirObjectif(Objectif.perte);
    while (c.etape != Etape.sante) {
      c.suivant();
    }
    c.suivant();
    expect(c.construireProfil().objectif, Objectif.forme);
  });

  test('retour en arrière conserve les réponses', () {
    final c = nouveau();
    remplir(c);
    while (c.etape != Etape.objectif) {
      c.precedent();
    }
    expect(c.construireProfil(), profilAttendu);
  });

  test('profil incomplet : construireProfil lève une erreur', () {
    expect(() => nouveau().construireProfil(), throwsStateError);
  });

  test('depuis(profil) : prérempli et sans étape connexion', () {
    final c = QuestionnaireControleur.depuis(
      profilAttendu,
      maintenant: maintenant,
    );
    expect(c.etapes, isNot(contains(Etape.connexion)));
    expect(c.etapes.last, Etape.resultat);
    expect(c.construireProfil(), profilAttendu);
  });

  test('progression de 1/11 à 11/11 sans montre', () {
    final c = nouveau();
    expect(c.progression, closeTo(1 / 11, 1e-9));
    remplir(c);
    c.suivant();
    c.suivant();
    c.suivant();
    expect(c.progression, 1.0);
  });

  test('montre oui : étape application ajoutée et exigée', () {
    final c = nouveau();
    remplir(c);
    c.repondreMontre(true);
    expect(c.etapes, contains(Etape.appMontre));
    expect(c.etapes.length, 12);
    c.suivant();
    c.suivant();
    expect(c.etape, Etape.appMontre);
    expect(c.peutContinuer, isFalse);
    c.choisirAppMontre(AppMontre.miFitness);
    expect(c.peutContinuer, isTrue);
    final p = c.construireProfil();
    expect(p.montre, isTrue);
    expect(p.appMontre, AppMontre.miFitness);
  });

  test('montre non après un choix : application effacée', () {
    final c = nouveau();
    remplir(c);
    c
      ..repondreMontre(true)
      ..choisirAppMontre(AppMontre.fitbit)
      ..repondreMontre(false);
    expect(c.etapes, isNot(contains(Etape.appMontre)));
    expect(c.construireProfil().appMontre, isNull);
  });

  test('montre oui sans application : profil incomplet', () {
    final c = nouveau();
    remplir(c);
    c.repondreMontre(true);
    expect(c.construireProfil, throwsStateError);
  });

  test('date de pesée : conservée si le poids ne change pas', () {
    final ancien = profilAttendu.copyWith(poidsDate: DateTime(2026, 9, 1));
    final c = QuestionnaireControleur.depuis(ancien, maintenant: maintenant);
    expect(c.construireProfil().poidsDate, DateTime(2026, 9, 1));
    c.saisirPoids('79');
    expect(c.construireProfil().poidsDate, maintenant);
  });

  test('type de vie : le plancher au-dessus du maintien refuse la perte', () {
    // Femme de 60 ans, 150 cm, 45 kg (IMC 20), sédentaire : maintien 1112
    // kcal, sous le plancher de 1200.
    final c = nouveau()
      ..choisirObjectif(Objectif.perte)
      ..suivant()
      ..choisirSexe(Sexe.femme)
      ..saisirAge('60')
      ..suivant()
      ..saisirTaille('150')
      ..saisirPoids('45')
      ..suivant();
    expect(c.alerte, isNull);
    c
      ..choisirTypeDeVie(TypeDeVie.sedentaire)
      ..suivant();
    expect(c.alerte, Alerte.perteRefuseePlancher);
    expect(c.objectif, Objectif.forme);
  });

  test('muscle avec un IMC de 27 ou plus : recomposition annoncée', () {
    final c = nouveau()
      ..choisirObjectif(Objectif.muscle)
      ..suivant()
      ..choisirSexe(Sexe.homme)
      ..saisirAge('30')
      ..suivant()
      ..saisirTaille('175')
      ..saisirPoids('120')
      ..suivant();
    expect(c.alerte, Alerte.recomposition);
    expect(c.objectif, Objectif.muscle);
  });

  group('poids visé', () {
    test('facultatif, demandé pour la perte et le muscle', () {
      final c = nouveau()..choisirObjectif(Objectif.forme);
      expect(c.demandePoidsCible, isFalse);
      c.choisirObjectif(Objectif.perte);
      expect(c.demandePoidsCible, isTrue);
      expect(c.saisirPoidsCible(''), isNull);
      expect(c.poidsCibleKg, isNull);
    });

    test('enregistré dans le profil', () {
      final c = nouveau()..saisirTaille('180');
      expect(c.saisirPoidsCible('72,5'), isNull);
      remplir(c);
      expect(c.construireProfil().poidsCibleKg, 72.5);
    });

    test('trop bas pour la taille ou hors plage : refusé et bloquant', () {
      final c = nouveau();
      remplir(c);
      while (c.etape != Etape.mensurations) {
        c.precedent();
      }
      expect(c.saisirPoidsCible('55'), ErreurChamp.cibleTropBasse);
      expect(c.peutContinuer, isFalse);
      expect(c.saisirPoidsCible('20'), ErreurChamp.horsPlage);
      expect(c.saisirPoidsCible('abc'), ErreurChamp.nombreInvalide);
      expect(c.saisirPoidsCible(''), isNull);
      expect(c.peutContinuer, isTrue);
    });

    test("oublié si l'objectif ne s'y prête pas", () {
      final c = nouveau()..saisirTaille('180');
      c.saisirPoidsCible('72');
      remplir(c, objectif: Objectif.forme);
      expect(c.construireProfil().poidsCibleKg, isNull);
    });
  });
}
