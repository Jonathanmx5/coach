import 'dart:convert';
import 'dart:typed_data';

import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/journal/modele.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final image = Uint8List.fromList([1, 2, 3]);

AnalysePhotoRelais client(
  Future<http.Response> Function(http.Request) rep, {
  String? jeton = 'tok',
}) => AnalysePhotoRelais(
  url: 'https://relais.test',
  jeton: () async => jeton,
  client: MockClient(rep),
);

http.Response json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<CauseAnalyse> cause(AnalysePhotoRelais c) async {
  try {
    await c.analyser(image);
  } on AnalyseEchouee catch (e) {
    return e.cause;
  }
  fail('aucune erreur');
}

void main() {
  test('sans adresse, la fonction est indisponible', () {
    expect(
      AnalysePhotoRelais(url: '', jeton: () async => 't').disponible,
      isFalse,
    );
    expect(client((_) async => json({})).disponible, isTrue);
  });

  test('envoie l\'image avec le jeton et lit les aliments', () async {
    late http.Request vue;
    final c = client((r) async {
      vue = r;
      return json({
        'aliments': [
          {
            'nom': 'Œuf dur',
            'grammes': 100,
            'kcal': 155,
            'proteines': 13,
            'glucides': 1.1,
            'lipides': 11,
          },
          {'nom': 'Pain', 'grammes': 40, 'kcal': 100},
        ],
      });
    });
    final liste = await c.analyser(image);

    expect(vue.url.toString(), 'https://relais.test/analyse');
    expect(vue.headers['authorization'], 'Bearer tok');
    expect(vue.bodyBytes, [1, 2, 3]);
    expect(liste.description, '');
    expect(liste.aliments.map((a) => a.nom), ['Œuf dur', 'Pain']);
    expect(liste.aliments.first.macros.proteines, 13);
    expect(liste.aliments.last.macros.glucides, 0);
  });

  test("la précision de l'utilisateur part en paramètre", () async {
    late Uri vue;
    final c = client((r) async {
      vue = r.url;
      return json({'aliments': []});
    });
    await c.analyser(image, indice: '  sauce à part  ');
    expect(vue.path, '/analyse');
    expect(vue.queryParameters, {'indice': 'sauce à part'});

    await c.analyser(image, indice: '   ');
    expect(vue.query, isEmpty);
    await c.analyser(image);
    expect(vue.query, isEmpty);
  });

  test('confiance : lue, et « à vérifier » sous le seuil', () async {
    final c = client(
      (_) async => json({
        'aliments': [
          {'nom': 'a', 'grammes': 10, 'kcal': 10, 'confiance': 0.9},
          {'nom': 'b', 'grammes': 10, 'kcal': 10, 'confiance': 0.4},
          {'nom': 'c', 'grammes': 10, 'kcal': 10},
        ],
      }),
    );
    final l = (await c.analyser(image)).aliments;
    expect(l.map((a) => a.confiance), [0.9, 0.4, null]);
    expect(l.map((a) => a.aVerifier), [false, true, false]);
    // La portion changée garde la confiance et le nom reste modifiable.
    final b = l[1].avecGrammes(20).avecNom('Sauce');
    expect(b.confiance, 0.4);
    expect(b.nom, 'Sauce');
    expect(b.macros.kcal, 20);
  });

  test(
    'erreurs : pas de jeton, 401, 429, 413/422, 500, réseau, corps cassé',
    () async {
      expect(
        await cause(client((_) async => json({}), jeton: null)),
        CauseAnalyse.auth,
      );
      expect(
        await cause(client((_) async => json({}, 401))),
        CauseAnalyse.auth,
      );
      expect(
        await cause(client((_) async => json({}, 429))),
        CauseAnalyse.quota,
      );
      expect(
        await cause(client((_) async => json({}, 413))),
        CauseAnalyse.illisible,
      );
      expect(
        await cause(client((_) async => json({}, 422))),
        CauseAnalyse.illisible,
      );
      expect(
        await cause(client((_) async => json({}, 502))),
        CauseAnalyse.indisponible,
      );
      expect(
        await cause(client((_) async => throw http.ClientException('coupé'))),
        CauseAnalyse.reseau,
      );
      expect(
        await cause(client((_) async => http.Response('pas du json', 200))),
        CauseAnalyse.illisible,
      );
    },
  );

  test('changer la portion garde les proportions', () {
    const a = AlimentEstime(
      nom: 'Riz',
      grammes: 100,
      macros: Macros(kcal: 130, proteines: 2.7, glucides: 28, lipides: 0.3),
    );
    final b = a.avecGrammes(250);
    expect(b.grammes, 250);
    expect(b.macros.kcal, 325);
    expect(b.macros.glucides, 70);
  });
}
