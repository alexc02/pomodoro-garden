import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_providers.dart';
import '../settings/settings_providers.dart';
import '../shell/shell_providers.dart';
import '../shell/tab.dart';
import 'live_session.dart';
import 'live_session_providers.dart';

/// Keeps what the lock screen is showing in step with what the timer is doing.
///
/// The third of the three widgets wrapped around the shell, and the division
/// between them is by *what they answer to* rather than by what they touch.
/// `SessionLifecycle` is what the app coming and going does to the session;
/// `SessionAnnouncer` is what a session ending says to the user;
/// this is what a session in flight *looks like* while the user is elsewhere.
///
/// Two rules, and both are about pushing as little as possible:
///
/// **The surface is pushed when what it shows changes, not when the session
/// does.** The session changes every second — that is what a countdown is — and
/// the surface changes about six times in twenty-five minutes: when it starts,
/// four times as the plant grows, and whenever the user holds or resumes it.
/// The platform counts down from `LiveSession.endsAt` on its own, so the rest
/// of the seconds are not ours to redraw. [LiveSession.showsTheSameAs] is where
/// that judgement is written down.
///
/// **Anything that is not a session in flight takes the surface down.** Idle,
/// completed, cancelled, the setting turned off, the app detaching — all of
/// them hide, and hiding what is not there is free, so there is no state
/// machine here beyond "what is showing now".
class LiveSurfaceKeeper extends ConsumerStatefulWidget {
  const LiveSurfaceKeeper({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LiveSurfaceKeeper> createState() => _LiveSurfaceKeeperState();
}

class _LiveSurfaceKeeperState extends ConsumerState<LiveSurfaceKeeper> {
  /// What the surface is showing, as far as this knows. Null when it is down.
  LiveSession? _showing;

  AppLifecycleListener? _listener;
  StreamSubscription<void>? _taps;

  @override
  void initState() {
    super.initState();
    // A force-quit takes the session with it — `SessionLifecycle` voids it —
    // and a surface left standing would be counting down to a session that no
    // longer exists. Best-effort, like every write during teardown: on Android
    // the service dies with the process anyway, and on iOS an activity that
    // outlives its app is exactly what the dismissal policy is for.
    _listener = AppLifecycleListener(onDetach: _hide);

    _taps = ref.read(liveSessionSurfaceProvider).opened.listen(_opened);

    // Once, before anything has changed. `ref.listen` fires on a change and a
    // launch is not one — so without this, a session restored at launch waits
    // for its next tick to be shown, and a session restored *paused* waits
    // forever, because a held session's snapshot does not move until the user
    // touches it.
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
    // Both, because either can change what should be showing: the session by
    // running, the settings by REQ-033's switch. Turning the switch off with a
    // session in flight has to take the surface down there and then, which is
    // the case that would be missed by listening to the session alone.
    ref.listen(sessionControllerProvider, (_, _) => _sync());
    ref.listen(settingsProvider, (_, _) => _sync());
    return widget.child;
  }

  /// Puts the surface where the timer and the settings say it should be.
  void _sync() {
    final wanted = ref.read(settingsProvider).liveSurfaceEnabled
        ? LiveSession.of(ref.read(sessionControllerProvider))
        : null;

    if (wanted == null) {
      _hide();
      return;
    }

    // The push that is not worth making. See the class comment.
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

  /// The user tapped the surface to get back to their session.
  ///
  /// Unconditional, and it does not check that a session is still running: the
  /// surface only exists while one is, and a session that ended between the tap
  /// and this line has left a completed timer on that tab, which is the screen
  /// the user was asking for.
  void _opened(void _) {
    ref.read(selectedTabProvider.notifier).select(AppTab.timer);
  }
}
