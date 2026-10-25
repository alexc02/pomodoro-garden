import 'dart:async';

import 'package:pip_garden/src/live/live_session.dart';

/// A [LiveSessionSurface] that remembers what the lock screen was asked to
/// show.
///
/// Models the platform rather than merely counting calls, for the same reason
/// `FakeSessionNotifications` does: there is one surface, showing replaces
/// whatever was on it, and hiding takes it down. That is what makes [showing] a
/// fair answer to "would the user see their session on their lock screen right
/// now" — the question the whole ticket is about, and one no `Finder` can ask.
final class FakeLiveSessionSurface implements LiveSessionSurface {
  /// Every push, in order, taken down or not. The length of this is how the
  /// "pushed once a second" failure is caught.
  final List<LiveSession> pushes = <LiveSession>[];

  /// How many times the surface has been taken down.
  int hides = 0;

  /// What is on the lock screen, or null if nothing is.
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

  /// Called by `pumpApp`'s teardown. A broadcast controller with a listener
  /// left open keeps the test's zone alive.
  Future<void> close() => _opened.close();
}
