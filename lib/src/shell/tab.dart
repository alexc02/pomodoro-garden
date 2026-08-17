/// The app's four top-level destinations, in bar order.
enum AppTab {
  garden(label: 'Garden'),
  timer(label: 'Timer'),
  journal(label: 'Journal'),
  settings(label: 'Settings');

  const AppTab({required this.label});

  final String label;
}
