import 'package:audioplayers/audioplayers.dart';

class AudioService {
  late final AudioPlayer _player;
  bool _initialized = false;

  Future<void> init() async {
    _player = AudioPlayer();
    // Set release mode to stop after each play
    await _player.setReleaseMode(ReleaseMode.stop);
    _initialized = true;
  }

  Future<void> playNewOrder() async {
    if (!_initialized) return;
    try {
      // [AUDIO] New order alert chime — alarm stream so it fires in DND
      await _player.play(AssetSource('audio/new_order.mp3'));
    } catch (_) {
      // Audio failure is non-fatal; vibration still fires
    }
  }

  Future<void> playSuccess() async {
    if (!_initialized) return;
    try {
      await _player.play(AssetSource('audio/success.mp3'));
    } catch (_) {}
  }

  Future<void> playUrgent() async {
    if (!_initialized) return;
    try {
      await _player.play(AssetSource('audio/urgent.mp3'));
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

