import 'dart:async';

import 'package:pip_garden/src/quiet/quiet_mode.dart';

/// A [QuietMode] that tracks whether the phone is quiet instead of silencing
/// it. Change [reports] mid-test to simulate the user revoking access.
final class FakeQuietMode implements QuietMode {
  FakeQuietMode({this.reports = QuietModeAccess.unavailable});

  QuietModeAccess reports;

  /// Starts loud and unasked; see [everAsked].
  bool quiet = false;

  /// Every `until` asked for, in order. Used to catch re-arming every second.
  final List<DateTime> asks = <DateTime>[];

  int releases = 0;

  /// Tells "never asked" apart from "turned off", e.g. for the launch that
  /// clears a rule left by a process that died mid-session.
  bool everAsked = false;

  int accessRequests = 0;

  final StreamController<void> _requests = StreamController<void>.broadcast();

  @override
  Future<QuietModeAccess> access() async => reports;

  @override
  Future<void> requestAccess() async {
    accessRequests++;
  }

  @override
  Future<void> begin({required DateTime until}) async {
    everAsked = true;
    quiet = true;
    asks.add(until);
  }

  @override
  Future<void> end() async {
    everAsked = true;
    quiet = false;
    releases++;
  }

  @override
  Stream<void> get sessionRequests => _requests.stream;

  /// The user changing access in system settings while the app is away.
  void reportAccess(QuietModeAccess access) => reports = access;

  /// A Shortcuts automation running the app's App Intent.
  void requestSession() => _requests.add(null);

  /// Called from `pumpApp`'s teardown; an open controller keeps the zone alive.
  Future<void> close() => _requests.close();
}
