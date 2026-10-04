/// The four UI micro-sounds, and the one place their files are named.
///
/// Deliberately a closed set; the app should stay quiet. Not a setting and not
/// in the domain (see [MicroSounds] for why there's no switch).
enum MicroSound {
  /// When the seed lands at the end of the planting drop, with the particle
  /// burst.
  soilSettle('soil_settle'),

  /// At a growth stage change, alongside the haptic. Not affected by the
  /// haptics switch.
  growthShimmer('growth_shimmer'),

  /// Only on START, Pause, Resume, confirmed Cancel and accepting a break.
  ///
  /// Not on skipping a break: `SessionMachine.endBreak` goes to `idle` rather
  /// than `breakOver` so that skipping is silent.
  buttonTap('button_tap'),

  /// When a milestone award card is shown. Not for plot unlocks, which have
  /// nothing on screen.
  unlock('unlock');

  const MicroSound(this.stem);

  /// File name without extension.
  final String stem;

  /// AAC is fine here: these never go to a notification. See
  /// `docs/ambience.md` for the size budget.
  String get asset => 'assets/audio/micro/$stem.m4a';
}

/// Plays the micro-sounds. One interface for all four so tests need one fake.
///
/// No on/off setting: they play on `AudioUse.chimeOnly`, so the ring switch
/// (iOS) or ringer mode (Android) silences them. `EndSound.none` only covers
/// the session-end sound. `test/feedback/micro_sounds_test.dart` checks this.
///
/// Never plays while the app is in the background. Taps and animations get
/// that for free; `MilestoneKeeper` guards `MicroSound.unlock`.
abstract interface class MicroSounds {
  /// Returns once the sound has started, not finished.
  Future<void> play(MicroSound sound);
}
