import 'package:pomodoro_domain/pomodoro_domain.dart';

/// What is playing under a focus session, if anything. An interface so widget
/// tests can swap it via `ambienceProvider`.
///
/// No separate `stop()`: [AmbientSound.silence] is just another sound.
/// Best-effort; nothing here may throw at a caller.
abstract interface class Ambience {
  /// Plays [sound], replacing whatever was playing, or stops for
  /// [AmbientSound.silence]. A repeat of the current sound is a no-op, so the
  /// loop doesn't restart with a gap.
  Future<void> play(AmbientSound sound);
}

/// The bundled loop for [sound], or null for silence. The only place ambient
/// assets are named. The files are placeholders from
/// `scripts/make_synth_beds.py`.
///
/// WAV, not AAC: AAC's encoder padding puts a gap of tens of ms in every loop
/// on ExoPlayer and AVPlayer. PCM loops sample-accurately with `LoopMode.one`.
/// See `docs/ambience.md`.
String? ambientLoopAsset(AmbientSound sound) => switch (sound) {
      // Not a silent file either: that would hold the audio session open and
      // keep iOS on `playback`, overriding the ring switch.
      AmbientSound.silence => null,
      AmbientSound.rain => 'assets/audio/rain.wav',
      AmbientSound.forest => 'assets/audio/forest.wav',
      AmbientSound.ocean => 'assets/audio/ocean.wav',
      AmbientSound.cafe => 'assets/audio/cafe.wav',
      AmbientSound.whiteNoise => 'assets/audio/white_noise.wav',
    };
