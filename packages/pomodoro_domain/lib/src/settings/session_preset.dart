/// One-tap session lengths. Just named values of
/// [GardenSettings.sessionLength], not a separate setting.
enum SessionPreset {
  short(label: 'Short', length: Duration(minutes: 15)),
  classic(label: 'Classic', length: Duration(minutes: 25)),
  deep(label: 'Deep', length: Duration(minutes: 50));

  const SessionPreset({required this.label, required this.length});

  final String label;

  final Duration length;

  /// Null means a custom length.
  static SessionPreset? matching(Duration length) {
    for (final preset in values) {
      if (preset.length == length) return preset;
    }
    return null;
  }
}
