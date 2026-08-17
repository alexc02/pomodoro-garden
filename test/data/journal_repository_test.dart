import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_journal_repository.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';

// Real in-memory SQLite: the day a session falls on is computed by
// date(..., 'localtime') in the query, so a fake can't check it.
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

  /// Records a session anchored at [local] device time (stored UTC, ADR 0001).
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

  Future<void> abandon(DateTime local) async {
    final anchor = local.toUtc();
    await sessions.save(FocusSession(
      id: 'cancelled-${anchor.microsecondsSinceEpoch}',
      startedAt: anchor,
      plannedDuration: const Duration(minutes: 25),
    ).cancelledAt(anchor.add(const Duration(minutes: 5))));
  }

  Future<void> plant(FocusSession session, {GardenPlot? plot}) => garden.save(
        Plant.fromSession(session, id: 'plant-${session.id}', plot: plot),
      );

  final week = DayRange.week(
    const CalendarDay(2026, 8, 11),
    firstDayOfWeek: DateTime.monday,
  );

  group('span totals', () {
    test('counts completed sessions and sums their lengths', () async {
      await complete(DateTime(2026, 8, 10, 9), length: const Duration(minutes: 25));
      await complete(DateTime(2026, 8, 11, 14), length: const Duration(minutes: 50));
      await complete(DateTime(2026, 8, 16, 20), length: const Duration(minutes: 15));

      expect(
        await journal.sessionsIn(week),
        const SessionTally(sessions: 3, focus: Duration(minutes: 90)),
      );
    });

    test('ignores unfinished sessions', () async {
      await complete(DateTime(2026, 8, 11, 9));
      await abandon(DateTime(2026, 8, 11, 11));
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

    test('is zero for an empty span', () async {
      expect(await journal.sessionsIn(week), SessionTally.none);
      expect(await journal.sessionsEver(), SessionTally.none);
    });

    test('range is half open', () async {
      // Boundary instants for the half-open range, in local time.
      await complete(DateTime(2026, 8, 9, 23, 59, 59), id: 'the-night-before');
      await complete(DateTime(2026, 8, 10), id: 'first-midnight');
      await complete(DateTime(2026, 8, 16, 23, 59, 59), id: 'last-moment');
      await complete(DateTime(2026, 8, 17), id: 'next-midnight');

      expect((await journal.sessionsIn(week)).sessions, 2);
      expect((await journal.sessionsEver()).sessions, 4);
    });

    test('sums all completed sessions ever', () async {
      await complete(DateTime(2019, 1, 2, 8), length: const Duration(hours: 2));
      await complete(DateTime(2026, 8, 11, 8), length: const Duration(hours: 1));

      expect(
        await journal.sessionsEver(),
        const SessionTally(sessions: 2, focus: Duration(hours: 3)),
      );
    });
  });

  group('session day', () {
    test('is the anchor day, not the end day', () async {
      // 23:50 to 00:20. Belongs to the start day.
      await complete(
        DateTime(2026, 8, 10, 23, 50),
        length: const Duration(minutes: 30),
      );

      expect(await journal.sessionsByDay(week), {const CalendarDay(2026, 8, 10): 1});
      expect(await journal.daysWithSessions(), [const CalendarDay(2026, 8, 10)]);
    });

    test('uses the local day', () async {
      await complete(DateTime(2026, 8, 11, 22, 30));
      await complete(DateTime(2026, 8, 11, 23, 30));

      expect(await journal.sessionsByDay(week), {const CalendarDay(2026, 8, 11): 2});
    });
  });

  group('month by day', () {
    test('counts per day, skips empty days', () async {
      await complete(DateTime(2026, 8, 3, 9));
      await complete(DateTime(2026, 8, 3, 11));
      await complete(DateTime(2026, 8, 11, 9));

      expect(await journal.sessionsByDay(DayRange.month(const CalendarDay(2026, 8, 11))), {
        const CalendarDay(2026, 8, 3): 2,
        const CalendarDay(2026, 8, 11): 1,
      });
    });

    test('excludes neighbouring months', () async {
      await complete(DateTime(2026, 7, 31, 23));
      await complete(DateTime(2026, 8, 1, 1));
      await complete(DateTime(2026, 9, 1, 1));

      expect(await journal.sessionsByDay(DayRange.month(const CalendarDay(2026, 8, 11))), {
        const CalendarDay(2026, 8, 1): 1,
      });
    });

    test('does not count unfinished sessions', () async {
      await abandon(DateTime(2026, 8, 4, 9));

      expect(await journal.sessionsByDay(DayRange.month(const CalendarDay(2026, 8, 11))), isEmpty);
    });
  });

  group('tended days', () {
    test('distinct, most recent first', () async {
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

    test('cover the whole history', () async {
      await complete(DateTime(2019, 3, 1, 9));
      await complete(DateTime(2026, 8, 11, 9));

      expect(await journal.daysWithSessions(), const [
        CalendarDay(2026, 8, 11),
        CalendarDay(2019, 3, 1),
      ]);
    });

    test('empty with no completed sessions', () async {
      await abandon(DateTime(2026, 8, 11, 9));

      expect(await journal.daysWithSessions(), isEmpty);
    });
  });

  group('plants in a span', () {
    test('planted in the span, most recent first', () async {
      await plant(await complete(DateTime(2026, 8, 10, 9)),
          plot: const GardenPlot(0, 0));
      await plant(await complete(DateTime(2026, 8, 12, 9)),
          plot: const GardenPlot(1, 0));
      // Previous week, so excluded.
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

    test('include milestone plants', () async {
      // The repo returns what's planted; JournalWeek decides what counts.
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

  group('garden totals', () {
    test('counts plants and milestones', () async {
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

    test('counts unplaced plants', () async {
      // Past 200 plants are recorded but not drawn. Still counted.
      await plant(await complete(DateTime(2026, 8, 11, 9)));

      expect(await journal.plantsEver(), const PlantTally(plants: 1, bonusPlants: 0));
    });

    test('zero for an empty garden', () async {
      expect(await journal.plantsEver(), PlantTally.none);
    });
  });
}
