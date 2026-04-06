import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton audio manager for Phantom Crew.
///
/// Handles ambient background music and sound effects.
/// Volume settings are persisted to SharedPreferences.
class AudioManager {
  AudioManager._();
  static final instance = AudioManager._();

  double _musicVolume = 0.5;
  double _sfxVolume = 0.8;
  bool _initialized = false;

  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  /// Load saved volume preferences.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _musicVolume = prefs.getDouble('musicVolume') ?? 0.5;
    _sfxVolume = prefs.getDouble('sfxVolume') ?? 0.8;
  }

  Future<void> setMusicVolume(double v) async {
    _musicVolume = v.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('musicVolume', _musicVolume);
    // Update any currently playing BGM
    FlameAudio.bgm.audioPlayer.setVolume(_musicVolume);
  }

  Future<void> setSfxVolume(double v) async {
    _sfxVolume = v.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sfxVolume', _sfxVolume);
  }

  // ── Background music ──────────────────────────────────────────────────

  Future<void> playMenuMusic() async => _playBgm('music/menu_ambient.mp3');
  Future<void> playGameMusic() async => _playBgm('music/game_ambient.mp3');
  Future<void> playMeetingMusic() async => _playBgm('music/meeting_tension.mp3');

  Future<void> stopMusic() async {
    FlameAudio.bgm.stop();
  }

  Future<void> _playBgm(String file) async {
    try {
      FlameAudio.bgm.stop();
      FlameAudio.bgm.play(file, volume: _musicVolume);
    } catch (_) {
      // Audio file may not exist yet — fail silently during development.
    }
  }

  // ── Sound effects ─────────────────────────────────────────────────────

  void playKill() => _playSfx('sfx/kill_whoosh.mp3');
  void playVentEnter() => _playSfx('sfx/vent_hiss.mp3');
  void playVentExit() => _playSfx('sfx/vent_hiss.mp3');
  void playSabotageAlarm() => _playSfx('sfx/sabotage_alarm.mp3');
  void playMeetingBell() => _playSfx('sfx/meeting_bell.mp3');
  void playVoteCast() => _playSfx('sfx/vote_cast.mp3');
  void playTaskComplete() => _playSfx('sfx/task_complete.mp3');
  void playFootstep() => _playSfx('sfx/footstep.mp3');
  void playEject() => _playSfx('sfx/eject.mp3');

  void _playSfx(String file) {
    try {
      FlameAudio.play(file, volume: _sfxVolume);
    } catch (_) {
      // Audio file may not exist yet — fail silently during development.
    }
  }
}
