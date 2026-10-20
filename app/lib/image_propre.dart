import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Ré-encode une image en JPEG sans aucune métadonnée : ni EXIF (position
/// GPS, numéro de série de l'appareil, nom du propriétaire, date), ni profil
/// de couleur. L'orientation notée dans l'EXIF est appliquée aux pixels avant,
/// pour que la photo ne se retrouve pas couchée. L'image est réduite à
/// [largeurMax] pixels de large au plus.
///
/// Accepte aussi PNG, WebP… (une capture d'écran choisie dans la galerie) : la
/// sortie est toujours un JPEG. Null si les octets ne sont pas une image.
Uint8List? jpegSansMetadonnees(
  Uint8List octets, {
  required int largeurMax,
  required int qualite,
}) {
  final img.Image? lue;
  try {
    lue = img.decodeImage(octets);
  } catch (_) {
    return null;
  }
  if (lue == null) return null;
  var image = img.bakeOrientation(lue);
  if (image.width > largeurMax) {
    image = img.copyResize(image, width: largeurMax);
  }
  image
    ..exif = img.ExifData()
    ..iccProfile = null
    ..textData = null;
  return img.encodeJpg(image, quality: qualite);
}

/// [jpegSansMetadonnees] dans un isolat, pour ne pas figer l'écran.
Future<Uint8List?> nettoyerImage(
  Uint8List octets, {
  int largeurMax = 1024,
  int qualite = 80,
}) => Isolate.run(
  () => jpegSansMetadonnees(octets, largeurMax: largeurMax, qualite: qualite),
);

/// Lit une photo rendue par image_picker, la nettoie ([nettoyerImage]) puis
/// efface la copie qu'image_picker a laissée dans le cache de l'appli : seule
/// la version nettoyée subsiste. Null si le fichier n'est pas une image.
Future<Uint8List?> lirePriseNettoyee(
  XFile prise, {
  int largeurMax = 1024,
  int qualite = 80,
}) async {
  try {
    return await nettoyerImage(
      await prise.readAsBytes(),
      largeurMax: largeurMax,
      qualite: qualite,
    );
  } finally {
    try {
      final f = File(prise.path);
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // Le cache sera purgé par Android : la photo a déjà été lue.
    }
  }
}
