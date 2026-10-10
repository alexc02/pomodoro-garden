import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/opening_frame.dart';
import 'settings_providers.dart';

/// Holds the app back until the stored settings have been read.
///
/// One database read, at launch, before anything below can be built. That is
/// what lets `settingsProvider` be a plain synchronous value: every screen
/// under here is guaranteed a real [GardenSettings], so none of them carries a
/// "still loading" branch, and there is no window in which the timer could
/// start a session on last resort's defaults because the user tapped START
/// faster than SQLite answered.
///
/// PRD §4.4 budgets 1.5s from launch to the garden; this spends a query of it,
/// and `SessionGate` below it spends one more.
class SettingsGate extends ConsumerWidget {
  const SettingsGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(settingsControllerProvider).hasValue;
    return loaded ? child : const OpeningFrame();
  }
}
