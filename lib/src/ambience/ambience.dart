import 'package:pomodoro_domain/pomodoro_domain.dart';

/// REQ-012's bed: what is playing under a focus session, if anything.
///
/// A port, for the same reason `EndSoundPlayer` is one — a widget test has no
/// audio device, and a `just_audio` player in one is a plugin call into
/// nothing. Tests swap this through `ambienceProvider` and assert the session
/// had rain under it, which is the part of REQ-012 that is about the app rather
/// than about the speaker.
///
/// **One method, because [AmbientSound.silence] is one of the six.** A separate
/// `stop()` was tried and taken back out: every implementation of it — and the
/// keeper calling it — ended up choosing between the two on `sound == silence`
/// and then doing the same thing either way. The domain already says that
/// choosing quiet is a choice; a port with two entry points would be the one
/// place in the app that disagreed.
///
/// Best-effort by contract, on the same reasoning as `SessionNotifications` and
/// `LiveSessionSurface`: an audio route that will not open changes nothing
/// about whether the session completes, so nothing here may throw at a caller.
abstract interface class Ambience {
  /// Plays [sound] under the session, taking over from whatever was playing,
  /// and takes the bed down for [AmbientSound.silence].
  ///
  /// Called with the same sound twice, the second call does nothing — the bed
  /// is already what was asked for, and reloading it would put a gap in the
  /// thing the ticket is about. That includes silence, which is what lets the
  /// keeper follow one rule — the bed is whatever the session says it is —
  /// without tracking what it last did.
  Future<void> play(AmbientSound sound);
}

/// Where a bed's loop is bundled, or null for the one that is not a file.
///
/// **The only place an ambient asset is named**, the same way
/// `end_sound_player.dart` is the only place the end sounds are named and
/// `PlantSpriteRegistry` is the only place a plant picture is. The five files
/// are placeholders synthesised by
/// `scripts/make_synth_beds.py`; swapping them for the real
/// recordings is dropping five files in and deleting the script.
///
/// **WAV rather than the AAC PRD §5.4 asks for, and the format is the feature.**
/// A lossy codec pads the front of a stream with encoder delay and the back
/// with a partial block, so a player looping an AAC file splices tens of
/// milliseconds of silence into the join — about ten times §4.4's five
/// millisecond budget — unless encoder and player agree on gapless metadata,
/// which ExoPlayer and AVPlayer do not. PCM has nothing to pad, so `LoopMode.one`
/// is sample-accurate on both platforms. See `docs/ambience.md`.
String? ambientLoopAsset(AmbientSound sound) => switch (sound) {
      // Not a file, and deliberately not a file of silence either: a silent
      // loop would hold the audio session open, keep the iOS category on
      // `playback`, and stop the ring switch from winning for the whole of a
      // session the user asked to be quiet.
      AmbientSound.silence => null,
      AmbientSound.rain => 'assets/audio/rain.wav',
      AmbientSound.forest => 'assets/audio/forest.wav',
      AmbientSound.ocean => 'assets/audio/ocean.wav',
      AmbientSound.cafe => 'assets/audio/cafe.wav',
      AmbientSound.whiteNoise => 'assets/audio/white_noise.wav',
    };
