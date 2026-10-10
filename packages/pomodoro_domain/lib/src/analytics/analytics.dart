import 'analytics_event.dart';

/// Where the app says what happened: PRD §7.1's events, and the one seam
/// between them and whatever records them.
///
/// **This is the port every call site talks to**, and it is deliberately one
/// method with no future on it. A timer that had to await its own analytics
/// would be a timer whose START button waits on a disk, and a call site that
/// could see a failure would be a call site with an opinion about what to do
/// about one. Recording is fire-and-forget by contract: it returns immediately,
/// it never throws, and a write that fails costs a log line rather than the
/// user's action.
///
/// **Nothing behind it leaves the device.** PRD §7.2 makes that a promise rather
/// than a default — no SDK, no network, no account — and the only implementation
/// in the app writes to a table in the same SQLite file everything else is in.
/// The port exists so that a real sink is one class and one provider override
/// later, with no call site re-instrumented; it is not a hedge about the privacy
/// stance.
abstract interface class Analytics {
  /// Records [event]. Returns at once, and never throws.
  void record(AnalyticsEvent event);
}

/// An [Analytics] that drops everything.
///
/// For tests and for any build that wants the call sites without the log — it
/// is what "the port makes the sink swappable" looks like at its simplest.
final class NoAnalytics implements Analytics {
  const NoAnalytics();

  @override
  void record(AnalyticsEvent event) {}
}
