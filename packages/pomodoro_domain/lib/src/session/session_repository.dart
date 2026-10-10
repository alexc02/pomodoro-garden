import 'focus_session.dart';

/// Where sessions are kept.
///
/// A port: the domain says what it needs of storage, and the app supplies a
/// SQLite-backed implementation. Nothing in here knows about tables, and
/// nothing in the domain awaits a database directly — the controller does the
/// awaiting, so the state machine stays synchronous and pure.
abstract interface class SessionRepository {
  /// Writes [session], replacing any earlier version of it.
  ///
  /// One upsert rather than an insert and an update because a session is
  /// written twice — when it starts and when it ends — and the caller should
  /// not have to remember which write it is on.
  Future<void> save(FocusSession session);

  /// Every session that reached its planned duration, most recent first.
  ///
  /// Sessions that were started and never finished are not returned. They are
  /// in the table — see ADR 0002 — but they are not sessions the user
  /// completed, and every count in the app is a count of completed ones.
  Future<List<FocusSession>> completedSessions();

  /// The session that was still running when the app was last here, or null.
  ///
  /// This is what a cold start reads: a session with no outcome recorded is one
  /// nothing ever ended, and the clock decides where it should be now. There is
  /// at most one, because starting a session over a live one is refused and
  /// force-quitting closes the live one — but the most recent wins if a crash
  /// at exactly the wrong moment ever leaves two.
  Future<FocusSession?> inFlightSession();
}
