import 'dart:async';

import 'package:pomodoro_garden/src/quiet/quiet_mode.dart';

/// A [QuietMode] that remembers how quiet the phone is instead of silencing
/// one.
///
/// Models the platform rather than counting calls, for the same reason
/// `FakeLiveSessionSurface` does: every one of ticket 11's criteria is about
/// *whether the phone is quiet right now* — when a session starts, when it is
/// cancelled, when the app is force-quit, when the permission is taken away —
/// and [quiet] is what answers all of them. [asks] is what catches the failure
/// [quiet] cannot: a rule re-armed once a second for the whole of a pause.
///
/// [reports] is the platform's own answer about what it can do, and changing it
/// mid-test is the user walking off to system settings and revoking the
/// permission — which is the only way that failure can be staged here.
final class FakeQuietMode implements QuietMode {
  FakeQuietMode({this.reports = QuietModeAccess.unavailable});

  /// What the platform says it can do. Public because a test changes it
  /// through [reportAccess], which is the user in system settings.
  QuietModeAccess reports;

  /// Whether the phone is quiet right now.
  ///
  /// Starts loud, and starts *unasked*: [everAsked] is what tells the two apart
  /// for the launch that has to switch off a rule left behind by a process that
  /// died mid-session.
  bool quiet = false;

  /// Every instant quiet mode has been asked to hold until, in order. Its
  /// length is how the "asked once a second" failure is caught.
  final List<DateTime> asks = <DateTime>[];

  /// How many times the phone has been let make noise again.
  int releases = 0;

  /// Whether anything has been asked of this at all.
  bool everAsked = false;

  /// How many times the user has been sent to grant the permission.
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

  /// The user granting or revoking notification policy access, which they can
  /// only do from system settings — so it happens while the app is away, and
  /// the app finds out when it comes back.
  void reportAccess(QuietModeAccess access) => reports = access;

  /// A Shortcuts automation running the app's App Intent.
  void requestSession() => _requests.add(null);

  /// Called by `pumpApp`'s teardown. A broadcast controller with a listener
  /// left open keeps the test's zone alive.
  Future<void> close() => _requests.close();
}
