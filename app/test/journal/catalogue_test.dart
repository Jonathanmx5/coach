import 'dart:convert';

import 'package:coach/journal/catalogue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client client(
  int statut,
  Object corps, {
  void Function(http.Request)? vu,
}) => MockClient((req) async {
  vu?.call(req);
  return http.Response(
    jsonEncode(corps),
    statut,
    headers: {'content-type': 'application/json'},
  );
});

void main() {
  test('produit trouvé : nom et valeurs pour 100 g', () async {
    late http.Request requete;
    final catalogue = CatalogueOpenFoodFacts(
      client(200, {
        'status': 1,
        'product': {
          'product_name': 'Muesli croustillant',
          'brands': 'Marque',
          'nutriments': {
            'energy-kcal_100g': 410,
            'proteins_100g': 9.5,
            'carbohydrates_100g': 62,
            'fat_100g': 13.2,
          },
        },
      }, vu: (r) => requete = r),
    );

    final p = (await catalogue.chercher('3017620422003'))!;

    expect(p.nom, 'Muesli croustillant');
    expect(p.pour100g.kcal, 410);
    expect(p.pour100g.proteines, 9.5);
    expect(p.pour100g.glucides, 62);
    expect(p.pour100g.lipides, 13.2);
    expect(requete.url.path, contains('3017620422003'));
    expect(requete.headers['User-Agent'], contains('Coach'));
  });

  test('kcal absentes : calculées depuis les kJ', () async {
    final catalogue = CatalogueOpenFoodFacts(
      client(200, {
        'status': 1,
        'product': {
          'product_name': 'Barre',
          'nutriments': {'energy_100g': 1046, 'proteins_100g': 5},
        },
      }),
    );
    expect((await catalogue.chercher('1'))!.pour100g.kcal, closeTo(250, 0.5));
  });

  test('produit inconnu : null', () async {
    final catalogue = CatalogueOpenFoodFacts(
      client(200, {'status': 0, 'status_verbose': 'product not found'}),
    );
    expect(await catalogue.chercher('0000'), isNull);
  });

  test('erreur réseau ou serveur : exception ErreurCatalogue', () async {
    final catalogue = CatalogueOpenFoodFacts(client(503, {}));
    expect(() => catalogue.chercher('1'), throwsA(isA<ErreurCatalogue>()));
  });

  test('produit sans données nutritionnelles : null', () async {
    final catalogue = CatalogueOpenFoodFacts(
      client(200, {
        'status': 1,
        'product': {'product_name': 'Mystère', 'nutriments': {}},
      }),
    );
    expect(await catalogue.chercher('2'), isNull);
  });
}
