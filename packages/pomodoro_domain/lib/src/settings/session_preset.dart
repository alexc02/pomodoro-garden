/// The one-tap session lengths of REQ-006.
///
/// A preset is not a fourth kind of setting: it is a session length with a name
/// on it. Tapping one sets the same [GardenSettings.sessionLength] the custom
/// control sets, and every preset length is reachable from that control too —
/// so the two are one setting with two ways in, never two settings that can
/// disagree.
enum SessionPreset {
  short(label: 'Short', length: Duration(minutes: 15)),
  classic(label: 'Classic', length: Duration(minutes: 25)),
  deep(label: 'Deep', length: Duration(minutes: 50));

  const SessionPreset({required this.label, required this.length});

  /// The preset's name, as REQ-006 words it.
  final String label;

  final Duration length;

  /// The preset that is exactly [length], or null when the length is one no
  /// preset names — which is what "custom" means.
  static SessionPreset? matching(Duration length) {
    for (final preset in values) {
      if (preset.length == length) return preset;
    }
    return null;
  }
}
