import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../session/session_providers.dart';
import '../settings/settings_providers.dart';
import '../shell/shell_providers.dart';
import '../shell/tab.dart';
import 'quiet_mode.dart';
import 'quiet_mode_providers.dart';

/// Keeps Do Not Disturb in step with the timer.
///
/// - Quiet while a focus session is running or paused; loud otherwise,
///   including breaks.
/// - Only when the setting is on and [QuietModeAccess] is granted, so a
///   revoked permission turns it off on the next resume.
/// - Turned off when the session ends, on force-quit, and on any launch with
///   no session in flight (catches a killed process). The platform deadline
///   covers an app that never comes back.
/// - Also handles [QuietMode.sessionRequests] (iOS Shortcuts), here rather
///   than on the timer screen since they can arrive on any screen or at launch.
class QuietModeKeeper extends ConsumerStatefulWidget {
  const QuietModeKeeper({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<QuietModeKeeper> createState() => _QuietModeKeeperState();
}

class _QuietModeKeeperState extends ConsumerState<QuietModeKeeper> {
  /// Null when loud.
  DateTime? _until;

  /// False until the first call. The first sync always talks to the platform,
  /// so a rule left on by a killed process gets switched off.
  bool _told = false;

  AppLifecycleListener? _listener;
  StreamSubscription<void>? _requests;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      // Access may have changed in system settings while we were away.
      onResume: _accessMayHaveChanged,
      // Force-quit voids the session. Best-effort; the platform deadline is
      // the backstop.
      onDetach: _end,
    );

    _requests = ref.read(quietModeProvider).sessionRequests.listen(_requested);

    // ref.listen won't fire at launch, so sync once now (restored sessions,
    // and clearing a rule left on by a killed process).
    _sync();
  }

  @override
  void dispose() {
    unawaited(_requests?.cancel());
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionControllerProvider, (_, _) => _sync());
    ref.listen(settingsProvider, (_, _) => _sync());
    ref.listen(quietModeAccessProvider, (_, _) => _sync());
    return widget.child;
  }

  void _sync() {
    final wanted = _quietUntil();

    if (wanted == null) {
      _end();
      return;
    }

    // dueAt is constant while running but moves every second while paused;
    // don't re-arm on every tick of a pause.
    if (_told && _until != null && (_held || wanted == _until)) return;

    _until = wanted;
    _told = true;
    unawaited(ref.read(quietModeProvider).begin(until: wanted));
  }

  /// Null if the phone should be loud.
  DateTime? _quietUntil() {
    final settings = ref.read(settingsProvider);
    if (!settings.quietModeEnabled) return null;
    // Still loading, unsupported, or revoked.
    if (ref.read(quietModeAccessProvider).value !=
        QuietModeAccess.granted) {
      return null;
    }

    final snapshot = ref.read(sessionControllerProvider);
    return switch (snapshot.phase) {
      SessionPhase.running || SessionPhase.paused => snapshot.dueAt,
      SessionPhase.idle ||
      SessionPhase.completed ||
      SessionPhase.onBreak ||
      SessionPhase.breakOver =>
        null,
    };
  }

  bool get _held =>
      ref.read(sessionControllerProvider).phase == SessionPhase.paused;

  void _end() {
    if (_told && _until == null) return;

    _until = null;
    _told = true;
    unawaited(ref.read(quietModeProvider).end());
  }

  void _accessMayHaveChanged() {
    unawaited(ref.read(quietModeAccessProvider.notifier).refresh());
  }

  /// A Shortcuts automation asked for a session. Ignored if a session or
  /// break is in flight, so a duplicate trigger is harmless.
  void _requested(void _) {
    const atRest = {
      SessionPhase.idle,
      SessionPhase.completed,
      SessionPhase.breakOver,
    };
    if (!atRest.contains(ref.read(sessionControllerProvider).phase)) return;

    unawaited(ref.read(sessionControllerProvider.notifier).start());
    ref.read(selectedTabProvider.notifier).select(AppTab.timer);
  }
}
