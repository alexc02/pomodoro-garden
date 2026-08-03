import 'analytics_event.dart';

/// The analytics port every call site uses.
///
/// Fire-and-forget: returns immediately and never throws, so nothing waits on
/// a disk write. Nothing leaves the device; the only real implementation
/// writes to a local SQLite table.
abstract interface class Analytics {
  /// Returns immediately, never throws.
  void record(AnalyticsEvent event);
}

/// Drops everything. For tests.
final class NoAnalytics implements Analytics {
  const NoAnalytics();

  @override
  void record(AnalyticsEvent event) {}
}
