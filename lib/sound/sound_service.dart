import 'package:audioplayers/audioplayers.dart';

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
    } catch (_) {
      // Non-fatal — app works fine without sound.
    }
  }

  void playClick() {
    if (!_ready) return;
    // Seek to start and resume; works even if previous play is mid-way.
    _player.seek(Duration.zero).then((_) => _player.resume());
  }
}
