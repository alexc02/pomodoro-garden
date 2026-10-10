/// REQ-031's six end-of-session sounds: what the user has chosen to hear at
/// the moment a session or a break runs out.
///
/// Shaped exactly like `AmbientSound` and for the same reasons — a small set of
/// named choices, stored as text, defaulted, and read back through a [named]
/// that survives a value this build has never heard of. It lives in the domain
/// rather than beside the player because what hangs off it is a rule about
/// which sound is the user's, not a fact about decoding a file.
///
/// **The name was contested.** `EndSound` was the port that *plays* the sound
/// until this ticket; that is now `EndSoundPlayer`, and the word is free for
/// the choice. The pair reads the way `AmbientSound` and `Ambience` already do:
/// the user picks a *sound*, the *player* plays it. See `CONTEXT.md` under
/// **End sound** and **Chime**.
///
/// [none] is one of the six rather than the absence of the other five, on the
/// same reasoning `AmbientSound.silence` is: a user who wants no sound has
/// chosen something, and it is stored and defaulted like any other value. It is
/// also why there is no separate on/off switch beside this — see
/// `GardenSettings.endSound`.
enum EndSound {
  /// REQ-008's default, and what every install and every upgrade starts on.
  windChime('Wind chime'),

  softBell('Soft bell'),

  birdsong('Birdsong'),

  singingBowl('Singing bowl'),

  oceanWave('Ocean wave'),

  /// Silent in front of the user and silent on the notification — and the
  /// notification still *appears*. The announcement is the news, not the noise.
  none('None');

  const EndSound(this.label);

  /// What the picker calls this sound.
  final String label;

  /// Whether choosing this is choosing to hear nothing.
  ///
  /// A question rather than four `== EndSound.none` comparisons scattered
  /// across the player, the picker and both platforms' notification dressing.
  /// It is the same question every time — *is there a sound here* — and the
  /// enum is where it should be answered, in the same way `AmbientSound` lets
  /// `ambientLoopAsset` answer "is there a file here" by returning null.
  bool get isSilent => this == none;

  /// The sound called [name], or [windChime] if this build has never heard of
  /// it.
  ///
  /// Falls back rather than throwing, for the reason `AmbientSound.named` does:
  /// the name arrives from a stored row, and a row written by a build that
  /// offered a sound this one does not is a row to read as best it can be read.
  /// The wind chime is the answer that cannot be wrong here — unlike the beds,
  /// where the safe reading is silence, this sound is the one the app has made
  /// since ticket 06 and the one an upgrading user is already used to. Reading
  /// an unknown row as [none] would quietly turn somebody's completion sound
  /// off.
  static EndSound named(String name) => values.firstWhere(
        (sound) => sound.name == name,
        orElse: () => windChime,
      );
}
