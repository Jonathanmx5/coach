import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Une photo de progression, stockée sur l'appareil.
@immutable
class PhotoProgres {
  const PhotoProgres({required this.chemin, required this.date});

  final String chemin;
  final DateTime date;
}

/// Photos de progression. Elles restent sur le téléphone : jamais envoyées
/// dans le cloud (confidentialité).
abstract class PhotosProgres {
  /// Triées par date croissante.
  Future<List<PhotoProgres>> lister();

  /// Ouvre l'appareil photo ; null si l'utilisateur annule.
  Future<PhotoProgres?> prendre(DateTime date);

  Future<void> supprimer(PhotoProgres photo);
}

class PhotosProgresLocales implements PhotosProgres {
  PhotosProgresLocales([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<Directory> _dossier() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/photos_progres').create(recursive: true);
  }

  @override
  Future<List<PhotoProgres>> lister() async {
    final dossier = await _dossier();
    final photos = <PhotoProgres>[];
    for (final f in dossier.listSync()) {
      final nom = f.uri.pathSegments.last;
      final millis = int.tryParse(nom.split('.').first);
      if (f is File && millis != null) {
        photos.add(
          PhotoProgres(
            chemin: f.path,
            date: DateTime.fromMillisecondsSinceEpoch(millis),
          ),
        );
      }
    }
    return photos..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<PhotoProgres?> prendre(DateTime date) async {
    final prise = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (prise == null) return null;
    final dossier = await _dossier();
    final chemin = '${dossier.path}/${date.millisecondsSinceEpoch}.jpg';
    await File(prise.path).copy(chemin);
    return PhotoProgres(chemin: chemin, date: date);
  }

  @override
  Future<void> supprimer(PhotoProgres photo) async {
    final f = File(photo.chemin);
    if (f.existsSync()) await f.delete();
  }
}
