import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';

/// What each stored session says its outcome was, by session id.
///
/// Read as raw columns rather than through the repository: the point is what
/// SQLite is holding, which is what a later ticket's query — or a hand-written
/// migration — will see.
Future<Map<String, String?>> _outcomes(AppDatabase database) async {
  final rows =
      await database.customSelect('SELECT id, outcome FROM sessions').get();
  return {
    for (final row in rows)
      row.read<String>('id'): row.readNullable<String>('outcome'),
  };
}

/// The repository is tested against a real SQLite database, in memory. A fake
/// repository would prove the tests agree with each other; this proves the
/// schema, the mapping and the queries agree with SQLite.
void main() {
  late AppDatabase database;
  late SessionRepository repository;

  final anchor = DateTime.utc(2026, 8, 11, 9, 41);

  setUp(() {
    database = AppDatabase.forTesting();
    repository = DriftSessionRepository(database);
  });

  tearDown(() => database.close());

  test('a session that is still running is not a completed session', () async {
    await repository.save(FocusSession(
      id: 'a',
      startedAt: anchor,
      plannedDuration: const Duration(minutes: 25),
    ));

    expect(await repository.completedSessions(), isEmpty);
  });

  test('completing a session updates the row it already has', () async {
    final session = FocusSession(
      id: 'a',
      startedAt: anchor,
      plannedDuration: const Duration(minutes: 25),
    );
    await repository.save(session);

    await repository.save(session.completedAt(anchor.add(
      const Duration(minutes: 25),
    )));

    final completed = await repository.completedSessions();
    expect(completed, hasLength(1), reason: 'updated, not inserted twice');
    expect(completed.single.id, 'a');
    expect(completed.single.startedAt, anchor);
    expect(completed.single.plannedDuration, const Duration(minutes: 25));
    expect(completed.single.completed, isTrue);
    expect(completed.single.endedAt, anchor.add(const Duration(minutes: 25)));
    expect(completed.single.pausedDuration, Duration.zero);
  });

  test('completed sessions come back most recent first', () async {
    for (final (index, minutesAgo) in [90, 30, 60].indexed) {
      final startedAt = anchor.subtract(Duration(minutes: minutesAgo));
      await repository.save(FocusSession(
        id: 'session-$index',
        startedAt: startedAt,
        plannedDuration: const Duration(minutes: 15),
      ).completedAt(startedAt.add(const Duration(minutes: 15))));
    }

    expect(
      (await repository.completedSessions()).map((s) => s.id),
      ['session-1', 'session-2', 'session-0'],
    );
  });

  test('instants survive the round trip as UTC', () async {
    // SQLite has no date type. If the mapping stored local time, a session
    // started at 23:30 in one timezone would come back at a different hour in
    // another — and the anchor is the one value the whole timer rests on.
    final session = FocusSession(
      id: 'a',
      startedAt: anchor,
      plannedDuration: const Duration(minutes: 50),
    ).completedAt(anchor.add(const Duration(minutes: 50)));
    await repository.save(session);

    final read = (await repository.completedSessions()).single;
    expect(read.startedAt.isUtc, isTrue);
    expect(read.startedAt.toIso8601String(), anchor.toIso8601String());
    expect(read.endedAt!.isUtc, isTrue);
  });

  group('the session in flight', () {
    FocusSession running(String id, {DateTime? startedAt}) => FocusSession(
          id: id,
          startedAt: startedAt ?? anchor,
          plannedDuration: const Duration(minutes: 25),
        );

    test('there is none in an empty database', () async {
      expect(await repository.inFlightSession(), isNull);
    });

    test('a running session comes back with everything it was saved with',
        () async {
      await repository.save(running('a')
          .pausedAt(anchor.add(const Duration(minutes: 4)))
          .resumedAt(anchor.add(const Duration(minutes: 7)))
          .pausedAt(anchor.add(const Duration(minutes: 9))));

      final restored = (await repository.inFlightSession())!;
      expect(restored.id, 'a');
      expect(restored.startedAt, anchor);
      expect(restored.plannedDuration, const Duration(minutes: 25));
      expect(restored.pausedDuration, const Duration(minutes: 3));
      expect(restored.pausedSince, anchor.add(const Duration(minutes: 9)));
      expect(restored.pausedSince!.isUtc, isTrue);
      expect(restored.outcome, isNull);
    });

    test('resuming empties the column pausing filled', () async {
      // The one field on a session that has to go back to null, and so the one
      // that catches an upsert which only ever fills columns in. A session left
      // paused on disk comes back paused on the next launch, with a countdown
      // that never starts again.
      final held = running('a').pausedAt(anchor.add(const Duration(minutes: 4)));
      await repository.save(held);
      expect((await repository.inFlightSession())!.isPaused, isTrue);

      await repository.save(held.resumedAt(anchor.add(
        const Duration(minutes: 7),
      )));

      final resumed = (await repository.inFlightSession())!;
      expect(resumed.pausedSince, isNull);
      expect(resumed.isPaused, isFalse);
      expect(resumed.pausedDuration, const Duration(minutes: 3));
    });

    test('a session that ended, however it ended, is not in flight', () async {
      final at = anchor.add(const Duration(minutes: 12));
      await repository.save(running('a').completedAt(at));
      await repository.save(running('b').cancelledAt(at));
      await repository.save(running('c').voidedAt(at));

      expect(await repository.inFlightSession(), isNull);
    });

    test('cancelled and voided are told apart on the way back out', () async {
      // The two look identical from the garden's point of view — neither grew
      // anything — and the difference is kept anyway, because one of them was
      // the user's decision and the other was not.
      final at = anchor.add(const Duration(minutes: 12));
      await repository.save(running('a').cancelledAt(at));
      await repository.save(running('b').voidedAt(at));
      await repository.save(running('c').completedAt(at));

      expect(await _outcomes(database), {
        'a': 'cancelled',
        'b': 'voided',
        'c': 'completed',
      });
      expect((await repository.completedSessions()).single.id, 'c');
    });

    test('the most recent wins if two rows were somehow left open', () async {
      await repository.save(running('older',
          startedAt: anchor.subtract(const Duration(days: 1))));
      await repository.save(running('newer'));

      expect((await repository.inFlightSession())!.id, 'newer');
    });
  });

  test('a fresh database starts empty and at the current schema version',
      () async {
    // The migration path from empty: an app installed today opens a database
    // that does not exist yet, and gets every table without any upgrade step.
    // `database_migration_test.dart` owns the schema version and the path up
    // from an older one; what this asserts is that `sessions` is among the
    // tables a fresh install gets.
    expect(await repository.completedSessions(), isEmpty);

    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(
      tables.map((row) => row.read<String>('name')),
      contains('sessions'),
    );
  });
}
