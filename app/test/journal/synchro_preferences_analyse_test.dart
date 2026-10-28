import 'dart:async';

import 'package:coach/journal/preferences_analyse.dart';
import 'package:coach/journal/synchro_preferences_analyse.dart';
import 'package:flutter_test/flutter_test.dart';

class _Depot implements DepotPreferencesAnalyse {
  final flux = StreamController<Map<String, Object?>?>.broadcast();
  final ecritures = <Map<String, Object?>>[];

  @override
  Stream<Map<String, Object?>?> ecouter(String uid) => flux.stream;

  @override
  Future<void> ecrire(String uid, Map<String, Object?> donnees) async {
    ecritures.add(donnees);
  }
}

Future<void> _laisser() => Future<void>.delayed(Duration.zero);

void main() {
  late PreferencesAnalyseMemoire prefs;
  late _Depot depot;
  late StreamController<String?> comptes;

  setUp(() async {
    prefs = PreferencesAnalyseMemoire(
      assietteCm: 26,
      appris: {'riz': const Etalonnage(1.2, 3)},
    );
    depot = _Depot();
    comptes = StreamController<String?>();
    SynchroPreferencesAnalyse(
      prefs: prefs,
      depot: depot,
      comptes: comptes.stream,
    );
    comptes.add('alice');
    await _laisser();
  });

  test('compte vide : les réglages de cet appareil y sont envoyés', () async {
    depot.flux.add(null);
    await _laisser();
    expect(depot.ecritures.single['assiette'], 26);
    expect((depot.ecritures.single['etalonnage'] as Map)['riz'], isNotNull);
  });

  test('première lecture : on réunit, la valeur la plus travaillée gagne', () async {
    depot.flux.add({
      'assiette': 24,
      'etalonnage': {
        'riz': {'f': 0.9, 'n': 8},
        'pates': {'f': 1.1, 'n': 2},
      },
    });
    await _laisser();
    expect(prefs.assietteCm, 24);
    expect(prefs.appris['riz']!.nombre, 8);
    expect(prefs.appris.containsKey('pates'), isTrue);
  });

  test('ensuite, l’autre appareil remplace tout, même « oublier »', () async {
    depot.flux.add(null);
    await _laisser();
    depot.flux.add({'etalonnage': <String, Object?>{}});
    await _laisser();
    expect(prefs.appris, isEmpty);
    expect(prefs.assietteCm, isNull);
  });

  test('un changement ici est envoyé au compte', () async {
    depot.flux.add(null);
    await _laisser();
    depot.ecritures.clear();
    await prefs.definirAssiette(30);
    expect(depot.ecritures.single['assiette'], 30);
  });

  test('déconnecté : rien n’est envoyé', () async {
    comptes.add(null);
    await _laisser();
    await prefs.definirAssiette(20);
    expect(depot.ecritures, isEmpty);
  });
}
