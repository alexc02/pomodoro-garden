import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [AnalyticsEventLog] over SQLite. Events are stored as a name plus a JSON
/// object; nothing here knows about individual event types.
final class DriftAnalyticsEventLog implements AnalyticsEventLog {
  const DriftAnalyticsEventLog(this._database);

  final AppDatabase _database;

  /// Writes the event and trims old rows in the same transaction. Trimming on
  /// write because the app never runs in the background to do it otherwise.
  @override
  Future<void> append(AnalyticsEvent event, {required DateTime at}) {
    return _database.transaction(() async {
      await _database.into(_database.analyticsEvents).insert(
            AnalyticsEventsCompanion.insert(
              name: event.name.recorded,
              parameters: jsonEncode(event.parameters),
              // Drift stores zoneless Unix seconds; keep everything UTC.
              recordedAt: at.toUtc(),
            ),
          );

      await _database.customStatement(
        'DELETE FROM analytics_events WHERE id <= ('
        '  SELECT id FROM analytics_events ORDER BY id DESC LIMIT 1 OFFSET ?'
        ')',
        // First id past the cap, counting back from the newest. If the log
        // isn't full the subquery is null and `id <= null` deletes nothing.
        [AnalyticsEventLog.maximumEvents],
      );
    });
  }

  @override
  Future<List<LoggedEvent>> recent({
    int limit = AnalyticsEventLog.maximumEvents,
  }) async {
    final query = _database.select(_database.analyticsEvents)
      // By id, not timestamp, so clock changes don't reorder the log.
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

  /// Bad JSON decodes to an empty map instead of throwing, since the log is
  /// also read at launch.
  static Map<String, Object?> _decode(String stored) {
    try {
      final decoded = jsonDecode(stored);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}
