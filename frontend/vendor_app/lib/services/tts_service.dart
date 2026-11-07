import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  late final FlutterTts _tts;
  bool _initialized = false;

  Future<void> init() async {
    _tts = FlutterTts();
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      _initialized = true;
    } catch (_) {
      // TTS engine may not be available on all devices — fail silently
    }
  }

  Future<void> speak(String text) async {
    if (!_initialized) return;
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  /// Announces new order count to vendor
  Future<void> announceNewOrders(int count) async {
    if (count <= 0) return;
    final message = count == 1 ? 'New order received' : 'You have $count new orders';
    await speak(message);
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

