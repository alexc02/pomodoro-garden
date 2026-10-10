import 'package:audio_session/audio_session.dart';

/// What the app's one audio session is currently set up to do.
enum AudioUse {
  /// Nothing is playing but the end-of-session chime, when it comes.
  chimeOnly,

  /// A bed is playing under a focus session, and has to go on playing while
  /// the phone is in a pocket.
  ambientBed,
}

/// The app's single audio session, and the one place that decides its shape.
///
/// **There is one `AVAudioSession` per process and one Android audio focus
/// request per app, so there is exactly one configuration and it cannot belong
/// to a feature.** Ticket 06 set it from what is now `BundledEndSoundPlayer`,
/// because the chime was the only thing playing. Ticket 10 adds a second player
/// with the opposite needs, and two features calling `AudioSession.configure`
/// would leave the app running on whichever configured last — which is a bug
/// that shows up as "the rain stops when the screen locks", on a device, weeks
/// later. So the
/// configuration moved here, and the two players ask for a *use* rather than
/// setting a category.
///
/// The two uses are genuinely opposed, and the line between them is one
/// sentence:
///
/// **The silent switch wins, unless the user has asked for a bed.**
///
/// - [chimeOnly] is ticket 06's decision, unchanged: `ambient`, which is the
///   iOS category the ring switch mutes, and `mixWithOthers`, so a user who
///   focuses to music still has music. A focus app that chimed in a meeting
///   because the user had silenced their phone would have earned every word of
///   the review.
/// - [ambientBed] is `playback`: it ignores the silent switch, it survives the
///   screen locking, and it is the only iOS category that keeps playing while
///   the app is in the background — which is REQ-012's requirement, not a
///   preference. It does *not* mix, and on Android it takes full audio focus,
///   which pauses whatever the user had playing. That is the honest reading of
///   "honour the user's choice when music is already playing": they chose rain
///   over the music, deliberately, from a picker showing what they were
///   choosing. Choosing Silence hands the session straight back to
///   [chimeOnly] and their music with it.
///
/// Playing under `playback` also requires `UIBackgroundModes: audio` in
/// `ios/Runner/Info.plist`. Without it iOS suspends the app on the way to the
/// lock screen and the category makes no difference — see `docs/ambience.md`.
final class AppAudioSession {
  AppAudioSession();

  /// The use the platform session is actually configured for, or null before
  /// anything has configured it. Set only when a configuration lands.
  AudioUse? _configured;

  /// The tail of the configuration queue. See [useFor].
  Future<void> _queue = Future<void>.value();

  /// Configures the platform session for [use], and stays out of the way if it
  /// already is.
  ///
  /// The bed is the only caller: it takes the session when it starts and hands
  /// it back when it stops, which is what makes "the bed owns the category
  /// while it plays" a thing one class does rather than two classes agree on.
  /// The chime asks for [ensureConfigured] instead.
  Future<void> useFor(AudioUse use) => _enqueue(() => _configure(use));

  /// Makes sure the session has been configured for *something*, without taking
  /// it from whatever holds it.
  ///
  /// What the chime asks for, and the asymmetry is the whole point. A chime
  /// that called [useFor] would drop the app back to `ambient` in the middle of
  /// a session with rain playing — silencing the bed on iOS at the first
  /// completion of the app's life, on a device, weeks after anyone looked at
  /// this. A chime does not need the session to be any particular shape; it
  /// needs it not to be unconfigured.
  Future<void> ensureConfigured() => _enqueue(() async {
        if (_configured != null) return;
        await _configure(AudioUse.chimeOnly);
      });

  /// Runs [work] after everything already asked for.
  ///
  /// Serialised rather than fired off, because the callers reach this from
  /// event handlers that do not await each other — a session ending fades the
  /// bed out while the chime is asking to be heard — and two `configure` calls
  /// in flight at once would land in whichever order the platform channel felt
  /// like. Queued, the last one asked for is the last one applied.
  ///
  /// A failure does not poison the queue. A configuration that would not take
  /// is a quieter app, not a broken one, and it must not stop the next one from
  /// being tried.
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

  /// What [use] configures the platform session to.
  ///
  /// Exposed because the two configurations are the whole of REQ-012's
  /// background playback and REQ-008's silent switch, and neither is something
  /// a widget test can observe by playing anything — see
  /// `test/platform/background_audio_test.dart`.
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
      // The category that keeps playing behind a locked screen, and the reason
      // this enum has two values at all.
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      // Not `mixWithOthers`, and not `duckOthers` either. Ducking somebody's
      // album under fifteen seconds of looping rain for two hours is worse
      // than stopping it: they would hear both, quietly, for the whole session.
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      // Full focus, for as long as the session runs: this is the user's
      // foreground audio now, and holding it is what makes a phone call able
      // to take it back and hand it over again.
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      // False, so that Android's "you may carry on quietly" arrives as a duck
      // rather than as a pause. A navigation prompt is three seconds long, and
      // a bed that stopped and restarted around it would make more of the
      // interruption than the interruption did. `BundledAmbience` fades into
      // and out of the duck, so what the user hears is the rain stepping back.
      androidWillPauseWhenDucked: false,
    ),
  };
}
