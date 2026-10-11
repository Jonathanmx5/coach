import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Les photos des repas analysés. Elles restent sur le téléphone : seule leur
/// référence est notée dans le repas, la photo n'est jamais stockée dans le
/// cloud (confidentialité).
abstract class PhotosRepas {
  /// Range la photo et rend sa référence.
  Future<String> enregistrer(Uint8List octets);

  /// Null si la photo n'est pas (ou plus) sur ce téléphone.
  Future<Uint8List?> lire(String id);

  Future<void> supprimer(String id);

  /// Efface toutes les photos (suppression du compte).
  Future<void> toutSupprimer();
}

class PhotosRepasLocales implements PhotosRepas {
  // La référence vient aussi de la base : on n'accepte que des chiffres, pour
  // ne jamais sortir du dossier.
  static final _valide = RegExp(r'^\d{1,20}$');

  Future<Directory> _dossier() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/photos_repas').create(recursive: true);
  }

  Future<File?> _fichier(String id) async {
    if (!_valide.hasMatch(id)) return null;
    return File('${(await _dossier()).path}/$id.jpg');
  }

  @override
  Future<String> enregistrer(Uint8List octets) async {
    final dossier = await _dossier();
    var id = DateTime.now().microsecondsSinceEpoch;
    while (File('${dossier.path}/$id.jpg').existsSync()) {
      id++;
    }
    await File('${dossier.path}/$id.jpg').writeAsBytes(octets, flush: true);
    return '$id';
  }

  @override
  Future<Uint8List?> lire(String id) async {
    final f = await _fichier(id);
    return f != null && f.existsSync() ? f.readAsBytes() : null;
  }

  @override
  Future<void> supprimer(String id) async {
    final f = await _fichier(id);
    if (f != null && f.existsSync()) await f.delete();
  }

  @override
  Future<void> toutSupprimer() async {
    final dossier = await _dossier();
    for (final f in dossier.listSync()) {
      if (f is File) await f.delete();
    }
  }
}
