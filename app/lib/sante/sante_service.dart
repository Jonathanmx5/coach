import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'modele.dart';

enum DispoSante { disponible, aInstaller, indisponible }

/// Accès en lecture seule à Health Connect (spec santé connectée §2).
abstract class SanteService {
  Future<DispoSante> disponibilite();
  Future<void> installer();

  /// Vrai si l'utilisateur a accordé au moins une partie de l'accès.
  Future<bool> demanderAutorisations();

  /// [types] : les mesures à lire, à donner explicitement pour ne pas lire ce
  /// qui ne sert pas (par défaut : toutes les mesures connues).
  Future<List<PointSante>> lire(
    DateTime debut,
    DateTime fin, {
    Set<TypeMesure>? types,
  });
}

class HealthSanteService implements SanteService {
  HealthSanteService([Health? health]) : _health = health ?? Health();

  final Health _health;
  Future<void>? _configuration;

  static const _correspondances = {
    HealthDataType.STEPS: TypeMesure.pas,
    HealthDataType.DISTANCE_DELTA: TypeMesure.distance,
    HealthDataType.FLIGHTS_CLIMBED: TypeMesure.etages,
    HealthDataType.ACTIVE_ENERGY_BURNED: TypeMesure.kcalActives,
    HealthDataType.TOTAL_CALORIES_BURNED: TypeMesure.kcalTotales,
    HealthDataType.RESTING_HEART_RATE: TypeMesure.fcRepos,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD: TypeMesure.variabilite,
    HealthDataType.BLOOD_OXYGEN: TypeMesure.spo2,
    HealthDataType.RESPIRATORY_RATE: TypeMesure.freqResp,
    HealthDataType.WEIGHT: TypeMesure.poids,
    HealthDataType.BODY_FAT_PERCENTAGE: TypeMesure.masseGrasse,
    HealthDataType.SLEEP_DEEP: TypeMesure.sommeilProfond,
    HealthDataType.SLEEP_LIGHT: TypeMesure.sommeilLeger,
    HealthDataType.SLEEP_REM: TypeMesure.sommeilParadoxal,
    HealthDataType.SLEEP_AWAKE: TypeMesure.sommeilEveil,
    HealthDataType.SLEEP_ASLEEP: TypeMesure.sommeilEndormi,
    // La session entière : elle relie les phases d'une même nuit et donne la
    // durée des nuits écrites sans phases.
    HealthDataType.SLEEP_SESSION: TypeMesure.sommeilSession,
    HealthDataType.WORKOUT: TypeMesure.seance,
  };

  static final _types = _correspondances.keys.toList();

  Future<void> _configurer() => _configuration ??= _health.configure();

  @override
  Future<DispoSante> disponibilite() async {
    await _configurer();
    return switch (await _health.getHealthConnectSdkStatus()) {
      HealthConnectSdkStatus.sdkAvailable => DispoSante.disponible,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        DispoSante.aInstaller,
      _ => DispoSante.indisponible,
    };
  }

  @override
  Future<void> installer() async {
    await _configurer();
    await _health.installHealthConnect();
  }

  @override
  Future<bool> demanderAutorisations() async {
    await _configurer();
    await Permission.activityRecognition.request();
    final accorde = await _health.requestAuthorization(
      _types,
      permissions: [for (final _ in _types) HealthDataAccess.READ],
    );
    if (accorde && !await _health.isHealthDataHistoryAuthorized()) {
      await _health.requestHealthDataHistoryAuthorization();
    }
    return accorde;
  }

  @override
  Future<List<PointSante>> lire(
    DateTime debut,
    DateTime fin, {
    Set<TypeMesure>? types,
  }) async {
    await _configurer();
    final points = await _health.getHealthDataFromTypes(
      types: [
        for (final e in _correspondances.entries)
          if (types == null || types.contains(e.value)) e.key,
      ],
      startTime: debut,
      endTime: fin,
    );
    return [for (final p in _health.removeDuplicates(points)) ?_versPoint(p)];
  }

  static PointSante? _versPoint(HealthDataPoint p) {
    final type = _correspondances[p.type];
    if (type == null) return null;
    final valeur = p.value;
    return switch (valeur) {
      // totalEnergyBurned n'est pas lu : c'est la somme de toutes les calories
      // totales (métabolisme de base compris) de toutes les applications sur
      // l'intervalle. Les calories d'une séance viennent des calories actives
      // (voir agregerParJour).
      WorkoutHealthValue() => PointSante(
        type: type,
        debut: p.dateFrom,
        fin: p.dateTo,
        valeur: 0,
        libelle: valeur.workoutActivityType.name,
        source: p.sourceName,
      ),
      NumericHealthValue() => PointSante(
        type: type,
        debut: p.dateFrom,
        fin: p.dateTo,
        valeur: valeur.numericValue.toDouble(),
        source: p.sourceName,
      ),
      _ => null,
    };
  }
}
