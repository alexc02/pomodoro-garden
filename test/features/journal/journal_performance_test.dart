import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_journal_repository.dart';

// Journal aggregates should be computed in SQL, not by loading every session.
//
// The query plan check matters more than the timings: a fast machine would
// pass a stopwatch with the wrong implementation. Timings are loose budgets
// like test/garden/garden_performance_test.dart.
void main() {
  late AppDatabase database;
  late JournalRepository journal;

  /// Four years at three sessions a day.
  const years = 4;
  const perDay = 3;
  const days = years * 365;
  const sessions = days * perDay;

  final today = CalendarDay.of(DateTime(2026, 8, 11, 9, 41));

  setUpAll(() async {
    database = AppDatabase.forTesting();
    journal = DriftJournalRepository(database);

    // One batch instead of repositories to keep fixture setup fast.
    await database.batch((batch) {
      for (var back = 0; back < days; back++) {
        final day = today.plus(-back);
        for (var n = 0; n < perDay; n++) {
          final anchor = day.startsAt.add(Duration(hours: 8 + n * 3)).toUtc();
          final id = 'session-$back-$n';
          batch.insert(
            database.sessions,
            SessionsCompanion.insert(
              id: id,
              startedAt: anchor,
              durationSeconds: 1500,
              completed: const Value(true),
              outcome: const Value('completed'),
              endedAt: Value(anchor.add(const Duration(minutes: 25))),
            ),
          );
          batch.insert(
            database.plants,
            PlantsCompanion.insert(
              id: 'plant-$back-$n',
              sessionId: Value(id),
              type: PlantType.flower.name,
              species: PlantSpecies.tulip.name,
              growthStage: GrowthStage.mature.index,
              plantedAt: anchor,
              sessionDurationSeconds: const Value(1500),
            ),
          );
        }
      }
    });
  });

  tearDownAll(() => database.close());

  /// Time for [read] in ms, after a warm-up.
  Future<int> timed(Future<void> Function() read) async {
    await read();

    final clock = Stopwatch()..start();
    await read();
    clock.stop();
    return clock.elapsedMilliseconds;
  }

  test('fixture has four years of sessions', () async {
    expect((await journal.sessionsEver()).sessions, sessions);
    expect(await journal.daysWithSessions(), hasLength(days));
  });

  test('every figure loads within budget', () async {
    final week = DayRange.week(today, firstDayOfWeek: DateTime.monday);
    final month = DayRange.month(today);

    final reads = <String, Future<void> Function()>{
      'the week': () => journal.sessionsIn(week),
      'the lifetime': () => journal.sessionsEver(),
      'the month, day by day': () => journal.sessionsByDay(month),
      'the days tended': () => journal.daysWithSessions(),
      "the week's plants": () => journal.plantsIn(week),
      'the garden': () => journal.plantsEver(),
    };

    for (final MapEntry(key: what, value: read) in reads.entries) {
      expect(
        await timed(read),
        lessThan(150),
        reason: '$what took too long over $sessions sessions',
      );
    }
  });

  test('counts use the index, not a table scan', () async {
    // SEARCH ... USING INDEX means an index lookup; SCAN sessions would mean
    // reading every row.
    Future<String> planFor(String sql, [List<int> variables = const []]) async {
      final rows = await database
          .customSelect(
            'EXPLAIN QUERY PLAN $sql',
            variables: [for (final value in variables) Variable<int>(value)],
          )
          .get();
      return rows.map((row) => row.read<String>('detail')).join(' | ');
    }

    final week = DayRange.week(today, firstDayOfWeek: DateTime.monday);
    final from = week.from.millisecondsSinceEpoch ~/ 1000;
    final until = week.until.millisecondsSinceEpoch ~/ 1000;

    final rangeCount = await planFor(
      'SELECT COUNT(*), SUM(duration_seconds) FROM sessions '
      'WHERE completed = 1 AND started_at >= ? AND started_at < ?',
      [from, until],
    );
    expect(rangeCount, contains('sessions_completed_started_at'));
    expect(rangeCount, contains('SEARCH'));

    final everyDay = await planFor(
      "SELECT date(started_at, 'unixepoch', 'localtime') AS day, COUNT(*) "
      'FROM sessions WHERE completed = 1 GROUP BY day',
    );
    expect(everyDay, contains('sessions_completed_started_at'));
    // Covering index for the streak: day and flag are both in it.
    expect(everyDay, contains('COVERING INDEX'));
    expect(everyDay, isNot(contains('SCAN sessions ')));

    final weekPlants = await planFor(
      'SELECT * FROM plants WHERE planted_at >= ? AND planted_at < ? '
      'ORDER BY planted_at DESC',
      [from, until],
    );
    expect(weekPlants, contains('plants_planted_at'));
  });
}
