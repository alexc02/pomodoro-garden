import 'package:audio_session/audio_session.dart';

/// What the app's audio session is currently set up for.
enum AudioUse {
  /// Only the end chime and micro-sounds.
  chimeOnly,

  /// An ambient bed is playing and has to keep going with the screen locked.
  ambientBed,
}

/// The app's single audio session config.
///
/// There's one `AVAudioSession` per process and one audio focus per app, so
/// if the chime and the bed each called `AudioSession.configure`, whichever
/// ran last would win (e.g. rain stopping on lock). Players ask for an
/// [AudioUse] instead.
///
/// - [chimeOnly]: iOS `ambient` + `mixWithOthers`, so the ring switch mutes it
///   and the user's music keeps playing.
/// - [ambientBed]: `playback`, the only iOS category that keeps going in the
///   background. Ignores the ring switch, doesn't mix, and takes full focus on
///   Android, pausing other audio. Picking Silence goes back to [chimeOnly].
///
/// `playback` also needs `UIBackgroundModes: audio` in `ios/Runner/Info.plist`;
/// see `docs/ambience.md`.
final class AppAudioSession {
  AppAudioSession();

  /// Null until a configure call has succeeded.
  AudioUse? _configured;

  Future<void> _queue = Future<void>.value();

  /// Switches the session to [use]. Only the bed calls this; everything else
  /// uses [ensureConfigured].
  Future<void> useFor(AudioUse use) => _enqueue(() => _configure(use));

  /// Configures [AudioUse.chimeOnly] only if nothing has configured the
  /// session yet. Calling [useFor] from the chime would flip a playing bed back
  /// to `ambient` and silence it on iOS.
  Future<void> ensureConfigured() => _enqueue(() async {
        if (_configured != null) return;
        await _configure(AudioUse.chimeOnly);
      });

  /// Serialises configure calls so the last one requested is the last one
  /// applied (callers don't await each other). A failure doesn't block later
  /// work.
  Future<void> _enqueue(Future<void> Function() work) {
    final done = _queue.then((_) => work());
    _queue = done.catchError((Object _) {});
    return done;
  }

  Future<void> _configure(AudioUse use) async {
    if (_configured == use) return;

    final session = await AudioSession.instance;
    await session.configure(configurationFor(use));
    _configured = use;
  }

  /// Public so `test/platform/background_audio_test.dart` can check the
  /// configs directly.
  static AudioSessionConfiguration configurationFor(AudioUse use) =>
      _configurations[use]!;

  static const Map<AudioUse, AudioSessionConfiguration> _configurations = {
    AudioUse.chimeOnly: AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.notificationEvent,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ),
    AudioUse.ambientBed: AudioSessionConfiguration(
      // Keeps playing with the screen locked.
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      // No mixing or ducking: hearing both quietly for two hours is worse.
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      // Full focus, so a phone call can take it and hand it back.
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      // So short interruptions (nav prompts) arrive as a duck, not a pause.
      // `BundledAmbience` fades in and out of the duck.
      androidWillPauseWhenDucked: false,
    ),
  };
}
