import 'dart:convert';

import 'package:coach/reglages/mises_a_jour.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../fakes.dart';
import '../parcours.dart';
import '../racine_test.dart' as racine;

void main() {
  test('comparaison des versions', () {
    expect(versionPlusRecente('0.9.1', '0.9.0'), isTrue);
    expect(versionPlusRecente('1.0.0', '0.9.9'), isTrue);
    expect(versionPlusRecente('0.10.0', '0.9.0'), isTrue);
    expect(versionPlusRecente('0.9.0', '0.9.0'), isFalse);
    expect(versionPlusRecente('0.8.0', '0.9.0'), isFalse);
    expect(versionPlusRecente('1.0', '1.0.0'), isFalse);
    expect(versionPlusRecente('1.0.0+3', '1.0.0+1'), isFalse);
    expect(versionPlusRecente('beta', '0.9.0'), isFalse);
  });

  group('GitHub', () {
    http.Response liste(List<Map<String, Object?>> l, [int code = 200]) =>
        http.Response.bytes(utf8.encode(jsonEncode(l)), code);

    Map<String, Object?> rel(String tag, {bool draft = false}) => {
      'tag_name': tag,
      'draft': draft,
      'html_url': 'https://github.com/Jonathanmx5/coach/releases/tag/$tag',
    };

    test('plus récente publiée, brouillons ignorés', () async {
      final api = MisesAJourGithub(
        MockClient(
          (_) async =>
              liste([rel('v2.0.0', draft: true), rel('v1.1.0'), rel('v1.0.0')]),
        ),
      );
      final info = await api.verifier('1.0.0');
      expect(info!.version, '1.1.0');
      expect(info.page.toString(), endsWith('/tag/v1.1.0'));
    });

    test('à jour, erreur réseau ou réponse cassée : rien', () async {
      expect(
        await MisesAJourGithub(MockClient((_) async => liste([rel('v1.0.0')])))
            .verifier('1.0.0'),
        isNull,
      );
      expect(
        await MisesAJourGithub(MockClient((_) async => liste([], 403)))
            .verifier('1.0.0'),
        isNull,
      );
      expect(
        await MisesAJourGithub(
          MockClient((_) async => throw http.ClientException('coupé')),
        ).verifier('1.0.0'),
        isNull,
      );
      expect(
        await MisesAJourGithub(
          MockClient((_) async => http.Response('pas du json', 200)),
        ).verifier('1.0.0'),
        isNull,
      );
    });
  });

  Future<void> ouvrir(WidgetTester tester, FausseMiseAJour maj) async {
    await racine.monter(
      tester,
      FauxAuth(connecte: racine.lea),
      racine.depotAvecProfil(),
      miseAJour: maj,
    );
    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
  }

  testWidgets('accueil : pas de point orange sans mise à jour', (tester) async {
    await racine.monter(
      tester,
      FauxAuth(connecte: racine.lea),
      racine.depotAvecProfil(),
    );
    expect(find.byTooltip('Réglages'), findsOneWidget);
    expect(
      tester.widget<Badge>(find.byType(Badge).first).isLabelVisible,
      isFalse,
    );
  });

  testWidgets('accueil : point orange quand une mise à jour existe', (
    tester,
  ) async {
    await racine.monter(
      tester,
      FauxAuth(connecte: racine.lea),
      racine.depotAvecProfil(),
      miseAJour: FausseMiseAJour(
        InfoMiseAJour(version: '1.0.0', page: Uri.parse('https://x.test/v1')),
      ),
    );
    expect(
      tester.widget<Badge>(find.byType(Badge).first).isLabelVisible,
      isTrue,
    );
  });

  testWidgets('réglages : version, QR code de partage, lien copié', (
    tester,
  ) async {
    await ouvrir(tester, FausseMiseAJour());

    expect(find.text('Version 0.9.0'), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      tester.widget<QrImageView>(find.byType(QrImageView)).semanticsLabel,
      "Partager l'application",
    );

    String? copie;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copie = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await taper(tester, 'Copier le lien');
    expect(copie, lienPartage);
    expect(find.text('Lien copié.'), findsOneWidget);
  });

  testWidgets('réglages : mise à jour proposée, téléchargement, vérification', (
    tester,
  ) async {
    racine.liensOuverts.clear();
    final maj = FausseMiseAJour(
      InfoMiseAJour(version: '1.2.0', page: Uri.parse('https://x.test/v1.2')),
    );
    await ouvrir(tester, maj);

    expect(find.text('Nouvelle version 1.2.0 disponible'), findsOneWidget);
    await taper(tester, 'Télécharger la mise à jour');
    expect(racine.liensOuverts, [Uri.parse('https://x.test/v1.2')]);

    final avant = maj.verifications;
    maj.info = null;
    await taper(tester, 'Vérifier les mises à jour');
    expect(maj.verifications, avant + 1);
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('Tu as la dernière version.'), findsOneWidget);
    expect(find.textContaining('Nouvelle version'), findsNothing);
  });

  testWidgets('réglages : politique de confidentialité', (tester) async {
    racine.liensOuverts.clear();
    await ouvrir(tester, FausseMiseAJour());
    await taper(tester, 'Politique de confidentialité');
    expect(racine.liensOuverts.single.toString(), lienConfidentialite);
  });

  testWidgets('réglages : se déconnecter ferme la page', (tester) async {
    await ouvrir(tester, FausseMiseAJour());
    await taper(tester, 'Se déconnecter');
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Réglages'), findsNothing);
  });
}
