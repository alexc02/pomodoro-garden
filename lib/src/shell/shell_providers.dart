import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tab.dart';

/// Which tab the shell is showing. Lives in a provider rather than
/// `AppShell`'s state because a tap on the lock-screen surface also switches
/// tabs.
final selectedTabProvider =
    NotifierProvider<SelectedTab, AppTab>(SelectedTab.new);

class SelectedTab extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.garden;

  void select(AppTab tab) => state = tab;
}
