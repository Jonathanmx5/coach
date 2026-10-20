import 'package:coach/firebase_init.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('une erreur Firebase non rattrapée n\'est pas un plantage', () {
    expect(
      erreurFatale(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      isFalse,
    );
    expect(
      erreurFatale(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      isFalse,
    );
  });

  test('toute autre erreur reste fatale', () {
    expect(erreurFatale(StateError('bug')), isTrue);
    expect(erreurFatale(const FormatException('x')), isTrue);
  });
}
