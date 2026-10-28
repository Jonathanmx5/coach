import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coach/journal/signalement.dart';
import 'package:coach/reglages/mises_a_jour.dart';
import 'package:coach/reglages/reglage_rapports.dart';
import 'package:coach/reglages/reglage_theme.dart';
import 'package:coach/sauvegarde/fichiers.dart';
import 'package:coach/sauvegarde/sauvegarde.dart';
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

  testWidgets('réglages : sources et licences (Ciqual, Open Food Facts)', (
    tester,
  ) async {
    await ouvrir(tester, FausseMiseAJour());

    await taper(tester, 'Sources et licences');
    expect(find.textContaining("Ciqual 2020 de l'ANSES"), findsOneWidget);
    expect(find.textContaining('Open Food Facts'), findsOneWidget);
    expect(find.textContaining('ODbL'), findsOneWidget);
    expect(find.text('Licences des bibliothèques'), findsOneWidget);

    await taper(tester, 'OK');
    expect(find.textContaining('Open Food Facts'), findsNothing);
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

  test('le choix des rapports de plantage est gardé et appliqué', () async {
    SharedPreferences.setMockInitialValues({});
    final appliques = <bool>[];
    Future<void> appliquer(bool v) async => appliques.add(v);

    final premier = await ReglageRapportsLocal.charger(appliquer: appliquer);
    expect(premier.actif.value, isTrue, reason: 'activé par défaut');

    await premier.definir(false);
    expect(appliques, [false]);
    final relance = await ReglageRapportsLocal.charger(appliquer: appliquer);
    expect(relance.actif.value, isFalse);
  });

  group('rapports de plantage appliqués au service', () {
    Future<List<String>> appliquer({
      required bool actif,
      bool debug = false,
      bool collectePlante = false,
    }) async {
      final appels = <String>[];
      await appliquerChoixRapports(
        actif: actif,
        debug: debug,
        activerCollecte: (v) async {
          appels.add('collecte $v');
          if (collectePlante) throw Exception('indisponible');
        },
        effacerEnAttente: () async => appels.add('effacement'),
      );
      return appels;
    }

    test('accepté : collecte active, rien d\'effacé', () async {
      expect(await appliquer(actif: true), ['collecte true']);
    });

    test('refusé : collecte coupée puis rapports en attente effacés', () async {
      expect(await appliquer(actif: false), ['collecte false', 'effacement']);
    });

    test('jamais de collecte en debug', () async {
      expect(await appliquer(actif: true, debug: true), ['collecte false']);
    });

    test(
      'service en panne : le refus efface quand même, sans erreur',
      () async {
        expect(await appliquer(actif: false, collectePlante: true), [
          'collecte false',
          'effacement',
        ]);
      },
    );

    test('refusé : les erreurs prises en charge ne sont plus notées', () {
      final notees = <Object>[];
      final noterAvant = noterErreur;
      final autorisesAvant = rapportsAutorises;
      addTearDown(() {
        noterErreur = noterAvant;
        rapportsAutorises = autorisesAvant;
      });
      noterErreur = (e, _) async => notees.add(e);
      final rapports = ReglageRapportsFixe();
      rapportsAutorises = () => rapports.actif.value;

      signalerErreur('accepté', StackTrace.current);
      unawaited(rapports.definir(false));
      signalerErreur('refusé', StackTrace.current);

      expect(notees, ['accepté']);
    });
  });

  test('vider le cache efface fichiers et dossiers, sans erreur', () async {
    final cache = await Directory.systemTemp.createTemp('cache_coach');
    addTearDown(() async {
      if (await cache.exists()) await cache.delete(recursive: true);
    });
    await File('${cache.path}/scaled_photo.jpg').writeAsBytes([1, 2, 3]);
    await Directory('${cache.path}/file_picker').create();
    await File('${cache.path}/file_picker/sauvegarde.xlsx').writeAsBytes([4]);

    await FichiersSysteme(cache: () async => cache).viderCache();

    expect(await cache.list().toList(), isEmpty);
    // Un cache absent ne fait pas échouer la suppression du compte.
    await FichiersSysteme(cache: () async => Directory('${cache.path}/absent'))
        .viderCache();
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
      // Par défaut, les lignes déjà présentes ne sont pas remplacées.
      expect(sauvegarde.remplacements, [false]);
      // Des lignes ignorées : la fenêtre dit lesquelles et pourquoi.
      expect(find.text('Import terminé'), findsOneWidget);
      expect(
        find.text('3 ligne(s) importée(s), 1 ignorée(s).'),
        findsOneWidget,
      );
      expect(find.text('• Repas, ligne 4 : date invalide'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Import terminé'), findsNothing);
    });

    testWidgets('importer sans accroc : un simple message', (tester) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);
      sauvegarde.resultat = const ResultatImport(importes: 5, dejaPresents: 2);
      fichiers.aChoisir = Uint8List.fromList([9]);

      await taper(tester, 'Importer une sauvegarde');
      await tester.tap(find.widgetWithText(FilledButton, 'Importer'));
      await tester.pumpAndSettle();

      expect(find.text('Import terminé'), findsNothing);
      expect(
        find.text(
          '5 ligne(s) importée(s), 0 ignorée(s). 2 ligne(s) déjà dans ton '
          'compte, gardée(s) telle(s) quelle(s).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('importer en remplaçant les lignes existantes', (tester) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);
      fichiers.aChoisir = Uint8List.fromList([9]);

      await taper(tester, 'Importer une sauvegarde');
      await tester.tap(find.text('Remplacer les lignes existantes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Importer'));
      await tester.pumpAndSettle();

      expect(sauvegarde.remplacements, [true]);
    });

    testWidgets('import interrompu : ce qui est déjà écrit est annoncé', (
      tester,
    ) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);
      sauvegarde.resultat = ResultatImport(
        importes: 400,
        ignores: [
          for (var i = 0; i < 7; i++) Motif('Eau', i + 2, 'date invalide'),
        ],
        erreur: ErreurImport.interruption,
      );
      fichiers.aChoisir = Uint8List.fromList([9]);

      await taper(tester, 'Importer une sauvegarde');
      await tester.tap(find.widgetWithText(FilledButton, 'Importer'));
      await tester.pumpAndSettle();

      expect(find.text('Import interrompu'), findsOneWidget);
      expect(
        find.text('400 ligne(s) importée(s), 7 ignorée(s).'),
        findsOneWidget,
      );
      expect(find.textContaining('déjà dans ton compte'), findsOneWidget);
      expect(find.textContaining('• Eau, ligne'), findsNWidgets(5));
      expect(find.text('… et 2 autre(s).'), findsOneWidget);
    });

    testWidgets('importer un fichier trop gros ou illisible : message', (
      tester,
    ) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);
      fichiers.erreurChoix = const FichierTropGros();

      await taper(tester, 'Importer une sauvegarde');
      expect(find.textContaining('trop gros'), findsOneWidget);

      fichiers.erreurChoix = Exception('fichier sur le cloud indisponible');
      await taper(tester, 'Importer une sauvegarde');
      expect(find.textContaining("n'a pas pu être lu"), findsOneWidget);
      expect(find.text('Importer cette sauvegarde ?'), findsNothing);
      expect(sauvegarde.imports, isEmpty);
    });

    testWidgets('enregistrer hors-ligne : refusé, la sauvegarde serait '
        'incomplète', (tester) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(
        tester,
        reseau: FauxReseau(false),
      );

      await taper(tester, 'Enregistrer une sauvegarde (Excel)');

      expect(find.textContaining('elle serait incomplète'), findsOneWidget);
      expect(sauvegarde.exports, isEmpty);
      expect(fichiers.enregistres, isEmpty);
    });

    testWidgets('enregistrer : lecture du serveur impossible, aucun fichier', (
      tester,
    ) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);
      sauvegarde.echecExport = Exception('serveur injoignable');

      await taper(tester, 'Enregistrer une sauvegarde (Excel)');

      expect(find.textContaining("n'a pas pu être créée"), findsOneWidget);
      expect(find.text('Sauvegarde enregistrée.'), findsNothing);
      expect(fichiers.enregistres, isEmpty);
    });

    testWidgets('import refusé par le compte : pas de « Réessaie » trompeur', (
      tester,
    ) async {
      final (sauvegarde, fichiers) = await ouvrirSauvegarde(tester);
      sauvegarde.resultat = const ResultatImport(
        importes: 400,
        erreur: ErreurImport.refus,
      );
      fichiers.aChoisir = Uint8List.fromList([9]);

      await taper(tester, 'Importer une sauvegarde');
      await tester.tap(find.widgetWithText(FilledButton, 'Importer'));
      await tester.pumpAndSettle();

      expect(find.text('Import interrompu'), findsOneWidget);
      expect(
        find.text('400 ligne(s) importée(s), 0 ignorée(s).'),
        findsOneWidget,
      );
      expect(find.textContaining("a refusé l'écriture"), findsOneWidget);
      expect(find.textContaining('Réessaie'), findsNothing);
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

  testWidgets(
    "réglages : identifiant du compte affiché et copié, sans e-mail",
    (tester) async {
      await ouvrir(tester, FausseMiseAJour());
      await defilerJusqua(tester, find.text('Identifiant du compte'));
      expect(
        find.textContaining('${racine.lea.uid}\nTouche pour le copier'),
        findsOneWidget,
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
      await taper(tester, 'Identifiant du compte');
      expect(copie, racine.lea.uid);
      expect(find.text('Identifiant copié.'), findsOneWidget);
    },
  );

  testWidgets('réglages : se déconnecter ferme la page', (tester) async {
    await ouvrir(tester, FausseMiseAJour());
    await taper(tester, 'Se déconnecter');
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Réglages'), findsNothing);
  });
}
