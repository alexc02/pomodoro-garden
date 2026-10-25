/// The app's four top-level destinations, in bar order (PRD §5.1).
///
/// Each is drawn by its own `TabGlyph` — the "minimalist line icons" the
/// design language asks for, drawn for this app rather than taken from the
/// Material set (PRD v2.3).
enum AppTab {
  garden(label: 'Garden'),
  timer(label: 'Timer'),
  journal(label: 'Journal'),
  settings(label: 'Settings');

  const AppTab({required this.label});

  /// The tab-bar label, and the placeholder screens' title.
  final String label;
}
