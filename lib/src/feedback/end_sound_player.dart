import 'package:pomodoro_domain/pomodoro_domain.dart';

/// Plays the end-of-session sound. An interface so widget tests can swap it
/// via `endSoundPlayerProvider`.
abstract interface class EndSoundPlayer {
  /// Plays [sound] from the start and returns once it has started, not
  /// finished. [EndSound.none] does nothing (no audio session, no focus).
  Future<void> play(EndSound sound);
}

/// Shared file stem for all three copies of [sound], or null for
/// [EndSound.none]. `scripts/make_synth_end_sounds.py` writes all three from
/// it.
///
/// No silent file for none: it would still open an audio session and still
/// count as a sound to a notification channel.
String? _stem(EndSound sound) => switch (sound) {
      EndSound.none => null,
      EndSound.windChime => 'wind_chime',
      EndSound.softBell => 'soft_bell',
      EndSound.birdsong => 'birdsong',
      EndSound.singingBowl => 'singing_bowl',
      EndSound.oceanWave => 'ocean_wave',
    };

/// Foreground asset for [sound].
///
/// 16-bit PCM WAV, not AAC, because the same file is copied to iOS
/// `Library/Sounds` and `UNNotificationSound` only takes PCM, IMA/ADPCM, µLaw
/// and aLaw. An AAC file would silently fall back to the system sound.
String? endSoundAsset(EndSound sound) {
  final stem = _stem(sound);
  return stem == null ? null : 'assets/audio/end/$stem.wav';
}

/// Android raw resource name (no extension). Channels need a resource URI, not
/// a Flutter asset, so each sound is duplicated as AAC under
/// `android/app/src/main/res/raw/`.
String? endSoundAndroidResource(EndSound sound) => _stem(sound);

/// iOS file name in the app container's `Library/Sounds`.
///
/// `UNNotificationSound` can't see Flutter assets (they're inside
/// `App.framework`), so the asset is copied there on first use. Keeps the
/// sounds out of the Xcode project too.
String? endSoundIosSound(EndSound sound) {
  final stem = _stem(sound);
  return stem == null ? null : '$stem.wav';
}
