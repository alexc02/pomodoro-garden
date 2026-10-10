import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_session_notifications.dart';
import 'session_notifications.dart';

/// What the app asks to announce a session it will not be awake to announce
/// itself.
///
/// Read only by `SessionAnnouncer`, and overridden in every widget test —
/// scheduling a real notification from a test would be asking the machine
/// running the suite to interrupt whoever is using it.
final sessionNotificationsProvider = Provider<SessionNotifications>(
  (ref) => LocalSessionNotifications(),
);
