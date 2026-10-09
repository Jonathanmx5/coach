import 'package:coach/sante/sante_service.dart';
import 'package:coach/sante/suivi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../donnees_sante.dart';
import '../fakes.dart';

final maintenant = DateTime(2026, 10, 9, 20);

void main() {
  test('sans montre : inactif, rien lu', () async {
    final sante = FauxSante(points: semaineType());
    final suivi = Suivi(sante: sante, horloge: () => maintenant);

    await suivi.charger(montre: false);

    expect(suivi.etat, EtatSuivi.inactif);
    expect(suivi.maintien, isNull);
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
    expect(suivi.maintien, 2600);
    expect(suivi.pesees.single.valeur, 79.5);
    expect(suivi.jours.length, 31);
  });

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
