import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_analytics_event_log.dart';
import 'package:pip_garden/src/data/drift_garden_reset.dart';

/// PRD §7.2's local table: what goes in, what comes back, and what falls off
/// the end.
void main() {
  late AppDatabase database;
  late DriftAnalyticsEventLog log;

  setUp(() {
    database = AppDatabase.forTesting();
    log = DriftAnalyticsEventLog(database);
  });

  tearDown(() => database.close());

  final at = DateTime.utc(2026, 8, 20, 9, 41);

  test('an event comes back with its name, its parameters and its instant',
      () async {
    await log.append(
      const SessionCompleted(duration: Duration(minutes: 25), pausedCount: 2),
      at: at,
    );

    final events = await log.recent();

    expect(events, hasLength(1));
    expect(events.single.name, 'session_completed');
    expect(events.single.known, AnalyticsEventName.sessionCompleted);
    expect(events.single.parameters, {
      'duration_seconds': 1500,
      'paused_count': 2,
    });
    expect(events.single.at, at);
  });

  test('a null parameter survives the round trip', () async {
    // `days_since_last_open` is null on a first open, and a log that turned
    // that into a zero would be claiming the user opened the app yesterday.
    await log.append(
      const AppOpened(daysSinceLastOpen: null, streakDays: 0),
      at: at,
    );

    expect((await log.recent()).single.parameters, {
      'days_since_last_open': null,
      'streak_days': 0,
    });
  });

  test('the newest event is first', () async {
    for (var minute = 0; minute < 3; minute++) {
      await log.append(
        SessionPaused(
          duration: const Duration(minutes: 25),
          pauseCount: minute + 1,
        ),
        at: at.add(Duration(minutes: minute)),
      );
    }

    expect(
      (await log.recent()).map((event) => event.parameters['pause_count']),
      [3, 2, 1],
    );
  });

  test('a clock corrected backwards does not shuffle the log', () async {
    // Recency is the order the rows were written in, not what the clock said at
    // the time — a device whose date was wrong and has been fixed must not
    // reorder events that happened in a known order.
    await log.append(SessionStarted.of(const Duration(minutes: 25)), at: at);
    await log.append(
      SessionStarted.of(const Duration(minutes: 50)),
      at: at.subtract(const Duration(days: 400)),
    );

    expect(
      (await log.recent()).map((event) => event.parameters['duration_seconds']),
      [3000, 1500],
    );
  });

  test('a limit takes the newest, not the oldest', () async {
    for (var index = 0; index < 5; index++) {
      await log.append(
        SessionPaused(duration: const Duration(minutes: 25), pauseCount: index),
        at: at,
      );
    }

    final events = await log.recent(limit: 2);

    expect(events.map((event) => event.parameters['pause_count']), [4, 3]);
  });

  test('the log is bounded: old events are pruned as new ones arrive',
      () async {
    // One more than it holds, so the oldest has to go — and it has to go as
    // part of the write, because nothing in this app runs later to tidy up.
    for (var index = 0; index <= AnalyticsEventLog.maximumEvents; index++) {
      await log.append(
        SessionPaused(duration: const Duration(minutes: 25), pauseCount: index),
        at: at.add(Duration(seconds: index)),
      );
    }

    final events = await log.recent();

    expect(events, hasLength(AnalyticsEventLog.maximumEvents));
    // The newest survived and the very first one did not.
    expect(
      events.first.parameters['pause_count'],
      AnalyticsEventLog.maximumEvents,
    );
    expect(events.last.parameters['pause_count'], 1);
  });

  group('when an event was last recorded', () {
    test('is null when the log has never seen one', () async {
      await log.append(SessionStarted.of(const Duration(minutes: 25)), at: at);

      expect(await log.lastRecordedAt(AnalyticsEventName.appOpened), isNull);
    });

    test('is the most recent of that name, ignoring the others', () async {
      await log.append(
        const AppOpened(daysSinceLastOpen: null, streakDays: 0),
        at: at,
      );
      await log.append(
        SessionStarted.of(const Duration(minutes: 25)),
        at: at.add(const Duration(days: 2)),
      );
      await log.append(
        const AppOpened(daysSinceLastOpen: 1, streakDays: 1),
        at: at.add(const Duration(days: 1)),
      );

      expect(
        await log.lastRecordedAt(AnalyticsEventName.appOpened),
        at.add(const Duration(days: 1)),
      );
    });
  });

  test('a reset empties the log, and the log forgets it had anything',
      () async {
    // REQ-036, from this side of it. Emptying the log is `GardenReset`'s rather
    // than this port's — it happens in the same transaction as the plants and
    // the sessions — so what is asserted here is what the *log* looks like
    // afterwards: not merely empty, but with no last-recorded instant left for
    // the app-open check to read.
    await log.append(SessionStarted.of(const Duration(minutes: 25)), at: at);

    await DriftGardenReset(database).clear();

    expect(await log.recent(), isEmpty);
    expect(
      await log.lastRecordedAt(AnalyticsEventName.sessionStarted),
      isNull,
    );
  });

  test('an unreadable row is skipped rather than taking the read down',
      () async {
    // Not reachable through the port — this is a row written by a build that is
    // not this one. The log is a debugging aid, and one bad row must not be
    // able to stop the app-open check that reads it at launch.
    await database.customStatement(
      'INSERT INTO analytics_events (name, parameters, recorded_at) '
      "VALUES ('session_started', 'not json', 1786000000)",
    );

    final events = await log.recent();

    expect(events, hasLength(1));
    expect(events.single.parameters, isEmpty);
  });
}
