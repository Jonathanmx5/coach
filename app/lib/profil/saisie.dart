/// Lit un nombre saisi à la française (« 72,5 ») ou avec un point.
/// Renvoie `null` si la saisie n'est pas un nombre fini.
double? lireNombre(String saisie) {
  final nettoyee = saisie.trim().replaceAll(',', '.');
  final valeur = double.tryParse(nettoyee);
  if (valeur == null || !valeur.isFinite) return null;
  return valeur;
}
