import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _bgmPlayer.onPlayerStateChanged.listen((state) {
      isPlayingNotifier.value = (state == PlayerState.playing);
    });
    // Pre-load SFX for Web so we don't have to load them on every click
    _sfxCorrect.setSource(AssetSource('taip.mp3'));
    _sfxIncorrect.setSource(AssetSource('ne.mp3'));
    _sfxChampion.setSource(AssetSource('cemp.mp3'));
  }

  final AudioPlayer _bgmPlayer = AudioPlayer();
  
  final AudioPlayer _sfxCorrect = AudioPlayer()..setReleaseMode(ReleaseMode.stop)..setVolume(1.0);
  final AudioPlayer _sfxIncorrect = AudioPlayer()..setReleaseMode(ReleaseMode.stop)..setVolume(1.0);
  final AudioPlayer _sfxChampion = AudioPlayer()..setReleaseMode(ReleaseMode.stop)..setVolume(1.0);

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  bool _hasAttemptedAutoPlay = false;

  Future<void> autoPlayOnce() async {
    if (_hasAttemptedAutoPlay) return;
    _hasAttemptedAutoPlay = true;
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.2); 
      // Some browsers don't throw exceptions, they just silently fail or log.
      await _bgmPlayer.resume(); // Trying to resume first
      if (_bgmPlayer.state != PlayerState.playing) {
        await _bgmPlayer.play(AssetSource('pirmas.mp3'));
      }
    } catch (e) {
      print('Auto-play blocked or failed: $e');
    }
  }

  Future<void> playBackgroundMusic() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.2); 
      await _bgmPlayer.play(AssetSource('pirmas.mp3'));
    } catch (e) {
      print('Error playing background music: $e');
    }
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      print('Error stopping background music: $e');
    }
  }

  Future<void> pauseBackgroundMusic() async {
    try {
      await _bgmPlayer.pause();
    } catch (e) {
      print('Error pausing background music: $e');
    }
  }

  Future<void> toggleBackgroundMusic() async {
    if (isPlayingNotifier.value) {
      await pauseBackgroundMusic();
    } else {
      await playBackgroundMusic();
    }
  }

  // --- SOUND EFFECTS (SFX) ---
  // SFX are played independently of the BGM toggle. They don't loop.

  Future<void> playCorrectSound() async {
    try {
      await _sfxCorrect.stop();
      await _sfxCorrect.resume();
    } catch (e) {
      print('Error playing correct sound: $e');
    }
  }

  Future<void> playIncorrectSound() async {
    try {
      await _sfxIncorrect.stop();
      await _sfxIncorrect.resume();
    } catch (e) {
      print('Error playing incorrect sound: $e');
    }
  }

  Future<void> playChampionSound() async {
    try {
      await _sfxChampion.stop();
      await _sfxChampion.resume();
    } catch (e) {
      print('Error playing champion sound: $e');
    }
  }
}

final audioService = AudioService();

