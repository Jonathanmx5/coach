import 'dart:convert';

import 'package:coach/reglages/mises_a_jour.dart';
import 'package:coach/reglages/reglage_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets('réglages : thème clair, sombre ou automatique', (tester) async {
    final theme = ReglageThemeFixe();
    await racine.monter(
      tester,
      FauxAuth(connecte: racine.lea),
      racine.depotAvecProfil(),
      theme: theme,
    );
    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    final contexte = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(contexte).brightness, Brightness.light);

    await taper(tester, 'Sombre');
    expect(theme.mode.value, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );

    await taper(tester, 'Clair');
    expect(theme.mode.value, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );

    await taper(tester, 'Auto');
    expect(theme.mode.value, ThemeMode.system);
  });

  test('le thème choisi est gardé sur le téléphone', () async {
    SharedPreferences.setMockInitialValues({});
    final premier = await ReglageThemeLocal.charger();
    expect(premier.mode.value, ThemeMode.system);

    await premier.definir(ThemeMode.dark);
    final relance = await ReglageThemeLocal.charger();
    expect(relance.mode.value, ThemeMode.dark);

    SharedPreferences.setMockInitialValues({'theme': 'n-importe-quoi'});
    expect((await ReglageThemeLocal.charger()).mode.value, ThemeMode.system);
  });

  group('sauvegarde Excel', () {
    Future<(FausseSauvegarde, FauxFichiers)> ouvrirSauvegarde(
      WidgetTester tester, {
      FauxReseau? reseau,
    }) async {
      final sauvegarde = FausseSauvegarde();
      final fichiers = FauxFichiers();
      await racine.monter(
        tester,
        FauxAuth(connecte: racine.lea),
        racine.depotAvecProfil(),
        sauvegarde: sauvegarde,
        fichiers: fichiers,
        reseau: reseau,
      );
      await tester.tap(find.byTooltip('Réglages'));
      await tester.pumpAndSettle();
      await defilerJusqua(
        tester,
        find.text('Enregistrer une sauvegarde (Excel)'),
      );
      return (sauvegarde, fichiers);
    }

    testWidgets('enregistrer : fichier daté rangé par le téléphone', (
      tester,
    ) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);

      await taper(tester, 'Enregistrer une sauvegarde (Excel)');

      expect(sauvegarde.exports, ['u1']);
      expect(
        fichiers.enregistres.keys.single,
        matches(r'^crunch-and-go-\d{4}-\d{2}-\d{2}\.xlsx$'),
      );
      expect(find.text('Sauvegarde enregistrée.'), findsOneWidget);
    });

    testWidgets('enregistrer annulé : pas de message de réussite', (
      tester,
    ) async {
      final (_, fichiers) = await ouvrirSauvegarde(tester);
      fichiers.refuse = true;

      await taper(tester, 'Enregistrer une sauvegarde (Excel)');

      expect(find.text('Sauvegarde enregistrée.'), findsNothing);
    });

    testWidgets('importer : confirmation puis résultat', (tester) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);
      fichiers.aChoisir = Uint8List.fromList([9, 9]);

      await taper(tester, 'Importer une sauvegarde');
      expect(find.text('Importer cette sauvegarde ?'), findsOneWidget);
      expect(sauvegarde.imports, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Importer'));
      await tester.pumpAndSettle();

      expect(sauvegarde.imports.single, [9, 9]);
      expect(
        find.text('3 ligne(s) importée(s), 1 ignorée(s).'),
        findsOneWidget,
      );
    });

    testWidgets('importer : refus à la confirmation, rien n\'est écrit', (
      tester,
    ) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);
      fichiers.aChoisir = Uint8List.fromList([9]);

      await taper(tester, 'Importer une sauvegarde');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(sauvegarde.imports, isEmpty);
    });

    testWidgets('importer : fichier invalide, message clair', (tester) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);
      sauvegarde.invalide = true;
      fichiers.aChoisir = Uint8List.fromList([1]);

      await taper(tester, 'Importer une sauvegarde');
      await tester.tap(find.widgetWithText(FilledButton, 'Importer'));
      await tester.pumpAndSettle();

      expect(
        find.text("Ce fichier n'est pas une sauvegarde Crunch & Go."),
        findsOneWidget,
      );
    });

    testWidgets('importer : aucun fichier choisi, rien ne se passe', (
      tester,
    ) async {
      final (sauvegarde, _) = await ouvrirSauvegarde(tester);

      await taper(tester, 'Importer une sauvegarde');

      expect(find.text('Importer cette sauvegarde ?'), findsNothing);
      expect(sauvegarde.imports, isEmpty);
    });

    testWidgets('importer hors-ligne : message, fichier non demandé', (
      tester,
    ) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(
        tester,
        reseau: FauxReseau(false),
      );
      fichiers.aChoisir = Uint8List.fromList([1]);

      await taper(tester, 'Importer une sauvegarde');

      expect(find.textContaining('Connecte-toi à internet'), findsOneWidget);
      expect(sauvegarde.imports, isEmpty);
    });
  });

  testWidgets('réglages : politique de confidentialité', (tester) async {
    racine.liensOuverts.clear();
    await ouvrir(tester, FausseMiseAJour());
    await defilerJusqua(tester, find.text('Photos de repas'));
    expect(find.text('Photos de repas'), findsOneWidget);
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
