import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/opening_frame.dart';
import 'session_providers.dart';

/// Holds the app back until we know whether a session was running at last
/// exit, so the timer never flashes idle before jumping to a restored session.
/// Must sit below `SettingsGate`: restoring needs the settings.
class SessionGate extends ConsumerWidget {
  const SessionGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final read = ref.watch(restoredSessionProvider).hasValue &&
        ref.watch(restoredCyclePositionProvider).hasValue;
    return read ? child : const OpeningFrame();
  }
}
