import 'package:flutter/material.dart';

/// The app's four top-level destinations, in bar order (PRD §5.1).
///
/// Icons are the outlined Material set, which is the "minimalist line icons"
/// the design language asks for; selection is signalled by colour and weight
/// rather than by switching to a filled glyph, so the bar stays line art
/// throughout.
enum AppTab {
  garden(label: 'Garden', icon: Icons.local_florist_outlined),
  timer(label: 'Timer', icon: Icons.timer_outlined),
  journal(label: 'Journal', icon: Icons.menu_book_outlined),
  settings(label: 'Settings', icon: Icons.settings_outlined);

  const AppTab({required this.label, required this.icon});

  /// The tab-bar label, and the placeholder screens' title.
  final String label;

  final IconData icon;
}
