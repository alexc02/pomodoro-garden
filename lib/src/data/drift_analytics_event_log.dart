import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [AnalyticsEventLog] over SQLite: PRD §7.2's local table, and the whole of
/// what "analytics" means in this app.
///
/// The translation between a typed [AnalyticsEvent] and a stored row lives
/// here, and it is one line each way — a name and a JSON object. What the row
/// meant is the event class's business, which is why nothing in here switches on
/// an event.
final class DriftAnalyticsEventLog implements AnalyticsEventLog {
  const DriftAnalyticsEventLog(this._database);

  final AppDatabase _database;

  /// Writes the event and prunes in the same transaction.
  ///
  /// **Pruned on the way in rather than swept.** Nothing of this app runs in the
  /// background — REQ-005 — so a scheduled tidy-up is a tidy-up that never
  /// happens; the only moment the log is certainly growing is the moment
  /// something is being added to it, and that is when the oldest rows go. The
  /// cost is one indexed delete per event, against a table that sees a handful
  /// of rows a session.
  ///
  /// The delete is a range over the row id rather than a sort: the id below
  /// which everything is surplus is one seek from the end of the primary key,
  /// and `id <= that` is a contiguous sweep. A `NOT IN (SELECT … ORDER BY …
  /// LIMIT …)` would read the whole table to answer the same question.
  @override
  Future<void> append(AnalyticsEvent event, {required DateTime at}) {
    return _database.transaction(() async {
      await _database.into(_database.analyticsEvents).insert(
            AnalyticsEventsCompanion.insert(
              name: event.name.recorded,
              parameters: jsonEncode(event.parameters),
              // Drift stores instants as Unix seconds, which carry no zone;
              // going in as UTC is what makes coming out as UTC meaningful.
              recordedAt: at.toUtc(),
            ),
          );

      await _database.customStatement(
        'DELETE FROM analytics_events WHERE id <= ('
        '  SELECT id FROM analytics_events ORDER BY id DESC LIMIT 1 OFFSET ?'
        ')',
        // The id of the first row *past* what the log keeps, counting back from
        // the newest. Everything at or below it is surplus; a log that is not
        // full yet has no such row, the subquery is null, and `id <= null`
        // matches nothing — which is the no-op this wants on almost every write.
        [AnalyticsEventLog.maximumEvents],
      );
    });
  }

  @override
  Future<List<LoggedEvent>> recent({
    int limit = AnalyticsEventLog.maximumEvents,
  }) async {
    final query = _database.select(_database.analyticsEvents)
      // By id rather than by instant: the row written last is the event that
      // happened last, whatever a device clock corrected in between says.
      ..orderBy([(row) => OrderingTerm.desc(row.id)])
      ..limit(limit);

    return (await query.get()).map(_toEvent).toList();
  }

  @override
  Future<DateTime?> lastRecordedAt(AnalyticsEventName name) async {
    final query = _database.select(_database.analyticsEvents)
      ..where((row) => row.name.equals(name.recorded))
      ..orderBy([(row) => OrderingTerm.desc(row.id)])
      ..limit(1);

    return (await query.getSingleOrNull())?.recordedAt.toUtc();
  }

  LoggedEvent _toEvent(AnalyticsEventRow row) => LoggedEvent(
        name: row.name,
        parameters: _decode(row.parameters),
        at: row.recordedAt.toUtc(),
      );

  /// The stored JSON back as a map.
  ///
  /// A row whose parameters cannot be read comes back with none rather than
  /// taking the read down: the log is a debugging aid, and one unreadable row
  /// must not be able to stop the screen that would show it — or, worse, the
  /// app-open check that reads the log at launch.
  static Map<String, Object?> _decode(String stored) {
    try {
      final decoded = jsonDecode(stored);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}
