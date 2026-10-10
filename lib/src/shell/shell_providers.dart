import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tab.dart';

/// Which of the four destinations the shell is showing.
///
/// Held here rather than in `AppShell`'s own state because the tab bar stopped
/// being the only thing that chooses: from ticket 08 the user can tap the live
/// surface on their lock screen and expect to arrive at the session it was
/// showing, and whatever hears that tap is nowhere near the shell's `State`.
///
/// Still one selection with one writer per gesture — this is the shell's state,
/// moved somewhere both the bar and the platform can reach it.
final selectedTabProvider =
    NotifierProvider<SelectedTab, AppTab>(SelectedTab.new);

class SelectedTab extends Notifier<AppTab> {
  /// The garden, because PRD §5.1 opens on what the user has grown rather than
  /// on a control they have to be asked to use.
  @override
  AppTab build() => AppTab.garden;

  void select(AppTab tab) => state = tab;
}
