import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/journal/journal_repository.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/journal/verdict.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Repas repas(DateTime date, double kcal) => Repas(
  date: date,
  moment: Moment.diner,
  nom: 'Pâtes',
  macros: Macros(kcal: kcal, proteines: 12, glucides: 70, lipides: 5),
  source: SourceRepas.codeBarres,
);

void main() {
  final lundi = DateTime(2026, 10, 5);
  final mardi = DateTime(2026, 10, 6);

  test('repas du jour : seulement ceux de la fenêtre, triés', () async {
    final depot = FirestoreJournalRepository(FakeFirebaseFirestore());
    await depot.ajouterRepas(
      'u1',
      repas(lundi.add(const Duration(hours: 20)), 600),
    );
    await depot.ajouterRepas(
      'u1',
      repas(lundi.add(const Duration(hours: 8)), 300),
    );
    await depot.ajouterRepas(
      'u1',
      repas(mardi.add(const Duration(hours: 8)), 999),
    );

    final liste = await depot.repas('u1', lundi, mardi).first;

    expect(liste.map((r) => r.macros.kcal), [300, 600]);
    expect(liste.first.id, isNotNull);
    expect(liste.first.source, SourceRepas.codeBarres);
    expect(liste.first.macros.proteines, 12);
  });

  test('un repas photographié garde son analyse', () async {
    final depot = FirestoreJournalRepository(FakeFirebaseFirestore());
    await depot.ajouterRepas(
      'u1',
      Repas(
        date: lundi.add(const Duration(hours: 12)),
        moment: Moment.dejeuner,
        nom: 'Riz',
        macros: const Macros(kcal: 130, proteines: 3),
        source: SourceRepas.photo,
        description: 'Du riz blanc',
        photoId: '123',
        verdict: const Verdict(
          feu: Feu.rouge,
          points: ['Trop sucré', 'Peu de protéines'],
          conclusion: 'À éviter',
        ),
        aliments: const [
          AlimentEstime(
            nom: 'Riz',
            grammes: 100,
            macros: Macros(kcal: 130, proteines: 3, glucides: 28),
            confiance: 0.5,
            sucres: 1,
          ),
        ],
      ),
    );

    final r = (await depot.repas('u1', lundi, mardi).first).single;

    expect(r.description, 'Du riz blanc');
    expect(r.photoId, '123');
    expect(r.verdict?.feu, Feu.rouge);
    expect(r.verdict?.points, ['Trop sucré', 'Peu de protéines']);
    expect(r.verdict?.conclusion, 'À éviter');
    expect(r.aliments.single.nom, 'Riz');
    expect(r.aliments.single.grammes, 100);
    expect(r.aliments.single.confiance, 0.5);
    expect(r.aliments.single.sucres, 1);
    expect(r.aliments.single.satures, isNull);
    expect(r.aliments.single.macros.glucides, 28);
  });

  test('supprimer un repas', () async {
    final depot = FirestoreJournalRepository(FakeFirebaseFirestore());
    await depot.ajouterRepas(
      'u1',
      repas(lundi.add(const Duration(hours: 8)), 300),
    );
    final id = (await depot.repas('u1', lundi, mardi).first).single.id!;

    await depot.supprimerRepas('u1', id);

    expect(await depot.repas('u1', lundi, mardi).first, isEmpty);
  });

  test('activités : ajout, lecture et suppression', () async {
    final depot = FirestoreJournalRepository(FakeFirebaseFirestore());
    await depot.ajouterActivite(
      'u1',
      Activite(
        date: lundi.add(const Duration(hours: 18)),
        type: TypeActivite.mma,
        minutes: 90,
        intensite: Intensite.intense,
        kcal: 1440,
      ),
    );

    final liste = await depot.activites('u1', lundi, mardi).first;
    expect(liste.single.type, TypeActivite.mma);
    expect(liste.single.kcal, 1440);

    await depot.supprimerActivite('u1', liste.single.id!);
    expect(await depot.activites('u1', lundi, mardi).first, isEmpty);
  });
}
