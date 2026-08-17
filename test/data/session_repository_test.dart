import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';

/// Stored outcome per session id, read as raw columns.
Future<Map<String, String?>> _outcomes(AppDatabase database) async {
  final rows =
      await database.customSelect('SELECT id, outcome FROM sessions').get();
  return {
    for (final row in rows)
      row.read<String>('id'): row.readNullable<String>('outcome'),
  };
}

// Real in-memory SQLite so the schema and queries are actually exercised.
void main() {
  late AppDatabase database;
  late SessionRepository repository;

  final anchor = DateTime.utc(2026, 8, 11, 9, 41);

  setUp(() {
    database = AppDatabase.forTesting();
    repository = DriftSessionRepository(database);
  });

  tearDown(() => database.close());

  test('running session is not completed', () async {
    await repository.save(FocusSession(
      id: 'a',
      startedAt: anchor,
      plannedDuration: const Duration(minutes: 25),
    ));

    expect(await repository.completedSessions(), isEmpty);
  });

  test('completing updates the existing row', () async {
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
    // SQLite has no date type; the mapping must store UTC.
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

  group('in-flight session', () {
    FocusSession running(String id, {DateTime? startedAt}) => FocusSession(
          id: id,
          startedAt: startedAt ?? anchor,
          plannedDuration: const Duration(minutes: 25),
        );

    test('none in an empty database', () async {
      expect(await repository.inFlightSession(), isNull);
    });

    test('round-trips a running session', () async {
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

    test('resume clears pausedAt', () async {
      // The one field that goes back to null, which catches an upsert that only
      // fills columns in.
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

    test('ended sessions are not in flight', () async {
      final at = anchor.add(const Duration(minutes: 12));
      await repository.save(running('a').completedAt(at));
      await repository.save(running('b').cancelledAt(at));
      await repository.save(running('c').voidedAt(at));

      expect(await repository.inFlightSession(), isNull);
    });

    test('keeps cancelled and voided distinct', () async {
      // Same for the garden, but one was the user's choice and one wasn't.
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

    test('most recent wins if two are open', () async {
      await repository.save(running('older',
          startedAt: anchor.subtract(const Duration(days: 1))));
      await repository.save(running('newer'));

      expect((await repository.inFlightSession())!.id, 'newer');
    });
  });

  test('fresh database starts empty', () async {
    // Schema version and upgrades are covered in database_migration_test.dart.
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
