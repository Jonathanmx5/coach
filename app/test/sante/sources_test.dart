import 'package:coach/sante/sources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('noms lisibles des applications de santé', () {
    expect(nomDeSource('com.google.android.apps.fitness'), 'Google Fit');
    expect(nomDeSource('com.xiaomi.wearable'), 'Mi Fitness');
    expect(nomDeSource('com.samsung.android.shealth'), 'Samsung Health');
    // Suffixe ajouté par Health Connect au paquet du téléphone.
    expect(
      nomDeSource(
        'com.android.healthconnect.phone.jcdfcf9f6c8d93eada39343a35bed7868',
      ),
      'Téléphone',
    );
    // Inconnue : dernier morceau du paquet ; absente : vide.
    expect(nomDeSource('org.exemple.moncapteur'), 'moncapteur');
    expect(nomDeSource(null), '');
    expect(nomDeSource('  '), '');
  });
}
