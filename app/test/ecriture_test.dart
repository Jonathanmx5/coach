import 'package:coach/ecriture.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Nombre d'appels à surRefus pour [ecriture].
  Future<int> refus(Future<void> ecriture) async {
    var refus = 0;
    ecrireSansAttendre(ecriture, surRefus: () => refus++);
    await Future<void>.delayed(Duration.zero);
    return refus;
  }

  test('écriture réussie : rien à signaler', () async {
    expect(await refus(Future.value()), 0);
  });

  test("refus des règles : surRefus appelé, pas d'erreur non gérée", () async {
    expect(
      await refus(
        Future.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      ),
      1,
    );
  });

  test('autre erreur : notée, sans surRefus', () async {
    expect(
      await refus(
        Future.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      ),
      0,
    );
    expect(await refus(Future.error(Exception('x'))), 0);
  });
}
