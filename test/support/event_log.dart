import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_analytics_event_log.dart';

/// Reading PRD §7.1's events back out of the app, for the tests that assert on
/// them.
///
/// Read through the real log rather than through a fake port on purpose: what
/// these tests are about is that an event reached storage with the right
/// parameters, and a fake that collected them in a list would pass with the
/// database wiring broken.

/// Every event the app recorded, oldest first.
///
/// The reverse of what the log hands out, because a test reads in the order the
/// user did things — start, pause, complete — and reversing it there would put
/// the assertion and the story in different directions.
Future<List<LoggedEvent>> recordedEvents(AppDatabase database) async {
  final events = await DriftAnalyticsEventLog(database).recent();
  return events.reversed.toList();
}

/// Every event of [name] the app recorded, oldest first.
Future<List<LoggedEvent>> eventsNamed(
  AppDatabase database,
  AnalyticsEventName name,
) async {
  final events = await recordedEvents(database);
  return events.where((event) => event.known == name).toList();
}

/// The one event of [name] the app recorded, or a failure if there is not
/// exactly one.
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
