/// Formats de nombres à la française, partagés par les écrans.
library;

/// Nombre avec [decimales] chiffres après la virgule : 79.5 → « 79,5 ».
String formatDecimal(double v, {int decimales = 1}) =>
    v.toStringAsFixed(decimales).replaceAll('.', ',');

/// Millilitres en litres, deux décimales : 1500 → « 1,50 ».
String formatLitres(int ml) => formatDecimal(ml / 1000, decimales: 2);

/// [texte] coupé à [max] caractères (UTF-16), terminé par « … » s'il a fallu
/// couper, sans jamais séparer les deux moitiés d'un émoji.
String tronquer(String texte, int max) {
  if (texte.length <= max) return texte;
  var fin = max - 1;
  final dernier = texte.codeUnitAt(fin - 1);
  if (dernier >= 0xD800 && dernier <= 0xDBFF) fin--;
  return '${texte.substring(0, fin)}…';
}
