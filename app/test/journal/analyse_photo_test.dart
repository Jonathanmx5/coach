import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  Future<String?> Function()? fonctionJeton,
}) => AnalysePhotoRelais(
  url: 'https://relais.test',
  jeton: fonctionJeton ?? () async => jeton,
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

  test('App Check : la preuve part en en-tête quand elle existe', () async {
    final vues = <http.Request>[];
    Future<http.Response> ok(http.Request r) async {
      vues.add(r);
      return json({'aliments': []});
    }

    await AnalysePhotoRelais(
      url: 'https://relais.test',
      jeton: () async => 'tok',
      preuve: () async => 'preuve-123',
      client: MockClient(ok),
    ).analyser(image);
    await AnalysePhotoRelais(
      url: 'https://relais.test',
      jeton: () async => 'tok',
      preuve: () async => null,
      client: MockClient(ok),
    ).analyser(image);

    expect(vues[0].headers['x-firebase-appcheck'], 'preuve-123');
    expect(vues[1].headers.containsKey('x-firebase-appcheck'), isFalse);
  });

  test('fourchette de quantité lue, et calories entre deux bornes', () async {
    final c = client(
      (_) async => json({
        'description': 'Riz et poulet',
        'aliments': [
          {
            'nom': 'Riz',
            'grammes': 200,
            'grammes_min': 150,
            'grammes_max': 250,
            'kcal': 260,
          },
          {'nom': 'Poulet', 'grammes': 100, 'kcal': 165},
        ],
      }),
    );
    final r = await c.analyser(image);

    expect(r.aliments[0].grammesMin, 150);
    expect(r.aliments[0].grammesMax, 250);
    expect(r.aliments[0].aFourchette, isTrue);
    expect(r.aliments[1].grammesMin, isNull);
    expect(r.aliments[1].aFourchette, isFalse);
    final f = fourchetteKcal(r.aliments)!;
    // Riz : 195 à 325 ; poulet : 165 dans les deux cas.
    expect(f.min, 360);
    expect(f.max, 490);
    expect(fourchetteKcal([r.aliments[1]]), isNull);
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

  test(
    "la précision part dans le corps (multipart), jamais dans l'adresse",
    () async {
      final vues = <http.Request>[];
      final c = client((r) async {
        vues.add(r);
        return json({'aliments': []});
      });
      await c.analyser(image, indice: '  sauce à part  ');
      final r = vues.single;
      expect(r.url.toString(), 'https://relais.test/analyse');
      expect(r.url.query, isEmpty);
      expect(r.headers['authorization'], 'Bearer tok');
      expect(r.headers['content-type'], startsWith('multipart/form-data'));
      final corps = utf8.decode(r.bodyBytes, allowMalformed: true);
      expect(corps, contains('name="indice"'));
      expect(corps, contains('sauce à part'));
      expect(corps, contains('name="image"'));
      expect(corps, contains('content-type: image/jpeg'));

      // Sans précision : le JPEG brut, comme avant.
      vues.clear();
      await c.analyser(image, indice: '   ');
      await c.analyser(image);
      for (final v in vues) {
        expect(v.url.query, isEmpty);
        expect(v.headers['content-type'], 'image/jpeg');
        expect(v.bodyBytes, [1, 2, 3]);
      }
    },
  );

  test(
    "repli : un relais qui ne lit pas le multipart reçoit l'image seule",
    () async {
      final vues = <http.Request>[];
      final c = client((r) async {
        vues.add(r);
        final multipart = r.headers['content-type']!.startsWith('multipart');
        return multipart
            ? json({'erreur': 'illisible'}, 422)
            : json({
                'aliments': [
                  {'nom': 'Riz', 'grammes': 100, 'kcal': 130},
                ],
              });
      });
      final r = await c.analyser(image, indice: 'riz complet');
      expect(r.aliments.single.nom, 'Riz');
      expect(vues, hasLength(2));
      expect(vues[1].url.query, isEmpty);
      expect(vues[1].bodyBytes, [1, 2, 3]);
    },
  );

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
    // Corrigé par l'utilisateur : plus « à vérifier », le reste inchangé.
    final v = b.valideParUtilisateur();
    expect(v.aVerifier, isFalse);
    expect(v.confiance, isNull);
    expect(v.nom, 'Sauce');
    expect(v.grammes, 20);
    expect(v.macros.kcal, 20);
  });

  test(
    'erreurs : jeton, 401, 429, 413, 422, 502, délai, réseau, corps cassé',
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
      // Jeton à renouveler hors réseau : getIdToken lève une exception.
      expect(
        await cause(
          client(
            (_) async => json({}),
            fonctionJeton: () async =>
                throw Exception('network-request-failed'),
          ),
        ),
        CauseAnalyse.reseau,
      );
      expect(
        await cause(client((_) async => json({}, 413))),
        CauseAnalyse.tropGros,
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
        await cause(client((_) async => throw const SocketException('coupé'))),
        CauseAnalyse.reseau,
      );
      expect(
        await cause(client((_) async => throw TimeoutException('lent'))),
        CauseAnalyse.indisponible,
      );
      expect(
        await cause(client((_) async => http.Response('pas du json', 200))),
        CauseAnalyse.illisible,
      );
    },
  );

  test("App Check en panne : l'analyse part quand même, sans preuve", () async {
    late http.Request vue;
    await AnalysePhotoRelais(
      url: 'https://relais.test',
      jeton: () async => 'tok',
      preuve: () async => throw Exception('play integrity'),
      client: MockClient((r) async {
        vue = r;
        return json({'aliments': []});
      }),
    ).analyser(image);
    expect(vue.headers.containsKey('x-firebase-appcheck'), isFalse);
  });

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
