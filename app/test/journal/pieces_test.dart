import 'package:coach/journal/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les aliments qui se comptent sont reconnus, les autres non', () {
    expect(pieceDe('Œufs durs')?.singulier, 'œuf');
    expect(pieceDe('Pain au chocolat')?.singulier, 'pain au chocolat');
    expect(pieceDe('Banane')?.grammes, 120);
    expect(pieceDe('Riz'), isNull);
    expect(pieceDe('Compote de pommes'), isNull);
    expect(pieceDe('Chocolat chaud'), isNull);
    expect(pieceDe("Jus d'orange"), isNull);
    expect(pieceDe('Poulet'), isNull);
  });

  test('nombre de pièces affiché, arrondi à la demi-pièce', () {
    final oeuf = pieceDe('Oeuf')!;
    expect(textePieces(oeuf, 110), '2 œufs');
    expect(textePieces(oeuf, 55), '1 œuf');
    expect(textePieces(oeuf, 82), '1,5 œufs');
    expect(textePieces(oeuf, 10), '');
  });

  test('+ et − bougent d\'une pièce, jamais sous une pièce', () {
    final oeuf = pieceDe('Oeuf')!;
    expect(pieceSuivante(oeuf, 110, 1), 165);
    expect(pieceSuivante(oeuf, 110, -1), 55);
    expect(pieceSuivante(oeuf, 55, -1), 55);
  });
}
