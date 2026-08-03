/// One-tap break lengths, like [SessionPreset].
///
/// These set the normal break. The long break is still derived (3x, capped),
/// so `long` gives 15 min breaks and 30 min long breaks.
enum BreakPreset {
  short(label: 'Short', length: Duration(minutes: 5)),
  standard(label: 'Standard', length: Duration(minutes: 10)),
  long(label: 'Long', length: Duration(minutes: 15));

  const BreakPreset({required this.label, required this.length});

  final String label;

  final Duration length;

  static BreakPreset? matching(Duration length) {
    for (final preset in values) {
      if (preset.length == length) return preset;
    }
    return null;
  }
}
