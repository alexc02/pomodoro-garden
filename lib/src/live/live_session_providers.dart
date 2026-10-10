import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'channel_live_session_surface.dart';
import 'live_session.dart';

/// What the app shows a running session through, wherever the user is not
/// looking.
///
/// Read only by `LiveSurfaceKeeper`, and overridden in every widget test — the
/// real one would call across a channel nothing answers on the machine running
/// the suite, and the fake is what makes "would the lock screen be showing
/// this" a question a test can ask.
final liveSessionSurfaceProvider = Provider<LiveSessionSurface>(
  (ref) => ChannelLiveSessionSurface(),
);
