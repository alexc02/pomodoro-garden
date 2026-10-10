import 'package:pomodoro_domain/pomodoro_domain.dart';

/// REQ-031's end-of-session sound, played — and the one place the audio files
/// are named.
///
/// A port, for the same reason the repositories are: a widget test has no audio
/// device and a `just_audio` player in one would be a plugin call into nothing.
/// Tests swap this for a fake through `endSoundPlayerProvider` and assert which
/// sound the session made, which is the part of REQ-031 that is about the app
/// rather than about the speaker.
///
/// **The name.** This was `EndSound` until ticket 25, when the domain needed
/// that word for the *choice*. The pair now reads the way `AmbientSound` and
/// `Ambience` already do: the user picks a sound, the player plays it. See
/// `CONTEXT.md` under **End sound** and **Chime**.
abstract interface class EndSoundPlayer {
  /// Plays [sound], from the beginning, without waiting for it to finish.
  ///
  /// Returns when the sound has *started*. Nothing the user does next depends
  /// on four seconds of wind chime having run out, and a caller that awaited
  /// the whole thing would be holding a completion up for it.
  ///
  /// [EndSound.none] plays nothing, and plays nothing *quietly*: it does not
  /// open an audio session or take audio focus to do it.
  Future<void> play(EndSound sound);
}

/// The stem both copies of [sound] are written under, or null for the one
/// choice that is not a file.
///
/// One function behind all three names below because
/// `scripts/make_synth_end_sounds.py` writes all three from this same stem,
/// and a fourth place to keep them in step is a fourth place to get them out of
/// step. The real recordings from PRD §9.2 arrive under the same names.
///
/// [EndSound.none] is not a file, and deliberately not a file of silence
/// either — the same decision `ambientLoopAsset` makes about
/// `AmbientSound.silence`. A silent file would still open an audio session,
/// still hold the iOS category, and would still be a sound as far as a
/// notification channel is concerned.
String? _stem(EndSound sound) => switch (sound) {
      EndSound.none => null,
      EndSound.windChime => 'wind_chime',
      EndSound.softBell => 'soft_bell',
      EndSound.birdsong => 'birdsong',
      EndSound.singingBowl => 'singing_bowl',
      EndSound.oceanWave => 'ocean_wave',
    };

/// The bundled asset [sound] is played from in the foreground, or null for
/// [EndSound.none].
///
/// **16-bit PCM WAV, not the AAC §5.4 asks for**, and that is iOS's rule rather
/// than a preference: this same file is copied into the app container's
/// `Library/Sounds`, and `UNNotificationSound` takes only PCM, IMA/ADPCM, µLaw
/// and aLaw. An AAC end sound would play in the app and fall back to the
/// system default on the notification, which is the half of REQ-031 nobody
/// would notice was broken. The Android copy, which has no such rule, *is* AAC.
/// `docs/ambience.md` has the arithmetic that makes this matter.
String? endSoundAsset(EndSound sound) {
  final stem = _stem(sound);
  return stem == null ? null : 'assets/audio/end/$stem.wav';
}

/// The same sound as an Android raw resource, named without its extension.
///
/// Android will not take a notification sound from a Flutter asset — a channel
/// wants a resource URI — so every sound exists a second time under
/// `android/app/src/main/res/raw/`, written by the same script so the two
/// cannot drift apart. That copy is AAC: it is only ever a channel's sound, and
/// nothing about a one-shot needs it to be lossless.
String? endSoundAndroidResource(EndSound sound) => _stem(sound);

/// The same sound again on iOS, by the name it is installed under in the app
/// container's `Library/Sounds`.
///
/// `UNNotificationSound` looks in the main bundle and in `Library/Sounds`, and
/// Flutter's assets are in neither — they live inside `App.framework`. Copying
/// the asset into `Library/Sounds` on first use is what makes a scheduled
/// notification able to play it, and it keeps the sounds out of the Xcode
/// project, where a later ticket regenerating the iOS folder would lose them.
String? endSoundIosSound(EndSound sound) {
  final stem = _stem(sound);
  return stem == null ? null : '$stem.wav';
}
