import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coach/image_propre.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Marqueurs des segments d'en-tête d'un JPEG, jusqu'au début des données
/// (SOS). APP1 (0xE1) porte l'EXIF.
List<int> marqueurs(Uint8List jpeg) {
  expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
  final vus = <int>[];
  var i = 2;
  while (i + 4 <= jpeg.length) {
    expect(jpeg[i], 0xFF);
    final m = jpeg[i + 1];
    vus.add(m);
    if (m == 0xDA) break;
    i += 2 + (jpeg[i + 2] << 8 | jpeg[i + 3]);
  }
  return vus;
}

bool contient(Uint8List octets, String texte) {
  final motif = ascii.encode(texte);
  for (var i = 0; i + motif.length <= octets.length; i++) {
    var ok = true;
    for (var j = 0; j < motif.length && ok; j++) {
      ok = octets[i + j] == motif[j];
    }
    if (ok) return true;
  }
  return false;
}

/// Photo de [largeur] x [hauteur] avec position GPS, numéro de série et nom
/// du propriétaire, comme celles que recopie image_picker.
Uint8List photoAvecExif({
  int largeur = 40,
  int hauteur = 20,
  int? orientation,
}) {
  final image = img.Image(width: largeur, height: hauteur);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  image.exif.imageIfd.make = 'samsung';
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  image.exif.exifIfd['BodySerialNumber'] = img.IfdValueAscii('R58M12345');
  image.exif.exifIfd['CameraOwnerName'] = img.IfdValueAscii('Jean Dupont');
  image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
  image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(48, 1);
  image.exif.gpsIfd['GPSLongitudeRef'] = img.IfdValueAscii('E');
  image.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational(2, 1);
  return img.encodeJpg(image);
}

void main() {
  test('la photo ressort sans segment EXIF (GPS, numéro de série)', () {
    final source = photoAvecExif();
    // Le JPEG de départ porte bien l'EXIF.
    expect(marqueurs(source), contains(0xE1));
    expect(contient(source, 'R58M12345'), isTrue);

    final propre = jpegSansMetadonnees(source, largeurMax: 1024, qualite: 80)!;
    expect(marqueurs(propre), isNot(contains(0xE1)));
    expect(contient(propre, 'R58M12345'), isFalse);
    expect(contient(propre, 'Jean Dupont'), isFalse);
    expect(contient(propre, 'samsung'), isFalse);
    final relue = img.decodeJpg(propre)!;
    expect(relue.exif.isEmpty, isTrue);
    expect(relue.width, 40);
  });

  test("l'orientation est appliquée aux pixels avant de retirer l'EXIF", () {
    // Orientation 6 : l'appareil était tenu en portrait, à tourner de 90°.
    final source = photoAvecExif(largeur: 40, hauteur: 20, orientation: 6);
    final relue = img.decodeJpg(
      jpegSansMetadonnees(source, largeurMax: 1024, qualite: 80)!,
    )!;
    expect((relue.width, relue.height), (20, 40));
  });

  test('réduite à la largeur maximale, PNG converti en JPEG', () {
    final grande = img.Image(width: 300, height: 100, numChannels: 4);
    final png = img.encodePng(grande);
    final propre = jpegSansMetadonnees(png, largeurMax: 120, qualite: 80)!;
    final relue = img.decodeJpg(propre)!;
    expect((relue.width, relue.height), (120, 40));
  });

  test("ce qui n'est pas une image donne null", () async {
    expect(
      jpegSansMetadonnees(
        Uint8List.fromList([1, 2, 3, 4]),
        largeurMax: 1024,
        qualite: 80,
      ),
      isNull,
    );
    expect(await nettoyerImage(Uint8List(0)), isNull);
  });

  test(
    "la copie d'image_picker est effacée du cache, même illisible",
    () async {
      final dossier = await Directory.systemTemp.createTemp('prise');
      addTearDown(() => dossier.delete(recursive: true));
      final photo = File('${dossier.path}/scaled_1.jpg')
        ..writeAsBytesSync(photoAvecExif());
      final propre = await lirePriseNettoyee(XFile(photo.path));
      expect(propre, isNotNull);
      expect(marqueurs(propre!), isNot(contains(0xE1)));
      expect(photo.existsSync(), isFalse);

      final cassee = File('${dossier.path}/scaled_2.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      expect(await lirePriseNettoyee(XFile(cassee.path)), isNull);
      expect(cassee.existsSync(), isFalse);
    },
  );
}
