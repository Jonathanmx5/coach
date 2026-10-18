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

  test('entre : retrouve la correction qui mène d\'une base à une cible', () {
    const cible = Macros(kcal: 350, proteines: 25, glucides: 30, lipides: 10);
    final a = Ajustement.entre(cible, base);
    final m = a.appliquer(base);
    expect(m.kcal, closeTo(350, 0.001));
    expect(m.proteines, closeTo(25, 0.001));
    expect(Ajustement.entre(base, base).estNul, isTrue);
  });
}
