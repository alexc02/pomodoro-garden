/// The app's five top-level destinations, in bar order.
enum AppTab {
  garden(label: 'Garden'),
  shelf(label: 'Shelf'),
  timer(label: 'Timer'),
  journal(label: 'Journal'),
  settings(label: 'Settings');

  const AppTab({required this.label});

  final String label;
}
