import 'package:coach/poids/mensurations.dart';
import 'package:coach/poids/mensurations_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Mensuration prise(int jour, Map<TypeMensuration, double> v) =>
    Mensuration(date: DateTime(2026, 10, jour), valeurs: v);

void main() {
  test('dernière valeur et écart depuis la première', () {
    final liste = [
      prise(1, {TypeMensuration.taille: 90, TypeMensuration.bras: 33}),
      prise(5, {TypeMensuration.taille: 88.5}),
    ];
    final taille = derniereMesure(liste, TypeMensuration.taille)!;
    expect(taille.valeur, 88.5);
    expect(taille.ecart, -1.5);
    final bras = derniereMesure(liste, TypeMensuration.bras)!;
    expect(bras.valeur, 33);
    expect(bras.ecart, isNull);
    expect(derniereMesure(liste, TypeMensuration.masseGrasse), isNull);
  });

  test('toMap / fromMap ne gardent que les valeurs saisies', () {
    final m = prise(1, {TypeMensuration.masseGrasse: 22.5});
    final relu = Mensuration.fromMap('a', m.toMap());
    expect(relu.valeurs, {TypeMensuration.masseGrasse: 22.5});
    expect(relu.date, m.date);
  });

  test('dépôt : ajouter, observer trié, supprimer', () async {
    final depot = FirestoreMensurationsRepository(FakeFirebaseFirestore());
    await depot.ajouter('u1', prise(5, {TypeMensuration.bras: 34}));
    await depot.ajouter('u1', prise(1, {TypeMensuration.bras: 33}));
    final liste = await depot.observer('u1').first;
    expect(liste.map((m) => m.valeurs[TypeMensuration.bras]), [33, 34]);

    await depot.supprimer('u1', liste.first.id!);
    expect(await depot.observer('u1').first, hasLength(1));
  });
}
