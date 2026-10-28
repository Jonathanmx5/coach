import 'package:coach/accueil/accueil_page.dart';
import 'package:coach/app.dart';
import 'package:coach/coque.dart';
import 'package:coach/entrainement/generateur.dart';
import 'package:coach/entrainement/modele.dart';
import 'package:coach/entrainement/seance_guidee_page.dart';
import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/journal/calculs.dart';
import 'package:coach/journal/detail_repas_page.dart';
import 'package:coach/journal/dialogues_aliment.dart';
import 'package:coach/journal/formulaires.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/journal/photo_repas_page.dart';
import 'package:coach/journal/table_ciqual.dart';
import 'package:coach/poids/pesees.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/recettes/catalogue.dart';
import 'package:coach/recettes/idees_page.dart';
import 'package:coach/recettes/planning_page.dart';
import 'package:coach/recettes/recette_page.dart';
import 'package:coach/reglages/reglages_page.dart';
import 'package:coach/route_verre.dart';
import 'package:coach/verre.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coque_test.dart' show Banc, lea, profil;
import 'fakes.dart';
import 'parcours.dart';

/// Tailles et orientations d'écran vérifiées (en dp).
const tailles = {
  'tablette 10" portrait': Size(800, 1280),
  'tablette 10" paysage': Size(1280, 800),
  'tablette 8" portrait': Size(600, 960),
  'tablette 8" paysage': Size(960, 600),
  'téléphone portrait': Size(400, 800),
  'téléphone paysage': Size(800, 360),
};

const cibles = CiblesJour(kcal: 2080, proteines: 128, glucides: 250, lipides: 58);

/// Un journal bien rempli : de quoi remplir les listes et les totaux.
void remplir(Banc banc) {
  final jour = banc.heure;
  Repas repas(int h, Moment moment, String nom, int kcal, List<AlimentEstime> a) =>
      Repas(
        id: 'r$h',
        date: DateTime(jour.year, jour.month, jour.day, h),
        moment: moment,
        nom: nom,
        macros: Macros(kcal: kcal.toDouble(), proteines: 30, glucides: 60, lipides: 20),
        source: SourceRepas.photo,
        aliments: a,
      );
  banc.journal.repasParUid['u1'] = [
    repas(8, Moment.petitDejeuner, 'Porridge, Banane, Amandes', 420, [
      aliment('Porridge', 200, 250),
      aliment('Banane', 120, 110),
      aliment('Amandes', 10, 60),
    ]),
    repas(12, Moment.dejeuner,
        'Poulet rôti, Riz basmati, Haricots verts, Sauce à la crème et aux champignons',
        780, [
      aliment('Poulet rôti', 150, 300),
      aliment('Riz basmati', 200, 260),
      aliment('Haricots verts', 150, 50),
      aliment('Sauce à la crème et aux champignons', 40, 170),
    ]),
    repas(16, Moment.collation, 'Yaourt', 120, [aliment('Yaourt', 125, 120)]),
  ];
  banc.journal.activitesParUid['u1'] = [
    Activite(
      id: 'a1',
      date: DateTime(jour.year, jour.month, jour.day, 18),
      type: TypeActivite.course,
      minutes: 45,
      intensite: Intensite.moderee,
      kcal: 420,
    ),
  ];
  final pesees = banc.services.pesees as FauxPesees;
  pesees.donnees['u1'] = [
    for (var i = 0; i < 30; i++)
      Pesee(
        id: 'p$i',
        date: jour.subtract(Duration(days: 30 - i)),
        kg: 82 - i * 0.05,
        source: SourcePesee.manuel,
      ),
  ];
}

AlimentEstime aliment(String nom, double g, double kcal) => AlimentEstime(
  nom: nom,
  grammes: g,
  macros: Macros(kcal: kcal, proteines: kcal / 20, glucides: kcal / 8, lipides: kcal / 25),
);

void main() {
  for (final MapEntry(key: nom, value: taille) in tailles.entries) {
    group(nom, () {
      late Banc banc;

      Future<void> monter(WidgetTester tester, {double clavier = 0}) async {
        tester.view.physicalSize = taille;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: clavier);
        addTearDown(tester.view.reset);
        banc = Banc();
        remplir(banc);
        await banc.monter(tester);
      }

      Future<void> verifier(WidgetTester tester, String quoi) async {
        await tester.pumpAndSettle();
        final erreur = tester.takeException();
        expect(
          erreur,
          isNull,
          reason: '$nom / $quoi ${erreur is FlutterError ? erreur.toStringDeep() : ''}',
        );
      }

      /// Ouvre un écran poussé comme l'appli (route de verre), le contrôle,
      /// puis le referme.
      Future<void> pousser(
        WidgetTester tester,
        String quoi,
        WidgetBuilder page, {
        Future<void> Function()? ensuite,
      }) async {
        final nav = Navigator.of(tester.element(find.byType(Coque)));
        nav.push<void>(routeVerre(page));
        await verifier(tester, quoi);
        await ensuite?.call();
        await verifier(tester, quoi);
        nav.pop();
        await verifier(tester, 'retour de $quoi');
      }

      testWidgets('onglets avec un journal rempli', (tester) async {
        await monter(tester);
        final barre = taille.width >= largeurTablette
            ? find.byType(NavigationRail)
            : find.byType(NavigationBar);
        for (final onglet in ['Repas', 'Sport', 'Poids', 'Bien-être', 'Accueil']) {
          await tester.tap(
            find.descendant(of: barre, matching: find.text(onglet)).first,
          );
          await verifier(tester, onglet);
        }
        expect(find.byType(AccueilPage), findsOneWidget);
      });

      testWidgets('écrans poussés : réglages, idées, recettes, planning', (
        tester,
      ) async {
        await monter(tester);
        final s = banc.services;
        final recette = catalogueRecettes.first;
        await pousser(
          tester,
          'Réglages',
          (_) => ReglagesPage(
            utilisateur: lea,
            services: s,
            version: Future.value('0.15.0'),
            miseAJour: ValueNotifier(null),
            reverifier: () async {},
          ),
        );
        await pousser(
          tester,
          'Idées',
          (_) => IdeesPage(
            utilisateur: lea,
            objectif: Objectif.perte,
            kcalCible: 2000,
            avis: s.avis,
            horloge: () => banc.heure,
          ),
        );
        await pousser(
          tester,
          'Envies',
          (_) => EnviesPage(uid: 'u1', avis: s.avis, portions: (_) => 1),
        );
        await pousser(
          tester,
          'Recette',
          (_) => RecettePage(recette: recette, portions: 1.5),
        );
        await pousser(
          tester,
          'Planning',
          (_) => PlanningPage(
            utilisateur: lea,
            kcalCible: 2000,
            planning: s.planning,
            avis: s.avis,
            journal: s.journal,
            horloge: () => banc.heure,
          ),
        );
      });

      testWidgets('écrans poussés : repas, activité, séance', (tester) async {
        await monter(tester);
        final s = banc.services;
        final repas = banc.journal.repasDe('u1')[1];
        await pousser(
          tester,
          'Détail du repas',
          (_) => DetailRepasPage(
            repas: repas,
            dejaMange: const Macros(kcal: 540, proteines: 40, glucides: 90, lipides: 25),
            cibles: cibles,
            objectif: Objectif.perte,
            photos: s.photosRepas,
            onModifier: (r) async {},
          ),
        );
        await pousser(
          tester,
          'Ajout repas',
          (_) => AjoutRepasPage(date: banc.heure),
        );
        await pousser(
          tester,
          'Ajout activité',
          (_) => AjoutActivitePage(date: banc.heure, poidsKg: 80),
        );
        final seance = genererRenforcement(
          lieu: Lieu.maison,
          materiel: const {},
          profil: profil,
          seancesFaites: 0,
        );
        await pousser(
          tester,
          'Séance guidée',
          (_) => SeanceGuideePage(seance: seance, voix: FausseVoix()),
        );
      });

      testWidgets('photo du repas : choix, puis résultat avec aliments', (
        tester,
      ) async {
        await monter(tester);
        final s = banc.services;
        await pousser(
          tester,
          'Photo du repas',
          (_) => PhotoRepasPage(
            date: banc.heure,
            analyse: FausseAnalyse(
              aliments: [
                aliment('Riz', 200, 260),
                aliment('Poulet', 150, 250),
                aliment('Haricots verts', 150, 50),
                aliment('Sauce à la crème et aux champignons', 40, 170),
              ],
            ),
            prise: (_) async => Uint8List.fromList([1, 2, 3]),
            photos: s.photosRepas,
            catalogue: s.catalogue,
            accordPhoto: (_) async => true,
            scan: (_) async => null,
            cibles: cibles,
            dejaMange: const Macros(kcal: 540, proteines: 40, glucides: 90, lipides: 25),
          ),
          ensuite: () async {
            await taper(tester, 'Prendre une photo');
            await taper(tester, 'Analyser ce repas');
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('dialogues, clavier ouvert', (tester) async {
        // Un clavier occupe à peu près la moitié d'un écran à plat.
        tester.view.physicalSize = taille;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: taille.height * 0.45);
        addTearDown(tester.view.reset);
        // Page neutre : on juge les dialogues, pas l'écran en dessous.
        await tester.pumpWidget(const CoachApp(accueil: Scaffold(body: SizedBox())));
        await tester.pumpAndSettle();
        final contexte = tester.element(find.byType(Scaffold));
        for (final (quoi, dialogue) in <(String, Widget)>[
          ('portion', const DialoguePortion(nom: 'Riz basmati')),
          ('aliment', DialogueAliment(modele: aliment('Riz basmati', 200, 260))),
          ('nouvel aliment', const DialogueAliment()),
          ('recherche Ciqual', const DialogueRechercheCiqual(depart: 'riz')),
        ]) {
          showDialog<void>(context: contexte, builder: (_) => dialogue);
          await verifier(tester, 'dialogue $quoi');
          Navigator.of(contexte).pop();
          await verifier(tester, 'fermeture $quoi');
        }
      });
    });
  }
}
