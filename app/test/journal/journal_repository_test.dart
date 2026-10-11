import 'package:coach/journal/journal_repository.dart';
import 'package:coach/journal/modele.dart';
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
