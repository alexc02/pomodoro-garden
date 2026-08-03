import 'focus_session.dart';

/// Stores sessions. The controller does the awaiting so [SessionMachine]
/// stays synchronous.
abstract interface class SessionRepository {
  /// Upsert: a session is written at start and again at end.
  Future<void> save(FocusSession session);

  /// Completed only, most recent first. Unfinished rows exist (ADR 0002) but
  /// aren't returned.
  Future<List<FocusSession>> completedSessions();

  /// The session with no outcome yet, read on cold start, or null. Should be
  /// at most one; if a crash ever leaves two, the most recent wins.
  Future<FocusSession?> inFlightSession();
}
