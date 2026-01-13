import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  final AudioPlayer _player = AudioPlayer();

  factory SoundService() {
    return _instance;
  }

  SoundService._internal();

  Future<void> play(String soundName) async {
    try {
      await _player.stop(); // Stop any currently playing sound
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/$soundName'));
    } catch (e) {
      if (kDebugMode) {
        print('Error playing sound $soundName: $e');
      }
    }
  }
}
