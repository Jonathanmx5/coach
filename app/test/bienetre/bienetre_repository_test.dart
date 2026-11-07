import 'package:coach/bienetre/bienetre_repository.dart';
import 'package:coach/bienetre/complements.dart';
import 'package:coach/bienetre/hydratation.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FirestoreBienEtreRepository depot;
  setUp(() => depot = FirestoreBienEtreRepository(FakeFirebaseFirestore()));

  test('eau : fenêtre du jour, triée, suppression', () async {
    final jour = DateTime(2026, 10, 9);
    await depot.ajouterEau(
      'u1',
      EntreeEau(date: DateTime(2026, 10, 9, 15), ml: 500),
    );
    await depot.ajouterEau(
      'u1',
      EntreeEau(date: DateTime(2026, 10, 9, 9), ml: 250),
    );
    await depot.ajouterEau(
      'u1',
      EntreeEau(date: DateTime(2026, 10, 8, 23), ml: 300),
    );
    final liste = await depot.eau('u1', jour, DateTime(2026, 10, 10)).first;
    expect(liste.map((e) => e.ml), [250, 500]);

    await depot.supprimerEau('u1', liste.last.id!);
    expect(
      (await depot.eau('u1', jour, DateTime(2026, 10, 10)).first).single.ml,
      250,
    );
  });

  test('météo : réglage par défaut faux', () async {
    expect(await depot.meteoActive('u1').first, isFalse);
    await depot.activerMeteo('u1', true);
    expect(await depot.meteoActive('u1').first, isTrue);
  });

  test('compléments : ajout, tri par heure, modification, prises', () async {
    await depot.ajouterComplement(
      'u1',
      const Complement(nom: 'Soir', minutes: 1260),
    );
    await depot.ajouterComplement(
      'u1',
      const Complement(nom: 'Matin', minutes: 480),
    );
    final liste = await depot.complements('u1').first;
    expect(liste.map((c) => c.nom), ['Matin', 'Soir']);

    await depot.modifierComplement('u1', liste.first.copyWith(actif: false));
    expect((await depot.complements('u1').first).first.actif, isFalse);

    final jour = DateTime(2026, 10, 9);
    final id = liste.first.id!;
    await depot.marquerPris('u1', jour, id, true);
    expect(await depot.prises('u1', jour).first, {id});
    await depot.marquerPris('u1', jour, id, false);
    expect(await depot.prises('u1', jour).first, isEmpty);

    await depot.supprimerComplement('u1', id);
    expect(await depot.complements('u1').first, hasLength(1));
  });

  test('heureTexte', () {
    expect(heureTexte(485), '08h05');
    expect(heureTexte(1260), '21h00');
  });
}
