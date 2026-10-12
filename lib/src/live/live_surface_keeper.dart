import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_providers.dart';
import '../settings/settings_providers.dart';
import '../shell/shell_providers.dart';
import '../shell/tab.dart';
import 'live_session.dart';
import 'live_session_providers.dart';

/// Keeps the lock-screen surface in step with the timer.
///
/// Only pushes when what's shown changes (start, stage change, pause/resume),
/// not every second; the platform counts down from `LiveSession.endsAt` itself.
/// See [LiveSession.showsTheSameAs]. Anything other than a session in flight
/// (or the setting off) hides it.
class LiveSurfaceKeeper extends ConsumerStatefulWidget {
  const LiveSurfaceKeeper({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LiveSurfaceKeeper> createState() => _LiveSurfaceKeeperState();
}

class _LiveSurfaceKeeperState extends ConsumerState<LiveSurfaceKeeper> {
  /// Null when hidden.
  LiveSession? _showing;

  AppLifecycleListener? _listener;
  StreamSubscription<void>? _taps;

  @override
  void initState() {
    super.initState();
    // Force-quit voids the session. Best-effort: the Android service dies with
    // the process anyway, and iOS has the dismissal policy as a backstop.
    _listener = AppLifecycleListener(onDetach: _hide);

    _taps = ref.read(liveSessionSurfaceProvider).opened.listen(_opened);

    // ref.listen won't fire for a session restored at launch (and a paused
    // one never ticks), so sync once now.
    _sync();
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Settings too: switching the surface off mid-session must hide it now.
    ref.listen(sessionControllerProvider, (_, _) => _sync());
    ref.listen(settingsProvider, (_, _) => _sync());
    return widget.child;
  }

  void _sync() {
    final wanted = ref.read(settingsProvider).liveSurfaceEnabled
        ? LiveSession.of(ref.read(sessionControllerProvider))
        : null;

    if (wanted == null) {
      _hide();
      return;
    }

    if (_showing case final showing? when showing.showsTheSameAs(wanted)) {
      return;
    }

    _showing = wanted;
    unawaited(ref.read(liveSessionSurfaceProvider).show(wanted));
  }

  void _hide() {
    if (_showing == null) return;

    _showing = null;
    unawaited(ref.read(liveSessionSurfaceProvider).hide());
  }

  /// Tap on the surface. No session check: if it just ended, the timer tab
  /// still shows the completed session, which is what they want.
  void _opened(void _) {
    ref.read(selectedTabProvider.notifier).select(AppTab.timer);
  }
}
