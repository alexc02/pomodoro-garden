import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_session_notifications.dart';
import 'session_notifications.dart';

/// Schedules the end-of-session notification for when the app isn't awake.
/// Overridden in widget tests so the suite doesn't post real notifications.
final sessionNotificationsProvider = Provider<SessionNotifications>(
  (ref) => LocalSessionNotifications(),
);
