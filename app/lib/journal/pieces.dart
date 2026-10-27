/// Aliments qui se comptent en pièces : une portion en « 2 œufs » est bien
/// plus facile à juger sur une photo qu'un poids en grammes.
library;

/// Poids moyen d'une pièce (cuite ou prête à manger), d'après les portions
/// usuelles.
class Piece {
  const Piece(this.mots, this.singulier, this.pluriel, this.grammes);

  /// Un de ces mots (sans accents, en minuscules) doit être dans le nom.
  final List<String> mots;
  final String singulier;
  final String pluriel;
  final double grammes;
}

const _pieces = [
  Piece(['oeuf', 'oeufs'], 'œuf', 'œufs', 55),
  Piece(
    ['tranche de pain', 'tranches de pain', 'pain de mie'],
    'tranche',
    'tranches',
    30,
  ),
  Piece(['baguette'], 'baguette', 'baguettes', 250),
  Piece(['croissant'], 'croissant', 'croissants', 60),
  Piece(['pain au chocolat'], 'pain au chocolat', 'pains au chocolat', 65),
  Piece(['banane', 'bananes'], 'banane', 'bananes', 120),
  Piece(['pomme', 'pommes'], 'pomme', 'pommes', 150),
  Piece(['orange', 'oranges'], 'orange', 'oranges', 150),
  Piece(
    ['clementine', 'clementines', 'mandarine'],
    'clémentine',
    'clémentines',
    70,
  ),
  Piece(['kiwi', 'kiwis'], 'kiwi', 'kiwis', 75),
  Piece(['yaourt', 'yaourts'], 'pot', 'pots', 125),
  Piece(
    ['tranche de jambon', 'tranches de jambon', 'jambon'],
    'tranche',
    'tranches',
    40,
  ),
  Piece(
    ['tranche de fromage', 'fromage en tranche'],
    'tranche',
    'tranches',
    20,
  ),
  Piece(
    ['biscuit', 'biscuits', 'cookie', 'cookies'],
    'biscuit',
    'biscuits',
    12,
  ),
  Piece(
    ['carre de chocolat', 'carres de chocolat', 'chocolat'],
    'carré',
    'carrés',
    6,
  ),
  Piece(['nugget', 'nuggets'], 'nugget', 'nuggets', 20),
  Piece(['sushi', 'sushis', 'maki', 'makis'], 'pièce', 'pièces', 30),
  Piece(['saucisse', 'saucisses'], 'saucisse', 'saucisses', 80),
  Piece(['tomate cerise', 'tomates cerises'], 'tomate', 'tomates', 15),
  Piece(['amande', 'amandes'], 'amande', 'amandes', 1.2),
  Piece(['noix'], 'noix', 'noix', 4),
  Piece(['datte', 'dattes'], 'datte', 'dattes', 8),
  Piece(
    ['pomme de terre', 'pommes de terre'],
    'pomme de terre',
    'pommes de terre',
    120,
  ),
];

String _simple(String s) {
  const de = 'àâäçéèêëîïôöùûüÿ';
  const vers = 'aaaceeeeiioouuuy';
  final b = StringBuffer();
  for (final c in s.toLowerCase().replaceAll('œ', 'oe').split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : vers[i]);
  }
  return b.toString();
}

final _transforme = RegExp(
  r' (compote|jus|tarte|gateau|glace|mousse|puree|confiture|sirop|sorbet|smoothie|chaud|poudre|lait|boisson|creme|sauce|salade|soupe|pate a|yaourt aux?) ',
);

/// La pièce correspondant au nom de l'aliment, ou null s'il ne se compte pas
/// ainsi (le plus long mot-clé trouvé l'emporte : « pain au chocolat » avant
/// « chocolat »).
Piece? pieceDe(String nom) {
  final n = ' ${_simple(nom).replaceAll(RegExp(r'[^a-z ]'), ' ')} ';
  // Préparations où le fruit ou le chocolat ne se compte plus en pièces.
  if (_transforme.hasMatch(n)) return null;
  Piece? meilleure;
  var longueur = 0;
  for (final p in _pieces) {
    for (final m in p.mots) {
      if (m.length > longueur && n.contains(' $m ')) {
        meilleure = p;
        longueur = m.length;
      }
    }
  }
  return meilleure;
}

/// Nombre de pièces pour [grammes] ; null si c'est moins d'une demi-pièce.
double? nombreDePieces(Piece p, double grammes) {
  final n = grammes / p.grammes;
  if (n < 0.5) return null;
  return (n * 2).round() / 2;
}

/// « 2 œufs », « 1,5 banane » : le nombre de pièces affiché.
String textePieces(Piece p, double grammes) {
  final n = nombreDePieces(p, grammes);
  if (n == null) return '';
  final texte = n == n.roundToDouble()
      ? n.round().toString()
      : n.toString().replaceAll('.', ',');
  return '$texte ${n > 1 ? p.pluriel : p.singulier}';
}

/// Portion après un appui sur + ([sens] = 1) ou − (−1) : une pièce de plus ou
/// de moins, au moins une pièce.
double pieceSuivante(Piece p, double grammes, int sens) {
  final n = (grammes / p.grammes).round() + sens;
  return (n < 1 ? 1 : n) * p.grammes;
}
