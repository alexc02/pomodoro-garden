import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/opening_frame.dart';
import 'session_providers.dart';

/// Holds the app back until storage has said whether a session was still
/// running when the app was last here.
///
/// The same bargain `SettingsGate` makes, for the same reason: below this gate
/// `sessionControllerProvider` is a plain synchronous value, so no screen
/// carries a "still finding out whether you are in a session" branch — and,
/// more to the point, there is no window in which the timer reads as idle to a
/// user who is in fact eleven minutes into a session. A timer that showed
/// **Ready to focus** for two frames and then jumped to 14:00 would be worse
/// than one that took two frames to open.
///
/// It has to sit *below* `SettingsGate`: what the restored session is worth is
/// decided against settings that are already in hand.
class SessionGate extends ConsumerWidget {
  const SessionGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final read = ref.watch(restoredSessionProvider).hasValue;
    return read ? child : const OpeningFrame();
  }
}
