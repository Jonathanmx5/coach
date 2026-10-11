import 'package:coach/bienetre/complements.dart';
import 'package:flutter/material.dart';
import 'package:coach/app.dart';
import 'package:coach/bienetre/bienetre_page.dart';
import 'package:coach/bienetre/hydratation.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import '../parcours.dart';

final maintenant = DateTime(2026, 10, 9, 20);
const lea = Utilisateur(uid: 'u1', prenom: 'Léa');

final profil = Profil(
  objectif: Objectif.forme,
  sexe: Sexe.femme,
  anneeNaissance: 1996,
  tailleCm: 170,
  poidsKg: 60,
  typeDeVie: TypeDeVie.actif,
  typesEntrainement: const {TypeEntrainement.maison},
  niveau: Niveau.debutant,
  joursParSemaine: 3,
  dureeSeanceMin: 30,
  problemeSante: false,
);

class Banc {
  final bienetre = FauxBienEtre();
  final journal = FauxJournal();
  final meteo = FausseMeteo(31);
  final rappels = FauxRappels();

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      CoachApp(
        accueil: BienEtrePage(
          utilisateur: lea,
          enregistre: ProfilEnregistre(
            profil: profil,
            reperes: calculerReperes(profil, maintenant: maintenant),
          ),
          bienetre: bienetre,
          journal: journal,
          meteo: meteo,
          rappels: rappels,
          horloge: () => maintenant,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  group('objectifEauMl', () {
    test('selon le poids, arrondi à 50 ml', () {
      expect(objectifEauMl(poidsKg: 60), 2000);
      expect(objectifEauMl(poidsKg: 71), 2350);
    });
    test('effort et chaleur', () {
      expect(objectifEauMl(poidsKg: 60, minutesEffort: 30), 2300);
      expect(objectifEauMl(poidsKg: 60, tempMaxC: 26), 2400);
      expect(objectifEauMl(poidsKg: 60, tempMaxC: 31), 2750);
      expect(objectifEauMl(poidsKg: 60, tempMaxC: 20), 2000);
    });
    test('bornes 1,5 L et 4,5 L', () {
      expect(objectifEauMl(poidsKg: 35), 1500);
      expect(
        objectifEauMl(poidsKg: 120, minutesEffort: 120, tempMaxC: 35),
        4500,
      );
    });
    test('total', () {
      expect(
        totalEauMl([
          EntreeEau(date: maintenant, ml: 250),
          EntreeEau(date: maintenant, ml: 500),
        ]),
        750,
      );
    });
  });

  testWidgets('hydratation : objectif du profil, ajout et annulation', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);
    expect(find.text('0,00 L sur 2,00 L'), findsOneWidget);

    await taper(tester, '+ 250 ml');
    await taper(tester, '+ 500 ml');
    expect(find.text('0,75 L sur 2,00 L'), findsOneWidget);
    expect(banc.bienetre.eauDe('u1'), hasLength(2));

    await taper(tester, 'Annuler le dernier');
    expect(find.text('0,25 L sur 2,00 L'), findsOneWidget);
  });

  testWidgets('hydratation : l\'effort du jour augmente l\'objectif', (
    tester,
  ) async {
    final banc = Banc();
    banc.journal.activitesParUid['u1'] = [
      Activite(
        date: maintenant,
        type: TypeActivite.course,
        minutes: 30,
        intensite: Intensite.moderee,
        kcal: 300,
      ),
    ];
    await banc.monter(tester);
    expect(find.text('0,00 L sur 2,30 L'), findsOneWidget);
    expect(find.textContaining('30 min d\'effort'), findsOneWidget);
  });

  testWidgets('météo : activée à la demande, objectif relevé', (tester) async {
    final banc = Banc();
    await banc.monter(tester);
    expect(banc.meteo.appels, 0);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(banc.bienetre.meteo['u1'], isTrue);
    expect(banc.meteo.appels, 1);
    expect(find.text('0,00 L sur 2,75 L'), findsOneWidget);
    expect(find.textContaining('31 °C'), findsOneWidget);
  });

  testWidgets('météo refusée : objectif inchangé', (tester) async {
    final banc = Banc();
    banc.meteo.temp = null;
    banc.bienetre.meteo['u1'] = true;
    await banc.monter(tester);
    expect(find.text('0,00 L sur 2,00 L'), findsOneWidget);
  });

  testWidgets('compléments : ajout, rappel planifié, pris, désactivation', (
    tester,
  ) async {
    final banc = Banc();
    await banc.monter(tester);

    await taper(tester, 'Ajouter un complément');
    await tester.enterText(find.byType(TextField), 'Vitamine D');
    await tester.pump();
    await taper(tester, 'Enregistrer');

    final c = banc.bienetre.complementsDe('u1').single;
    expect(c.nom, 'Vitamine D');
    expect(c.minutes, 480);
    expect(banc.rappels.autorisations, 1);
    expect(banc.rappels.planifications.last.single.nom, 'Vitamine D');
    expect(find.text('Rappel à 08h00'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(banc.bienetre.prisesDe('u1', maintenant), {c.id});

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Désactiver le rappel'));
    await tester.pumpAndSettle();
    expect(banc.bienetre.complementsDe('u1').single.actif, isFalse);
    expect(banc.rappels.planifications.last.single.actif, isFalse);
    expect(find.text('Rappel désactivé'), findsOneWidget);
  });

  testWidgets('compléments : supprimer retire le rappel', (tester) async {
    final banc = Banc();
    banc.bienetre.complementsParUid['u1'] = const [
      Complement(id: 'x', nom: 'Magnésium', minutes: 1290),
    ];
    await banc.monter(tester);
    expect(find.text('Rappel à 21h30'), findsOneWidget);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(banc.bienetre.complementsDe('u1'), isEmpty);
    expect(banc.rappels.planifications.last, isEmpty);
  });
}
