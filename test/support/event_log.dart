import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_analytics_event_log.dart';

// Reads events back through the real log, so the database wiring is covered
// too.

/// Every event the app recorded, oldest first (the log returns newest first).
Future<List<LoggedEvent>> recordedEvents(AppDatabase database) async {
  final events = await DriftAnalyticsEventLog(database).recent();
  return events.reversed.toList();
}

Future<List<LoggedEvent>> eventsNamed(
  AppDatabase database,
  AnalyticsEventName name,
) async {
  final events = await recordedEvents(database);
  return events.where((event) => event.known == name).toList();
}

/// The single event of [name]; throws if there isn't exactly one.
Future<LoggedEvent> theEventNamed(
  AppDatabase database,
  AnalyticsEventName name,
) async {
  final events = await eventsNamed(database, name);
  if (events.length != 1) {
    throw StateError(
      'Expected one ${name.recorded}, found ${events.length}: $events',
    );
  }
  return events.single;
}
