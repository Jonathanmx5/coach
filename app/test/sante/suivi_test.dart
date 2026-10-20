import 'package:coach/profil/besoins.dart';
import 'package:coach/sante/modele.dart';
import 'package:coach/sante/sante_service.dart';
import 'package:coach/sante/suivi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../donnees_sante.dart';
import '../fakes.dart';
import '../racine_test.dart' show perteSimple;

final maintenant = DateTime(2026, 10, 9, 20);
const profilMontre = perteSimple;

/// Health Connect qui compte ses lectures et peut échouer à la demande.
class SanteInstable extends FauxSante {
  SanteInstable({super.points});

  bool echoue = false;
  int lectures = 0;
  Set<TypeMesure>? derniersTypes;

  @override
  Future<List<PointSante>> lire(
    DateTime debut,
    DateTime fin, {
    Set<TypeMesure>? types,
  }) async {
    lectures++;
    derniersTypes = types;
    if (echoue) throw Exception('lecture impossible');
    return super.lire(debut, fin, types: types);
  }
}

void main() {
  test('sans montre : inactif, rien lu', () async {
    final sante = FauxSante(points: semaineType());
    final suivi = Suivi(sante: sante, horloge: () => maintenant);

    await suivi.charger(montre: false);

    expect(suivi.etat, EtatSuivi.inactif);
    expect(suivi.maintienPour(profilMontre), isNull);
  });

  test('avec montre : journée, maintien mesuré et pesées', () async {
    final suivi = Suivi(
      sante: FauxSante(points: semaineType()),
      horloge: () => maintenant,
    );

    await suivi.charger(montre: true);

    expect(suivi.etat, EtatSuivi.pret);
    expect(suivi.aujourdhui?.pas, 6500);
    expect(suivi.aujourdhui?.sommeil?.endormi, const Duration(hours: 7));
    expect(suivi.maintienPour(profilMontre), 2600);
    expect(suivi.pesees.single.valeur, 79.5);
    expect(suivi.jours.length, 31);
  });

  test(
    'ne lit que les mesures utilisées, session de sommeil comprise',
    () async {
      final sante = SanteInstable(points: semaineType());
      final suivi = Suivi(sante: sante, horloge: () => maintenant);

      await suivi.charger(montre: true);

      expect(sante.derniersTypes, Suivi.typesLus);
      expect(sante.derniersTypes, contains(TypeMesure.sommeilSession));
    },
  );

  test('repères du jour : avec le maintien mesuré', () async {
    final suivi = Suivi(
      sante: FauxSante(points: semaineType()),
      horloge: () => maintenant,
    );
    await suivi.charger(montre: true);

    final reperes = suivi.reperesDuJour(profilMontre);

    expect(reperes.source, SourceMaintien.mesure);
    expect(reperes.maintien, 2600);
    expect(
      reperes.kcalCible,
      calculerReperes(
        profilMontre,
        maintenant: maintenant,
        maintienMesure: 2600,
      ).kcalCible,
    );
  });

  test(
    'une lecture qui échoue après un succès garde les jours et le maintien',
    () async {
      final sante = SanteInstable(points: semaineType());
      final suivi = Suivi(sante: sante, horloge: () => maintenant);
      await suivi.charger(montre: true);
      final jours = suivi.jours;

      sante.echoue = true;
      await suivi.charger(montre: true);

      expect(suivi.jours, same(jours));
      expect(suivi.maintienPour(profilMontre), 2600);
      expect(suivi.aujourdhui?.pas, 6500);
      expect(suivi.etat, EtatSuivi.pret);
      expect(suivi.erreurLecture, isTrue);

      sante.echoue = false;
      await suivi.charger(montre: true);
      expect(suivi.erreurLecture, isFalse);
    },
  );

  test('première lecture en échec : erreur affichée', () async {
    final sante = SanteInstable(points: semaineType())..echoue = true;
    final suivi = Suivi(sante: sante, horloge: () => maintenant);

    await suivi.charger(montre: true);

    expect(suivi.etat, EtatSuivi.erreur);
    expect(suivi.jours, isEmpty);
  });

  test(
    'après minuit sans rechargement : pas de journée, pas la veille',
    () async {
      var heure = maintenant;
      final suivi = Suivi(
        sante: FauxSante(points: semaineType()),
        horloge: () => heure,
      );
      await suivi.charger(montre: true);
      expect(suivi.aujourdhui?.jour, DateTime(2026, 10, 9));

      heure = DateTime(2026, 10, 10, 0, 5);

      expect(suivi.aujourdhui, isNull);
    },
  );

  test('rechargerSiNecessaire : après 10 min ou un autre jour', () async {
    var heure = maintenant;
    final sante = SanteInstable(points: semaineType());
    final suivi = Suivi(sante: sante, horloge: () => heure);

    // Jamais chargé : rien à recharger.
    await suivi.rechargerSiNecessaire();
    expect(sante.lectures, 0);

    await suivi.charger(montre: true);
    expect(sante.lectures, 1);

    heure = maintenant.add(const Duration(minutes: 5));
    await suivi.rechargerSiNecessaire();
    expect(sante.lectures, 1);

    heure = maintenant.add(const Duration(minutes: 11));
    await suivi.rechargerSiNecessaire();
    expect(sante.lectures, 2);

    // 23:59 puis 00:01 : un autre jour, même à 2 min d'écart.
    heure = DateTime(2026, 10, 9, 23, 59);
    await suivi.charger(montre: true);
    heure = DateTime(2026, 10, 10, 0, 1);
    await suivi.rechargerSiNecessaire();
    expect(sante.lectures, 4);
    expect(suivi.aujourdhui?.jour, DateTime(2026, 10, 10));
  });

  test('rechargerSiNecessaire sans montre : rien lu', () async {
    var heure = maintenant;
    final sante = SanteInstable(points: semaineType());
    final suivi = Suivi(sante: sante, horloge: () => heure);
    await suivi.charger(montre: false);

    heure = maintenant.add(const Duration(hours: 1));
    await suivi.rechargerSiNecessaire();

    expect(sante.lectures, 0);
    expect(suivi.etat, EtatSuivi.inactif);
  });

  test(
    'relecture : les données restent affichées pendant la lecture',
    () async {
      final sante = SanteInstable(points: semaineType());
      final suivi = Suivi(sante: sante, horloge: () => maintenant);
      await suivi.charger(montre: true);

      final etats = <EtatSuivi>[];
      suivi.addListener(() => etats.add(suivi.etat));
      await suivi.charger(montre: true);

      expect(etats, isNot(contains(EtatSuivi.chargement)));
      expect(suivi.etat, EtatSuivi.pret);
    },
  );

  test('Health Connect indisponible : inactif', () async {
    final suivi = Suivi(
      sante: FauxSante(dispo: DispoSante.indisponible, points: semaineType()),
      horloge: () => maintenant,
    );

    await suivi.charger(montre: true);

    expect(suivi.etat, EtatSuivi.inactif);
  });

  test('aucune donnée lue : sansDonnees vrai', () async {
    final suivi = Suivi(sante: FauxSante(), horloge: () => maintenant);

    await suivi.charger(montre: true);

    expect(suivi.etat, EtatSuivi.pret);
    expect(suivi.sansDonnees, isTrue);
  });
}
