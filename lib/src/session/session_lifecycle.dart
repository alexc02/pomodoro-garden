import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_providers.dart';

/// Passes app lifecycle events to the session.
///
/// Backgrounding needs nothing (the session runs off the wall clock); resume
/// just repaints, since the ticker was asleep. `detached` means a force-quit,
/// so the session is voided and the next launch won't restore it. See
/// `docs/adr/0004-a-session-outlives-the-app-unless-the-user-quit-it.md` for
/// platforms that don't send it.
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
