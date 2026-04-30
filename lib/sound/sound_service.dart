import 'package:audioplayers/audioplayers.dart';
import 'package:hyperion_flutter/logging/app_logger.dart';

/// Plays a short click sound for UI button feedback.
/// Call [init] once in main() before runApp, then hook into
/// the Material splash factory so every InkWell/button tap triggers [playClick].
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;

  Future<void> init() async {
    try {
      // Pre-load asset so first tap has no perceptible delay.
      await _player.setSource(AssetSource('appIcons/buttonClickSound.mp3'));
      await _player.setReleaseMode(ReleaseMode.stop);
      _ready = true;
      AppLogger.log('[SoundService] initialized');
    } catch (e) {
      // Non-fatal — app works fine without sound.
      AppLogger.log('[SoundService] init failed: $e');
    }
  }

  void playClick() {
    if (!_ready) return;
    // Use play() rather than seek+resume.
    // On Windows (and after ReleaseMode.stop on all platforms) the player is
    // in a truly stopped state — resume() won't restart it, but play() will.
    _player.play(AssetSource('appIcons/buttonClickSound.mp3'));
  }
}
