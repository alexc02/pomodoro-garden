/// Sound played when a session or break ends. Same pattern as `AmbientSound`.
///
/// The thing that plays it is `EndSoundPlayer`. [none] is a real choice, which
/// is why there's no separate on/off toggle.
enum EndSound {
  /// Default.
  windChime('Wind chime'),

  softBell('Soft bell'),

  birdsong('Birdsong'),

  singingBowl('Singing bowl'),

  oceanWave('Ocean wave'),

  /// No sound, but the notification still shows.
  none('None');

  const EndSound(this.label);

  final String label;

  bool get isSilent => this == none;

  /// Falls back to [windChime] for unknown names. Not [none]: that would
  /// silently turn off an upgrading user's sound.
  static EndSound named(String name) => values.firstWhere(
        (sound) => sound.name == name,
        orElse: () => windChime,
      );
}
