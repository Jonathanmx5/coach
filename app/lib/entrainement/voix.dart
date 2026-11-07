import 'package:flutter_tts/flutter_tts.dart';

/// Annonces vocales de la séance guidée.
abstract class Voix {
  Future<void> dire(String texte);
  Future<void> arreter();
}

class VoixTts implements Voix {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _pret;

  Future<void> _init() => _pret ??= () async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.5);
  }();

  @override
  Future<void> dire(String texte) async {
    try {
      await _init();
      await _tts.speak(texte);
    } catch (_) {
      // Pas de synthèse vocale sur l'appareil : la séance reste lisible.
    }
  }

  @override
  Future<void> arreter() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
