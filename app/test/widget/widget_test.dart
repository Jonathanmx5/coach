import 'dart:async';
import 'dart:io';

import 'package:coach/bienetre/hydratation.dart';
import 'package:coach/widget/donnees_widget.dart';
import 'package:coach/widget/rappel_widget.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

DonneesWidget donnees({
  double brulees = 1500,
  double mangees = 1000,
  int eau = 1000,
}) => DonneesWidget(
  brulees: brulees,
  objectifBrule: 2000,
  mangees: mangees,
  objectifMange: 2000,
  proteines: 64,
  objectifProteines: 128,
  eauMl: eau,
  objectifEauMl: 2500,
  description: 'Anneaux du jour.',
);

/// Dépôt dont le cache de l'eau ne répond pas.
class EauIllisible extends FauxBienEtre {
  @override
  Stream<List<EntreeEau>> eau(String uid, DateTime debut, DateTime fin) =>
      Stream.error(StateError('cache'));
}

class _StockageEnPanne extends FauxStockageWidget {
  @override
  Future<String?> lire(String cle) async => throw StateError('panne');
}

void main() {
  test('textes des widgets repas : calories et protéines', () {
    const d = DonneesWidget(
      brulees: 900,
      objectifBrule: 2000,
      mangees: 1249.6,
      objectifMange: 2080,
      proteines: 85.2,
      objectifProteines: 128,
      eauMl: 750,
      objectifEauMl: 2650,
    );
    expect(d.repasTexte, '1250 / 2080 kcal');
    expect(d.proteinesTexte, 'Protéines 85 / 128 g');
  });

  test('chiffres du widget : trois anneaux, eau et bilan', () {
    final d = donnees();
    // L'eau n'est plus dans l'image : une barre native que les boutons
    // tiennent à jour.
    expect(d.progres, [0.75, 0.5, 0.5]);
    expect(d.eauTexte, '1,00 / 2,50 L');
    expect(d.bilanLigne, 'Bilan −500 kcal');
    expect(donnees(mangees: 1700).bilanLigne, 'Bilan +200 kcal');
  });

  test('objectif nul : pas de division par zéro', () {
    const d = DonneesWidget(
      brulees: 10,
      objectifBrule: 0,
      mangees: 0,
      objectifMange: 0,
      proteines: 0,
      objectifProteines: 0,
      eauMl: 0,
      objectifEauMl: 0,
    );
    expect(d.progres, [0, 0, 0]);
  });

  test('égalité : brûlées à 10 kcal près, pas de renvoi chaque minute', () {
    expect(donnees(brulees: 1500.2), donnees(brulees: 1499.8));
    expect(
      donnees(brulees: 1500.2).hashCode,
      donnees(brulees: 1499.8).hashCode,
    );
    // L'estimation sans montre monte d'environ 1 kcal par minute.
    expect(donnees(brulees: 1501), donnees(brulees: 1503));
    expect(donnees(brulees: 1500), isNot(donnees(brulees: 1510)));
    expect(donnees(eau: 1000), isNot(donnees(eau: 1250)));
    expect(donnees(mangees: 1000), isNot(donnees(mangees: 1010)));
  });

  test('l\'image ne change qu\'avec les anneaux au pourcent ou le bilan', () {
    expect(donnees().cleImage, donnees(eau: 2000).cleImage);
    expect(donnees().cleImage, isNot(donnees(mangees: 1100).cleImage));
  });

  group('envoi au widget', () {
    final hier = DateTime(2026, 10, 8);

    WidgetAccueil accueil(FauxStockageWidget stock, List<DonneesWidget> d) =>
        WidgetAccueil(
          stockage: stock,
          dessiner: (x) async => d.add(x),
          lancement: () async => null,
        );

    test(
      'daté du jour de la carte, avec le compte et la description',
      () async {
        final stock = FauxStockageWidget();
        final dessins = <DonneesWidget>[];
        await accueil(stock, dessins).mettre(donnees(), jour: hier, uid: 'u1');

        expect(stock.valeurs['donnees_jour'], '2026-10-08');
        expect(stock.valeurs['eau_jour'], '2026-10-08');
        expect(stock.valeurs['uid'], 'u1');
        expect(stock.valeurs['anneaux_description'], 'Anneaux du jour.');
        expect(stock.valeurs['bilan_texte'], 'Bilan −500 kcal');
        expect(stock.valeurs['eau_texte'], '1,00 / 2,50 L');
        expect(dessins, hasLength(1));
        expect(stock.rafraichissements, 1);
      },
    );

    test('n\'écrit que ce qui change, ne redessine que si besoin', () async {
      final stock = FauxStockageWidget();
      final dessins = <DonneesWidget>[];
      final w = accueil(stock, dessins);
      await w.mettre(donnees(), jour: hier, uid: 'u1');
      stock.ecritures.clear();

      // Rien de changé : aucun accès disque, aucun dessin.
      await w.mettre(donnees(), jour: hier, uid: 'u1');
      expect(stock.ecritures, isEmpty);
      expect(dessins, hasLength(1));
      expect(stock.rafraichissements, 1);

      // De l'eau bue : seulement le texte et le total de l'eau.
      await w.mettre(donnees(eau: 1250), jour: hier, uid: 'u1');
      expect(stock.ecritures, ['eau_texte', 'eau_ml']);
      expect(dessins, hasLength(1));
      expect(stock.rafraichissements, 2);

      // Un autre compte : tout est réécrit et redessiné.
      stock.ecritures.clear();
      await w.mettre(donnees(eau: 1250), jour: hier, uid: 'u2');
      expect(
        stock.ecritures,
        containsAll(clesWidget.where((c) => c != 'anneaux')),
      );
      expect(dessins, hasLength(2));
    });

    test('effacer() retire toutes les clés et l\'image', () async {
      final dossier = await Directory.systemTemp.createTemp('widget');
      addTearDown(() => dossier.delete(recursive: true));
      final image = File('${dossier.path}/anneaux.png')..writeAsBytesSync([1]);

      final stock = FauxStockageWidget();
      final dessins = <DonneesWidget>[];
      final w = accueil(stock, dessins);
      await w.mettre(donnees(), jour: hier, uid: 'u1');
      stock.valeurs['anneaux'] = image.path;
      final avant = stock.rafraichissements;

      await w.effacer();

      for (final cle in clesWidget) {
        expect(stock.valeurs[cle], isNull, reason: cle);
      }
      expect(stock.valeurs, isEmpty);
      expect(image.existsSync(), isFalse);
      expect(stock.rafraichissements, avant + 1);

      // Les mêmes chiffres renvoyés ensuite sont bien réécrits.
      await w.mettre(donnees(), jour: hier, uid: 'u1');
      expect(stock.valeurs['bilan_texte'], 'Bilan −500 kcal');
      expect(dessins, hasLength(2));
    });

    test('l\'action qui a lancé l\'appli n\'est rendue qu\'une fois', () async {
      final w = WidgetAccueil(
        stockage: FauxStockageWidget(),
        lancement: () async => Uri.parse('coach://photo?source=appareil'),
      );
      expect(await w.actionAuLancement(), 'photo-appareil');
      // Accueil recréé (autre compte, questionnaire) : pas de nouvelle photo.
      expect(await w.actionAuLancement(), isNull);
    });
  });

  group('boutons d\'eau du widget', () {
    final matin = DateTime(2026, 10, 9, 8, 30);

    test('l\'eau est enregistrée et le texte du widget mis à jour', () async {
      final depot = FauxBienEtre()
        ..eauParUid['u1'] = [
          EntreeEau(date: DateTime(2026, 10, 9, 7), ml: 750),
        ];
      final stock = FauxStockageWidget()
        ..valeurs['uid'] = 'u1'
        ..valeurs['eau_jour'] = '2026-10-09'
        ..valeurs['eau_ml'] = '750'
        ..valeurs['eau_objectif_ml'] = '2650';

      final total = await ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 250,
        maintenant: matin,
        depot: depot,
        stockage: stock,
      );

      expect(total, 1000);
      expect(depot.eauDe('u1').last.ml, 250);
      expect(depot.eauDe('u1').last.date, matin);
      expect(stock.valeurs['eau_ml'], '1000');
      expect(stock.valeurs['eau_texte'], '1,00 / 2,65 L');
      expect(stock.valeurs['uid'], 'u1');
      expect(stock.rafraichissements, 1);
    });

    test(
      'le total vient du cache Firestore, pas du dernier affichage',
      () async {
        // Le widget affichait 2,40 L de la veille datés d'aujourd'hui (carte
        // redessinée après minuit) : on repart du total réel du jour.
        final stock = FauxStockageWidget()
          ..valeurs['uid'] = 'u1'
          ..valeurs['eau_jour'] = '2026-10-09'
          ..valeurs['eau_ml'] = '2400'
          ..valeurs['eau_objectif_ml'] = '2000';
        final total = await ajouterEauDepuisWidget(
          uid: 'u1',
          ml: 500,
          maintenant: matin,
          depot: FauxBienEtre(),
          stockage: stock,
        );
        expect(total, 500);
        expect(stock.valeurs['eau_jour'], '2026-10-09');
        expect(stock.valeurs['eau_texte'], '0,50 / 2,00 L');
      },
    );

    test('sans données de l\'appli : objectif par défaut de 2 L', () async {
      final stock = FauxStockageWidget();
      await ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 250,
        maintenant: matin,
        depot: FauxBienEtre(),
        stockage: stock,
      );
      expect(stock.valeurs['eau_texte'], '0,25 / 2,00 L');
    });

    test('deux appuis de suite s\'additionnent', () async {
      final depot = FauxBienEtre();
      final stock = FauxStockageWidget();
      await ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 250,
        maintenant: matin,
        depot: depot,
        stockage: stock,
      );
      final total = await ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 500,
        maintenant: matin,
        depot: depot,
        stockage: stock,
      );
      expect(total, 750);
      expect(totalEauMl(depot.eauDe('u1')), 750);
    });

    test('deux appuis simultanés : le widget affiche bien les deux', () async {
      final depot = FauxBienEtre();
      final stock = FauxStockageWidget();
      // Android lance le second sans attendre la fin du premier.
      final totaux = await Future.wait([
        ajouterEauDepuisWidget(
          uid: 'u1',
          ml: 250,
          maintenant: matin,
          depot: depot,
          stockage: stock,
        ),
        ajouterEauDepuisWidget(
          uid: 'u1',
          ml: 250,
          maintenant: matin,
          depot: depot,
          stockage: stock,
        ),
      ]);
      expect(totaux, [250, 500]);
      expect(stock.valeurs['eau_ml'], '500');
      expect(totalEauMl(depot.eauDe('u1')), 500);
    });

    test('autre compte : son total, chiffres de l\'ancien retirés', () async {
      final depot = FauxBienEtre()
        ..eauParUid['u2'] = [
          EntreeEau(date: DateTime(2026, 10, 9, 7), ml: 300),
        ];
      final stock = FauxStockageWidget()
        ..valeurs['uid'] = 'u1'
        ..valeurs['eau_jour'] = '2026-10-09'
        ..valeurs['eau_ml'] = '2400'
        ..valeurs['eau_objectif_ml'] = '2000'
        ..valeurs['donnees_jour'] = '2026-10-09'
        ..valeurs['bilan_texte'] = 'Bilan −420 kcal'
        ..valeurs['repas_texte'] = '1850 / 2080 kcal'
        ..valeurs['proteines_texte'] = 'Protéines 85 / 128 g'
        ..valeurs['anneaux_description'] = 'Anneaux du jour.';

      final total = await ajouterEauDepuisWidget(
        uid: 'u2',
        ml: 250,
        maintenant: matin,
        depot: depot,
        stockage: stock,
      );

      expect(total, 550);
      expect(stock.valeurs['uid'], 'u2');
      for (final cle in clesDonneesJour) {
        expect(stock.valeurs[cle], isNull, reason: cle);
      }
    });

    test('cache illisible : dernier total du même compte et du jour', () async {
      final stock = FauxStockageWidget()
        ..valeurs['uid'] = 'u1'
        ..valeurs['eau_jour'] = '2026-10-09'
        ..valeurs['eau_ml'] = '750';
      expect(
        await ajouterEauDepuisWidget(
          uid: 'u1',
          ml: 250,
          maintenant: matin,
          depot: EauIllisible(),
          stockage: stock,
        ),
        1000,
      );
      // Jamais celui d'un autre compte.
      expect(
        await ajouterEauDepuisWidget(
          uid: 'u2',
          ml: 250,
          maintenant: matin,
          depot: EauIllisible(),
          stockage: stock,
        ),
        250,
      );
    });

    test('un appui en échec ne bloque pas les suivants', () async {
      final echec = ajouterEauDepuisWidget(
        uid: 'u1',
        ml: 250,
        maintenant: matin,
        depot: FauxBienEtre(),
        stockage: _StockageEnPanne(),
      );
      await expectLater(echec, throwsA(isA<StateError>()));
      expect(
        await ajouterEauDepuisWidget(
          uid: 'u1',
          ml: 250,
          maintenant: matin,
          depot: FauxBienEtre(),
          stockage: FauxStockageWidget(),
        ),
        250,
      );
    });
  });

  test('effacerDonneesWidget : plus rien, widget redessiné', () async {
    final stock = FauxStockageWidget();
    for (final cle in clesWidget) {
      stock.valeurs[cle] = 'x';
    }
    await effacerDonneesWidget(stock);
    expect(stock.valeurs, isEmpty);
    expect(stock.rafraichissements, 1);
  });

  test('file d\'attente : dans l\'ordre, une tâche après l\'autre', () async {
    final file = FileDAttente();
    final ordre = <String>[];
    final premiere = Completer<void>();
    final a = file.ajouter(() async {
      ordre.add('a début');
      await premiere.future;
      ordre.add('a fin');
      return 1;
    });
    final b = file.ajouter(() async {
      ordre.add('b');
      return 2;
    });
    await Future<void>.delayed(Duration.zero);
    expect(ordre, ['a début']);
    premiere.complete();
    expect(await Future.wait([a, b]), [1, 2]);
    expect(ordre, ['a début', 'a fin', 'b']);
  });

  test('la clé du jour est zéro-remplie', () {
    expect(cleDuJour(DateTime(2026, 1, 5, 23)), '2026-01-05');
  });
}
