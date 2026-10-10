import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_journal_repository.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/data/drift_session_repository.dart';

/// The journal's figures, against a real SQLite database in memory.
///
/// Every one of them is an aggregate, and the point of testing them here rather
/// than against a fake is that the arithmetic is SQLite's: the day a session
/// falls on is decided by `date(…, 'localtime')` in the query, and only a real
/// database can be asked whether it agrees with the Dart that computed the
/// range.
void main() {
  late AppDatabase database;
  late DriftSessionRepository sessions;
  late DriftPlantRepository garden;
  late JournalRepository journal;

  setUp(() {
    database = AppDatabase.forTesting();
    sessions = DriftSessionRepository(database);
    garden = DriftPlantRepository(database);
    journal = DriftJournalRepository(database);
  });

  tearDown(() => database.close());

  /// Records a session anchored at [local] on the device's own clock.
  ///
  /// Local rather than UTC on purpose: what the journal has to get right is the
  /// day the *user* was working, so every fixture here is written the way the
  /// user experienced it and stored the way ADR 0001 requires.
  Future<FocusSession> complete(
    DateTime local, {
    Duration length = const Duration(minutes: 25),
    String? id,
  }) async {
    final anchor = local.toUtc();
    final session = FocusSession(
      id: id ?? 'session-${anchor.microsecondsSinceEpoch}',
      startedAt: anchor,
      plannedDuration: length,
    ).completedAt(anchor.add(length));
    await sessions.save(session);
    return session;
  }

  /// Records a session that was started and never completed.
  Future<void> abandon(DateTime local) async {
    final anchor = local.toUtc();
    await sessions.save(FocusSession(
      id: 'cancelled-${anchor.microsecondsSinceEpoch}',
      startedAt: anchor,
      plannedDuration: const Duration(minutes: 25),
    ).cancelledAt(anchor.add(const Duration(minutes: 5))));
  }

  /// Plants what [session] grew.
  Future<void> plant(FocusSession session, {GardenPlot? plot}) => garden.save(
        Plant.fromSession(session, id: 'plant-${session.id}', plot: plot),
      );

  final week = DayRange.week(
    const CalendarDay(2026, 8, 11),
    firstDayOfWeek: DateTime.monday,
  );

  group('what a span of days came to', () {
    test('counts the completed sessions in it and adds up their lengths',
        () async {
      await complete(DateTime(2026, 8, 10, 9), length: const Duration(minutes: 25));
      await complete(DateTime(2026, 8, 11, 14), length: const Duration(minutes: 50));
      await complete(DateTime(2026, 8, 16, 20), length: const Duration(minutes: 15));

      expect(
        await journal.sessionsIn(week),
        const SessionTally(sessions: 3, focus: Duration(minutes: 90)),
      );
    });

    test('leaves out the sessions nobody finished', () async {
      await complete(DateTime(2026, 8, 11, 9));
      await abandon(DateTime(2026, 8, 11, 11));
      // In flight: started, never ended.
      await sessions.save(FocusSession(
        id: 'running',
        startedAt: DateTime(2026, 8, 11, 15).toUtc(),
        plannedDuration: const Duration(minutes: 25),
      ));

      expect(
        await journal.sessionsIn(week),
        const SessionTally(sessions: 1, focus: Duration(minutes: 25)),
      );
    });

    test('is nothing at all for a span with nothing in it', () async {
      expect(await journal.sessionsIn(week), SessionTally.none);
      expect(await journal.sessionsEver(), SessionTally.none);
    });

    test('takes the first day whole and stops before the day after the last',
        () async {
      // The four instants that decide whether a range is half open, all in
      // local time because that is where the boundary is.
      await complete(DateTime(2026, 8, 9, 23, 59, 59), id: 'the-night-before');
      await complete(DateTime(2026, 8, 10), id: 'first-midnight');
      await complete(DateTime(2026, 8, 16, 23, 59, 59), id: 'last-moment');
      await complete(DateTime(2026, 8, 17), id: 'next-midnight');

      expect((await journal.sessionsIn(week)).sessions, 2);
      expect((await journal.sessionsEver()).sessions, 4);
    });

    test('adds up every session ever completed, whenever it was', () async {
      await complete(DateTime(2019, 1, 2, 8), length: const Duration(hours: 2));
      await complete(DateTime(2026, 8, 11, 8), length: const Duration(hours: 1));

      expect(
        await journal.sessionsEver(),
        const SessionTally(sessions: 2, focus: Duration(hours: 3)),
      );
    });
  });

  group('the day a session belongs to', () {
    test('is the day it was anchored, not the day it ended', () async {
      // Ten to midnight, finishing twenty past: ADR 0012's case, and the one
      // the user remembers as Monday evening.
      await complete(
        DateTime(2026, 8, 10, 23, 50),
        length: const Duration(minutes: 30),
      );

      expect(await journal.sessionsByDay(week), {const CalendarDay(2026, 8, 10): 1});
      expect(await journal.daysWithSessions(), [const CalendarDay(2026, 8, 10)]);
    });

    test('is the local day, so an evening session is never the next morning',
        () async {
      await complete(DateTime(2026, 8, 11, 22, 30));
      await complete(DateTime(2026, 8, 11, 23, 30));

      expect(await journal.sessionsByDay(week), {const CalendarDay(2026, 8, 11): 2});
    });
  });

  group('the month, day by day', () {
    test('counts each day and leaves the empty ones out', () async {
      await complete(DateTime(2026, 8, 3, 9));
      await complete(DateTime(2026, 8, 3, 11));
      await complete(DateTime(2026, 8, 11, 9));

      expect(await journal.sessionsByDay(DayRange.month(const CalendarDay(2026, 8, 11))), {
        const CalendarDay(2026, 8, 3): 2,
        const CalendarDay(2026, 8, 11): 1,
      });
    });

    test('holds nothing from the months either side of it', () async {
      await complete(DateTime(2026, 7, 31, 23));
      await complete(DateTime(2026, 8, 1, 1));
      await complete(DateTime(2026, 9, 1, 1));

      expect(await journal.sessionsByDay(DayRange.month(const CalendarDay(2026, 8, 11))), {
        const CalendarDay(2026, 8, 1): 1,
      });
    });

    test('does not count a session nobody finished as a day tended', () async {
      await abandon(DateTime(2026, 8, 4, 9));

      expect(await journal.sessionsByDay(DayRange.month(const CalendarDay(2026, 8, 11))), isEmpty);
    });
  });

  group('the days a garden was tended', () {
    test('are distinct days, most recent first', () async {
      await complete(DateTime(2026, 8, 9, 9));
      await complete(DateTime(2026, 8, 11, 9));
      await complete(DateTime(2026, 8, 11, 13));
      await complete(DateTime(2026, 8, 10, 20));

      expect(await journal.daysWithSessions(), const [
        CalendarDay(2026, 8, 11),
        CalendarDay(2026, 8, 10),
        CalendarDay(2026, 8, 9),
      ]);
    });

    test('reach back as far as the history goes', () async {
      await complete(DateTime(2019, 3, 1, 9));
      await complete(DateTime(2026, 8, 11, 9));

      expect(await journal.daysWithSessions(), const [
        CalendarDay(2026, 8, 11),
        CalendarDay(2019, 3, 1),
      ]);
    });

    test('are empty for a user who has never finished one', () async {
      await abandon(DateTime(2026, 8, 11, 9));

      expect(await journal.daysWithSessions(), isEmpty);
    });
  });

  group('the plants a span grew', () {
    test('are the ones planted in it, most recent first', () async {
      await plant(await complete(DateTime(2026, 8, 10, 9)),
          plot: const GardenPlot(0, 0));
      await plant(await complete(DateTime(2026, 8, 12, 9)),
          plot: const GardenPlot(1, 0));
      // Planted the week before: not this week's work.
      await plant(await complete(DateTime(2026, 8, 3, 9)),
          plot: const GardenPlot(0, 1));

      final plants = await journal.plantsIn(week);
      expect(plants, hasLength(2));
      expect(
        plants.first.plantedAt.isAfter(plants.last.plantedAt),
        isTrue,
        reason: 'most recent first',
      );
    });

    test('include an award, which the domain is what drops', () async {
      // The repository reports what is in the ground; REQ-021's rule about what
      // counts as work done belongs to `JournalWeek`, not to a WHERE clause.
      await garden.save(Plant.forMilestone(
        Milestone.ten,
        id: 'awarded',
        plantedAt: DateTime(2026, 8, 11, 9).toUtc(),
        plot: const GardenPlot(0, 0),
      ));

      expect(await journal.plantsIn(week), hasLength(1));
      expect(JournalWeek.of(
        week: week,
        sessions: SessionTally.none,
        plants: await journal.plantsIn(week),
      ).plantsGrown, 0);
    });
  });

  group('the garden as a total', () {
    test('counts every plant, and the awards among them', () async {
      await plant(await complete(DateTime(2026, 8, 10, 9)),
          plot: const GardenPlot(0, 0));
      await plant(await complete(DateTime(2026, 8, 11, 9)),
          plot: const GardenPlot(1, 0));
      await garden.save(Plant.forMilestone(
        Milestone.ten,
        id: 'awarded',
        plantedAt: DateTime(2026, 8, 11, 10).toUtc(),
        plot: const GardenPlot(0, 1),
      ));

      expect(
        await journal.plantsEver(),
        const PlantTally(plants: 3, bonusPlants: 1),
      );
    });

    test('counts a plant the garden had no plot for', () async {
      // ADR 0006: past two hundred, a plant is recorded and not drawn. It is
      // still a plant the user grew, and the lifetime card says so.
      await plant(await complete(DateTime(2026, 8, 11, 9)));

      expect(await journal.plantsEver(), const PlantTally(plants: 1, bonusPlants: 0));
    });

    test('is nothing for an empty garden', () async {
      expect(await journal.plantsEver(), PlantTally.none);
    });
  });
}
