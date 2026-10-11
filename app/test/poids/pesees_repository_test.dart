import 'package:coach/poids/pesees.dart';
import 'package:coach/poids/pesees_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ajouter puis observer : pesées manuelles triées', () async {
    final db = FakeFirebaseFirestore();
    final depot = FirestorePeseesRepository(db);

    await depot.ajouter('u1', kg: 61.5, date: DateTime(2026, 10, 5));
    await depot.ajouter('u1', kg: 62, date: DateTime(2026, 10, 1));
    final pesees = await depot.observer('u1').first;

    expect(pesees.map((p) => p.kg), [62, 61.5]);
    expect(pesees.every((p) => p.source == SourcePesee.manuel), isTrue);
    expect(pesees.every((p) => p.id != null), isTrue);
    final brut = await db.collection('users/u1/pesees').get();
    expect(brut.docs.length, 2);
  });

  test('supprimer retire la pesée', () async {
    final depot = FirestorePeseesRepository(FakeFirebaseFirestore());
    await depot.ajouter('u1', kg: 61.5, date: DateTime(2026, 10, 5));
    final id = (await depot.observer('u1').first).single.id!;

    await depot.supprimer('u1', id);

    expect(await depot.observer('u1').first, isEmpty);
  });
}
