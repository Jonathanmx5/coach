import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../journal/analyse_photo.dart' show SourcePhoto;

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

  /// Prend une photo avec l'appareil ou en choisit une dans la bibliothèque,
  /// et la range à la date [jour] (une photo ancienne peut être ajoutée).
  /// Null si l'utilisateur annule.
  Future<PhotoProgres?> ajouter(SourcePhoto source, DateTime jour);

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
  Future<PhotoProgres?> ajouter(SourcePhoto source, DateTime jour) async {
    final prise = await _picker.pickImage(
      source: source == SourcePhoto.appareil
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (prise == null) return null;
    final dossier = await _dossier();
    // Le jour choisi, avec l'heure actuelle pour départager deux photos du
    // même jour ; le nom du fichier est la date en millisecondes.
    final maintenant = DateTime.now();
    var date = DateTime(
      jour.year,
      jour.month,
      jour.day,
      maintenant.hour,
      maintenant.minute,
      maintenant.second,
    );
    while (File('${dossier.path}/${date.millisecondsSinceEpoch}.jpg')
        .existsSync()) {
      date = date.add(const Duration(seconds: 1));
    }
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
