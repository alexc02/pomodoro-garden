/// The one-tap break lengths of REQ-007.
///
/// The same bargain [SessionPreset] makes for a session: a preset is a break
/// length with a name on it, not a setting of its own. Tapping one sets the same
/// [GardenSettings.breakLength] the slider sets, and every preset length is
/// reachable from that slider too.
///
/// They set the **ordinary** break. The long break is still derived from it —
/// three times as long, capped at the top of the range — so picking *Long*
/// gives a fifteen-minute break and a thirty-minute long break. The name is
/// REQ-007's, and it describes the break, not the long break.
enum BreakPreset {
  short(label: 'Short', length: Duration(minutes: 5)),
  standard(label: 'Standard', length: Duration(minutes: 10)),
  long(label: 'Long', length: Duration(minutes: 15));

  const BreakPreset({required this.label, required this.length});

  /// The preset's name, as REQ-007 words it.
  final String label;

  final Duration length;

  /// The preset that is exactly [length], or null when the length is one no
  /// preset names.
  static BreakPreset? matching(Duration length) {
    for (final preset in values) {
      if (preset.length == length) return preset;
    }
    return null;
  }
}
