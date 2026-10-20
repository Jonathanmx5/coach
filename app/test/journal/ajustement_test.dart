import 'package:coach/journal/ajustement.dart';
import 'package:coach/journal/modele.dart';
import 'package:flutter_test/flutter_test.dart';

const base = Macros(kcal: 300, proteines: 20, glucides: 30, lipides: 10);

void main() {
  test('sans correction, rien ne change', () {
    const a = Ajustement();
    expect(a.estNul, isTrue);
    final m = a.appliquer(base);
    expect(m.kcal, 300);
    expect(m.proteines, 20);
  });

  test('les calories suivent les macros : 4 kcal par g de protéines, 9 par g de lipides', () {
    var a = const Ajustement();
    a = a.avec(ChampMacro.proteines, 1, base);
    expect(a.appliquer(base).proteines, 21);
    expect(a.appliquer(base).kcal, 304);

    a = a.avec(ChampMacro.lipides, 1, base);
    expect(a.appliquer(base).lipides, 11);
    expect(a.appliquer(base).kcal, 313);

    a = a.avec(ChampMacro.glucides, -1, base);
    expect(a.appliquer(base).glucides, 29);
    expect(a.appliquer(base).kcal, 309);
  });

  test('les calories se corrigent seules, par 10, sans toucher aux macros', () {
    final a = const Ajustement()
        .avec(ChampMacro.kcal, 1, base)
        .avec(ChampMacro.kcal, 1, base);
    final m = a.appliquer(base);
    expect(m.kcal, 320);
    expect(m.proteines, 20);
    expect(m.glucides, 30);
    expect(m.lipides, 10);
    expect(a.avec(ChampMacro.kcal, -1, base).appliquer(base).kcal, 310);
  });

  test('jamais de valeur négative : le bouton − s\'arrête à zéro', () {
    const petit = Macros(kcal: 8, proteines: 1, glucides: 0, lipides: 0);
    var a = const Ajustement().avec(ChampMacro.proteines, -1, petit);
    expect(a.appliquer(petit).proteines, 0);
    final encore = a.avec(ChampMacro.proteines, -1, petit);
    expect(encore, a); // sans effet
    expect(a.avec(ChampMacro.glucides, -1, petit), a);
    expect(
      a.avec(ChampMacro.kcal, -1, petit).appliquer(petit).kcal >= 0,
      isTrue,
    );
    // + puis − revient au départ.
    a = a.avec(ChampMacro.proteines, 1, petit);
    expect(a.estNul, isTrue);
  });

  group('reborne : aliment décoché après une correction', () {
    // Steak (250 kcal, 16 g de lipides) et salade.
    const salade = Macros(kcal: 40, proteines: 2, glucides: 5, lipides: 1.5);
    const steakSalade = Macros(
      kcal: 290,
      proteines: 28,
      glucides: 5,
      lipides: 17.5,
    );

    test('les lipides baissés de 15 g ne retirent pas plus que la salade', () {
      var a = const Ajustement();
      for (var i = 0; i < 15; i++) {
        a = a.avec(ChampMacro.lipides, -1, steakSalade);
      }
      expect(a.appliquer(steakSalade).lipides, closeTo(2.5, 0.001));

      // On décoche le steak : sans reborne, 0 kcal pour 2 g de protéines.
      final b = a.reborne(salade);
      final m = b.appliquer(salade);
      expect(m.lipides, 0);
      expect(m.proteines, 2);
      expect(m.glucides, 5);
      // Seuls les 1,5 g de lipides de la salade sont retirés : 40 − 13,5.
      expect(m.kcal, closeTo(26.5, 0.001));
    });

    test('les calories baissées à la main ne passent jamais sous zéro', () {
      var a = const Ajustement();
      for (var i = 0; i < 20; i++) {
        a = a.avec(ChampMacro.kcal, -1, steakSalade);
      }
      expect(a.appliquer(steakSalade).kcal, 90);
      final m = a.reborne(salade).appliquer(salade);
      expect(m.kcal, 0);
      // Et l'ajustement borné reste valide : + le fait remonter tout de suite.
      final plus = a
          .reborne(salade)
          .avec(ChampMacro.kcal, 1, salade)
          .appliquer(salade);
      expect(plus.kcal, 10);
    });

    test('une correction encore valide est gardée telle quelle', () {
      final a = const Ajustement()
          .avec(ChampMacro.proteines, 1, steakSalade)
          .avec(ChampMacro.kcal, -1, steakSalade);
      expect(identical(a.reborne(salade), a), isTrue);
      expect(const Ajustement().reborne(salade).estNul, isTrue);
    });
  });

  test('partCorrigee : les sucres suivent les glucides corrigés', () {
    expect(partCorrigee(null, avant: 30, apres: 10), isNull);
    // 30 g de glucides dont 30 g de sucres, ramenés à 10 g : 10 g de sucres.
    expect(partCorrigee(30, avant: 30, apres: 10), 10);
    expect(partCorrigee(15, avant: 30, apres: 20), 10);
    expect(partCorrigee(5, avant: 30, apres: 30), 5);
    expect(partCorrigee(5, avant: 0, apres: 2), 2);
  });

  test('entre : retrouve la correction qui mène d\'une base à une cible', () {
    const cible = Macros(kcal: 350, proteines: 25, glucides: 30, lipides: 10);
    final a = Ajustement.entre(cible, base);
    final m = a.appliquer(base);
    expect(m.kcal, closeTo(350, 0.001));
    expect(m.proteines, closeTo(25, 0.001));
    expect(Ajustement.entre(base, base).estNul, isTrue);
  });
}
