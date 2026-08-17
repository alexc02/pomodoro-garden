import 'dart:async';

import 'package:pip_garden/src/live/live_session.dart';

/// A [LiveSessionSurface] that tracks what the lock screen is showing. One
/// surface: show replaces, hide clears.
final class FakeLiveSessionSurface implements LiveSessionSurface {
  /// Every push, in order. Used to catch pushing once a second.
  final List<LiveSession> pushes = <LiveSession>[];

  int hides = 0;

  LiveSession? showing;

  final StreamController<void> _opened = StreamController<void>.broadcast();

  @override
  Future<void> show(LiveSession session) async {
    pushes.add(session);
    showing = session;
  }

  @override
  Future<void> hide() async {
    hides++;
    showing = null;
  }

  @override
  Stream<void> get opened => _opened.stream;

  /// The user tapping the surface on their lock screen.
  void tap() => _opened.add(null);

  /// Called from `pumpApp`'s teardown; an open controller keeps the zone alive.
  Future<void> close() => _opened.close();
}
