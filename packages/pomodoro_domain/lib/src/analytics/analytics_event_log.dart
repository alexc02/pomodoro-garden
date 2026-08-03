import 'analytics_event.dart';

/// A stored event row, read back. Looser than [AnalyticsEvent] so rows from a
/// newer build don't make the reader throw.
final class LoggedEvent {
  const LoggedEvent({
    required this.name,
    required this.parameters,
    required this.at,
  });

  /// Raw stored name; use [known] to map it to [AnalyticsEventName].
  final String name;

  final Map<String, Object?> parameters;

  /// UTC.
  final DateTime at;

  /// Null if this build doesn't know the name.
  AnalyticsEventName? get known => AnalyticsEventName.named(name);

  @override
  String toString() => 'LoggedEvent($name at $at, $parameters)';
}

/// Local event log storage. Separate from [Analytics]: everything records
/// through that, only the debug screen and the app-open check read this.
///
/// No `clear` on purpose. Clearing happens in [GardenReset] so it's in the
/// same transaction as the rest of the garden. Bounded by [maximumEvents],
/// enforced on write.
abstract interface class AnalyticsEventLog {
  /// Older events get dropped. Weeks of normal use, a few tens of KB at most.
  static const int maximumEvents = 500;

  /// Also trims to [maximumEvents].
  Future<void> append(AnalyticsEvent event, {required DateTime at});

  /// Newest first.
  Future<List<LoggedEvent>> recent({int limit = maximumEvents});

  /// Null if never recorded. Used for "days since last open".
  Future<DateTime?> lastRecordedAt(AnalyticsEventName name);
}
