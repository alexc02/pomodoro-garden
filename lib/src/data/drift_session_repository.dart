import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [SessionRepository] over SQLite.
final class DriftSessionRepository implements SessionRepository {
  const DriftSessionRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> save(FocusSession session) {
    // Companion with explicit Values, not a data class: a data-class upsert
    // skips null fields, so `pausedSince` would never get cleared on resume.
    return _database.into(_database.sessions).insertOnConflictUpdate(
          SessionsCompanion(
            id: Value(session.id),
            // Drift stores zoneless Unix seconds; keep everything UTC.
            startedAt: Value(session.startedAt.toUtc()),
            durationSeconds: Value(session.plannedDuration.inSeconds),
            completed: Value(session.completed),
            outcome: Value(session.outcome?.name),
            pausedSeconds: Value(session.pausedDuration.inSeconds),
            pausedSince: Value(session.pausedSince?.toUtc()),
            endedAt: Value(session.endedAt?.toUtc()),
          ),
        );
  }

  @override
  Future<List<FocusSession>> completedSessions() async {
    final query = _database.select(_database.sessions)
      ..where((row) => row.completed.equals(true))
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]);

    return (await query.get()).map(_toSession).toList();
  }

  @override
  Future<FocusSession?> inFlightSession() async {
    final query = _database.select(_database.sessions)
      ..where((row) => row.outcome.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)])
      ..limit(1);

    final row = await query.getSingleOrNull();
    return row == null ? null : _toSession(row);
  }

  FocusSession _toSession(SessionRow row) => FocusSession(
        id: row.id,
        startedAt: row.startedAt.toUtc(),
        plannedDuration: Duration(seconds: row.durationSeconds),
        pausedDuration: Duration(seconds: row.pausedSeconds),
        pausedSince: row.pausedSince?.toUtc(),
        endedAt: row.endedAt?.toUtc(),
        outcome: _toOutcome(row.outcome),
      );

  /// Unknown names (from a newer build) read as voided, so they can't come
  /// back as a live session.
  SessionOutcome? _toOutcome(String? stored) {
    if (stored == null) return null;
    return SessionOutcome.values.firstWhere(
      (outcome) => outcome.name == stored,
      orElse: () => SessionOutcome.voided,
    );
  }
}
