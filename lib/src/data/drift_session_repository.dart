import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [SessionRepository] over SQLite.
///
/// The whole of the translation between the domain's [FocusSession] and the
/// stored row lives here, so the domain never sees a column and the database
/// never sees a [Duration].
final class DriftSessionRepository implements SessionRepository {
  const DriftSessionRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> save(FocusSession session) {
    // A companion with every field spelled out, rather than the `SessionRow`
    // data class this used to write. An upsert built from a data class leaves
    // null fields *absent* from its update clause, so a null never overwrites
    // what is already in the column — which is fine for the fields that only
    // ever fill in, and silently wrong for `pausedSince`, the one field that
    // has to empty again. Resuming a session would have left it paused on disk.
    return _database.into(_database.sessions).insertOnConflictUpdate(
          SessionsCompanion(
            id: Value(session.id),
            // Drift stores instants as Unix seconds, which are zone-free; going
            // in as UTC is what makes coming out as UTC meaningful.
            startedAt: Value(session.startedAt.toUtc()),
            durationSeconds: Value(session.plannedDuration.inSeconds),
            // Both from the one field on the session, so the flag every count
            // filters on cannot drift from the outcome it summarises.
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

  /// The stored name back as an outcome.
  ///
  /// A name this build does not know is treated as an ended session of no
  /// particular kind rather than as one still in flight: a row written by a
  /// later version and read by an older one must not come back as a live
  /// session and start counting down.
  SessionOutcome? _toOutcome(String? stored) {
    if (stored == null) return null;
    return SessionOutcome.values.firstWhere(
      (outcome) => outcome.name == stored,
      orElse: () => SessionOutcome.voided,
    );
  }
}
