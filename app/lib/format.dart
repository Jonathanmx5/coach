/// Formats de nombres à la française, partagés par les écrans.
library;

/// Nombre avec [decimales] chiffres après la virgule : 79.5 → « 79,5 ».
String formatDecimal(double v, {int decimales = 1}) =>
    v.toStringAsFixed(decimales).replaceAll('.', ',');

/// Millilitres en litres, deux décimales : 1500 → « 1,50 ».
String formatLitres(int ml) => formatDecimal(ml / 1000, decimales: 2);
