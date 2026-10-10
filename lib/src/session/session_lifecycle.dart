import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_providers.dart';

/// Tells the session what the app is doing: coming back, or going away for
/// good.
///
/// Two events, and REQ-013 is the whole of why:
///
/// **Backgrounding is not an interruption.** `inactive`, `hidden` and `paused`
/// are not handled here at all, because there is nothing to do about them — the
/// session is anchored to the wall clock and carries on being however far along
/// it is whether or not anyone is looking. What coming back needs is a repaint,
/// not a recalculation: the ticker has been asleep, so the first frame after a
/// resume would otherwise be however stale the moment of suspension left it.
///
/// **A force-quit is.** `detached` is the platform saying the engine is going
/// away, and it is the one signal that separates "the user threw this session
/// away" from "the app was killed to make room". The session is closed as
/// voided right here, so the next launch finds nothing to restore. See
/// `docs/adr/0005-a-session-outlives-the-app-unless-the-user-quit-it.md` for
/// what happens when a platform does not send it.
class SessionLifecycle extends ConsumerStatefulWidget {
  const SessionLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SessionLifecycle> createState() => _SessionLifecycleState();
}

class _SessionLifecycleState extends ConsumerState<SessionLifecycle> {
  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => ref.read(sessionControllerProvider.notifier).catchUp(),
      onDetach: () =>
          ref.read(sessionControllerProvider.notifier).voidInFlight(),
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
