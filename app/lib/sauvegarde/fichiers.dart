import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Le fichier choisi dépasse [Fichiers.tailleMax].
class FichierTropGros implements Exception {
  const FichierTropGros();

  @override
  String toString() => 'FichierTropGros';
}

/// Enregistrer ou choisir un fichier Excel, avec les boîtes de dialogue du
/// téléphone.
abstract class Fichiers {
  /// Au-delà, une sauvegarde ne vient pas de l'appli : la lire figerait le
  /// téléphone, voire épuiserait sa mémoire.
  static const tailleMax = 20 * 1024 * 1024;

  /// Propose à l'utilisateur où ranger le fichier ; vrai si c'est fait.
  Future<bool> enregistrer(String nom, Uint8List octets);

  /// Le contenu du fichier Excel choisi, ou null si l'utilisateur renonce.
  /// Lève [FichierTropGros] au-delà de [tailleMax].
  Future<Uint8List?> choisir();

  /// Efface les copies que le sélecteur garde dans le cache de l'appli.
  Future<void> nettoyer();
}

class FichiersSysteme implements Fichiers {
  static const _mime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  @override
  Future<bool> enregistrer(String nom, Uint8List octets) async {
    final adresse = await FilePicker.saveFile(
      fileName: nom,
      bytes: octets,
      mimeType: _mime,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    return adresse != null;
  }

  @override
  Future<Uint8List?> choisir() async {
    final fichier = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (fichier == null) return null;
    try {
      final taille = fichier.lengthSync() ?? await fichier.length();
      if (taille != null && taille > Fichiers.tailleMax) {
        throw const FichierTropGros();
      }
      final octets = await fichier.readAsBytes();
      if (octets.length > Fichiers.tailleMax) throw const FichierTropGros();
      return octets;
    } finally {
      // Sous Android, le sélecteur copie le fichier en clair dans le cache :
      // tout l'historique de santé y resterait.
      await nettoyer();
    }
  }

  @override
  Future<void> nettoyer() async {
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {
      // Rien à effacer sur cette plateforme.
    }
  }
}
