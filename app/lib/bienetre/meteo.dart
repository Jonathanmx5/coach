import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Température maximale prévue aujourd'hui, pour adapter l'hydratation.
abstract class Meteo {
  /// Null si la position est refusée, indisponible ou si le réseau échoue.
  /// Demande l'autorisation de localisation si besoin.
  Future<double?> temperatureMax();
}

/// Open-Meteo (sans clé). La position est arrondie à 0,1° (~10 km) avant
/// l'envoi et n'est jamais enregistrée.
class MeteoOpenMeteo implements Meteo {
  MeteoOpenMeteo([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;
  DateTime? _jour;
  double? _temp;

  @override
  Future<double?> temperatureMax() async {
    final aujourdhui = DateTime.now();
    final cle = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    if (_jour == cle && _temp != null) return _temp;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': position.latitude.toStringAsFixed(1),
        'longitude': position.longitude.toStringAsFixed(1),
        'daily': 'temperature_2m_max',
        'timezone': 'auto',
        'forecast_days': '1',
      });
      final reponse = await _client
          .get(url)
          .timeout(const Duration(seconds: 10));
      if (reponse.statusCode != 200) return null;
      final json = jsonDecode(reponse.body) as Map<String, dynamic>;
      final liste =
          (json['daily'] as Map<String, dynamic>)['temperature_2m_max'] as List;
      _temp = (liste.first as num).toDouble();
      _jour = cle;
      return _temp;
    } catch (_) {
      return null;
    }
  }
}
