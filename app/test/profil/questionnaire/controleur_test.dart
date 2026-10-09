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
  bool sante = false,
}) {
  c.choisirObjectif(objectif);
  c.suivant();
  c.choisirSexe(Sexe.homme);
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
  c.repondreSante(sante);
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
  problemeSante: false,
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

  test('santé oui : conseil médecin et objectif forme', () {
    final c = nouveau();
    remplir(c, sante: true);
    expect(c.alerte, Alerte.conseilMedecin);
    expect(c.construireProfil().objectif, Objectif.forme);
    expect(c.construireProfil().problemeSante, isTrue);
  });

  test('garde-fou non contournable en revenant choisir perte', () {
    final c = nouveau();
    remplir(c, objectif: Objectif.forme, sante: true);
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
    expect(c.etapes.last, Etape.montre);
    expect(c.construireProfil(), profilAttendu);
  });

  test('progression de 1/10 à 10/10 sans montre', () {
    final c = nouveau();
    expect(c.progression, closeTo(1 / 10, 1e-9));
    remplir(c);
    c.suivant();
    c.suivant();
    expect(c.progression, 1.0);
  });

  test('montre oui : étape application ajoutée et exigée', () {
    final c = nouveau();
    remplir(c);
    c.repondreMontre(true);
    expect(c.etapes, contains(Etape.appMontre));
    expect(c.etapes.length, 11);
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
}
