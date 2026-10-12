import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Enregistrer ou choisir un fichier Excel, avec les boîtes de dialogue du
/// téléphone.
abstract class Fichiers {
  /// Propose à l'utilisateur où ranger le fichier ; vrai si c'est fait.
  Future<bool> enregistrer(String nom, Uint8List octets);

  /// Le contenu du fichier Excel choisi, ou null si l'utilisateur renonce.
  Future<Uint8List?> choisir();
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
    return fichier?.readAsBytes();
  }
}
