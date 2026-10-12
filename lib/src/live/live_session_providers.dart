import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'channel_live_session_surface.dart';
import 'live_session.dart';

/// Lock screen / ongoing-notification surface for a running session.
/// Overridden in widget tests (nothing answers the channel there).
final liveSessionSurfaceProvider = Provider<LiveSessionSurface>(
  (ref) => ChannelLiveSessionSurface(),
);
