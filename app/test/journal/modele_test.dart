import 'package:coach/bienetre/complements.dart';
import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/journal/modele.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 10, 12, 12, 30);
  AlimentEstime riz(int i) => AlimentEstime(
    nom: 'Riz $i',
    grammes: 100,
    macros: const Macros(kcal: 130),
  );

  Repas repas({
    String nom = 'Riz',
    String description = '',
    int aliments = 0,
    String? photoId,
  }) => Repas(
    date: date,
    moment: Moment.petitDejeuner,
    nom: nom,
    macros: const Macros(kcal: 130),
    source: SourceRepas.codeBarres,
    description: description,
    aliments: [for (var i = 0; i < aliments; i++) riz(i)],
    photoId: photoId,
  );

  test('un repas ordinaire est écrit tel quel et se relit', () {
    final m = repas(
      description: 'Du riz',
      aliments: 2,
      photoId: '1760000000000000',
    ).toMap();
    expect(m['nom'], 'Riz');
    expect(m['moment'], 'petitDejeuner');
    expect(m['source'], 'codeBarres');
    expect(m['description'], 'Du riz');
    expect(m['photoId'], '1760000000000000');
    expect(m['aliments'], hasLength(2));
    final relu = Repas.fromMap('r1', m);
    expect(relu.nom, 'Riz');
    expect(relu.aliments.last.nom, 'Riz 1');
  });

  test('un nom trop long est coupé à 400 caractères avec « … »', () {
    final m = repas(nom: 'Sauce crémeuse, ' * 40).toMap();
    final nom = m['nom']! as String;
    expect(nom.length, Repas.nomMax);
    expect(nom, endsWith('…'));
    expect(nom, startsWith('Sauce crémeuse, Sauce'));
  });

  test('description, aliments et photo restent dans les bornes des règles', () {
    final m = repas(
      description: 'x' * 1000,
      aliments: 45,
      photoId: '1' * 31,
    ).toMap();
    expect((m['description']! as String).length, Repas.descriptionMax);
    expect(m['aliments'], hasLength(Repas.alimentsMax));
    // Les 40 premiers aliments sont gardés, dans l'ordre.
    expect(((m['aliments']! as List).last as Map)['nom'], 'Riz 39');
    // Une référence de photo invalide est omise plutôt que coupée.
    expect(m.containsKey('photoId'), isFalse);
  });

  test('textes courts : moment et source tiennent dans 20 caractères', () {
    for (final mo in Moment.values) {
      for (final s in SourceRepas.values) {
        final m = Repas(
          date: date,
          moment: mo,
          nom: '',
          macros: Macros.zero,
          source: s,
        ).toMap();
        expect((m['moment']! as String).length, lessThanOrEqualTo(20));
        expect((m['source']! as String).length, lessThanOrEqualTo(20));
        expect(m.keys, {'date', 'moment', 'nom', 'macros', 'source'});
      }
    }
  });

  test('le nom d\'un complément est borné à 80 caractères', () {
    final m = Complement(nom: 'a' * 120, minutes: 480).toMap();
    expect((m['nom']! as String).length, Complement.nomMax);
    expect(
      Complement(nom: 'Créatine', minutes: 480).toMap()['nom'],
      'Créatine',
    );
  });
}
