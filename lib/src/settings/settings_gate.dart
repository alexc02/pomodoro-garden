import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/opening_frame.dart';
import 'settings_providers.dart';

/// Holds the app back until the stored settings have been read, so
/// `settingsProvider` can be synchronous below here and START can't fire on
/// defaults before SQLite answers.
class SettingsGate extends ConsumerWidget {
  const SettingsGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(settingsControllerProvider).hasValue;
    return loaded ? child : const OpeningFrame();
  }
}
