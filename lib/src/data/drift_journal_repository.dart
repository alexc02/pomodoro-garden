import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';
import 'drift_plant_repository.dart';

/// [JournalRepository] over SQLite. Everything is aggregated in SQL so no
/// session rows get loaded into Dart.
///
/// SQLite works out a session's local day with `'localtime'`; Dart works out
/// range boundaries as instants ([DayRange.from], [DayRange.until]) so range
/// filters can use the index. Both use the device time zone.
final class DriftJournalRepository implements JournalRepository {
  const DriftJournalRepository(this._database);

  final AppDatabase _database;

  /// Local day of a session. Shared so the heatmap and streak agree.
  static const String _localDay =
      "date(started_at, 'unixepoch', 'localtime')";

  /// The table also has unfinished sessions (ADR 0002).
  static const String _completed = 'completed = 1';

  @override
  Future<SessionTally> sessionsIn(DayRange range) => _tally(
        'WHERE $_completed AND started_at >= ? AND started_at < ?',
        [
          Variable<int>(_seconds(range.from)),
          Variable<int>(_seconds(range.until)),
        ],
      );

  @override
  Future<SessionTally> sessionsEver() => _tally('WHERE $_completed', const []);

  @override
  Future<Map<CalendarDay, int>> sessionsByDay(DayRange range) async {
    final rows = await _database.customSelect(
      'SELECT $_localDay AS day, COUNT(*) AS sessions FROM sessions '
      'WHERE $_completed AND started_at >= ? AND started_at < ? '
      'GROUP BY day',
      variables: [
        Variable<int>(_seconds(range.from)),
        Variable<int>(_seconds(range.until)),
      ],
      readsFrom: {_database.sessions},
    ).get();

    return {
      for (final row in rows)
        CalendarDay.parse(row.read<String>('day')): row.read<int>('sessions'),
    };
  }

  @override
  Future<List<CalendarDay>> daysWithSessions() async {
    final rows = await _database.customSelect(
      'SELECT $_localDay AS day FROM sessions WHERE $_completed '
      // ISO dates sort as text.
      'GROUP BY day ORDER BY day DESC',
      readsFrom: {_database.sessions},
    ).get();

    return [for (final row in rows) CalendarDay.parse(row.read<String>('day'))];
  }

  @override
  Future<List<Plant>> plantsIn(DayRange range) async {
    // Query builder so we can reuse [plantFromRow].
    final query = _database.select(_database.plants)
      ..where((row) =>
          row.plantedAt.isBiggerOrEqualValue(range.from) &
          row.plantedAt.isSmallerThanValue(range.until))
      ..orderBy([(row) => OrderingTerm.desc(row.plantedAt)]);

    return (await query.get()).map(plantFromRow).toList();
  }

  @override
  Future<PlantTally> plantsEver() async {
    final row = await _database.customSelect(
      // COUNT(column) skips nulls, i.e. counts bonus plants.
      'SELECT COUNT(*) AS plants, COUNT(milestone_sessions) AS awarded '
      'FROM plants',
      readsFrom: {_database.plants},
    ).getSingle();

    return PlantTally(
      plants: row.read<int>('plants'),
      bonusPlants: row.read<int>('awarded'),
    );
  }

  /// Count and total duration. COALESCE because SUM of no rows is null.
  Future<SessionTally> _tally(
    String where,
    List<Variable<Object>> variables,
  ) async {
    final row = await _database.customSelect(
      'SELECT COUNT(*) AS sessions, COALESCE(SUM(duration_seconds), 0) AS '
      'focus_seconds FROM sessions $where',
      variables: variables,
      readsFrom: {_database.sessions},
    ).getSingle();

    return SessionTally(
      sessions: row.read<int>('sessions'),
      focus: Duration(seconds: row.read<int>('focus_seconds')),
    );
  }

  /// Unix seconds, matching drift's `DateTimeColumn` storage.
  static int _seconds(DateTime instant) =>
      instant.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
}
