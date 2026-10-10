import 'package:drift/drift.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';
import 'drift_plant_repository.dart';

/// [JournalRepository] over SQLite: every figure on the journal, counted by the
/// database.
///
/// The whole of ticket 15's performance requirement is in this file, and it is
/// a requirement about *shape* rather than about milliseconds. Nothing here
/// reads a session row into Dart. A count is `COUNT(*)`, a total is `SUM`, and
/// the heatmap and the streak are one row per day out of a `GROUP BY` — so
/// the work a query does grows with the history and the memory it needs does
/// not. A user with four years behind them has a few thousand rows here, and
/// gets back six numbers and thirty-one day counts.
///
/// **Where the days come from.** SQLite decides which local day a session
/// belongs to, with `date(started_at, 'unixepoch', 'localtime')`, and Dart
/// decides where a range begins and ends ([DayRange.from], [DayRange.until]).
/// The two agree because both read the device's time zone, and the division of
/// labour is deliberate: a range as a pair of instants is a seek down an index,
/// where a range expressed as "the local day is between these two" would be a
/// function evaluated against every row in the table. The grouped queries have
/// no such choice — a day is what they group *by* — which is why the index
/// puts `completed` first, so those scans walk the index rather than the
/// table.
///
/// The one thing `'localtime'` costs is a dependency on the platform's own
/// time-zone database, which is the same one `DateTime.toLocal` reads. See
/// `docs/adr/0012-a-day-in-the-journal-is-the-day-a-session-was-anchored.md`.
final class DriftJournalRepository implements JournalRepository {
  const DriftJournalRepository(this._database);

  final AppDatabase _database;

  /// The local calendar day a session's anchor falls in, as SQLite computes it.
  ///
  /// Written once and used by both grouped queries, because two copies of this
  /// expression is two chances for the heatmap and the streak to disagree about
  /// what a day is.
  static const String _localDay =
      "date(started_at, 'unixepoch', 'localtime')";

  /// The rows every count in this file is made from: sessions that completed.
  ///
  /// ADR 0002 — the table holds sessions that were started and never
  /// finished, and a journal is a record of work done.
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
      // Grouped rather than `SELECT DISTINCT` for the same answer and a
      // clearer plan, and ordered by the ISO text, which sorts as the calendar
      // does — that is the whole reason [CalendarDay] writes itself that way.
      'GROUP BY day ORDER BY day DESC',
      readsFrom: {_database.sessions},
    ).get();

    return [for (final row in rows) CalendarDay.parse(row.read<String>('day'))];
  }

  @override
  Future<List<Plant>> plantsIn(DayRange range) async {
    // The query builder rather than SQL, because this is the one method that
    // returns objects: the mapping from a row to a [Plant] belongs to
    // `drift_plant_repository.dart` and there must not be a second copy of it.
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
      // `COUNT(column)` counts the rows where it is not null, which is exactly
      // what a bonus plant is: a milestone in that column and no second flag to
      // disagree with it.
      'SELECT COUNT(*) AS plants, COUNT(milestone_sessions) AS awarded '
      'FROM plants',
      readsFrom: {_database.plants},
    ).getSingle();

    return PlantTally(
      plants: row.read<int>('plants'),
      bonusPlants: row.read<int>('awarded'),
    );
  }

  /// A count and a sum over the sessions [where] selects.
  ///
  /// `COALESCE` because `SUM` over no rows is null, and a journal opened by a
  /// user who has finished nothing should read zero rather than fail.
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

  /// An instant as the column holds it: Unix seconds, which is drift's default
  /// for a `DateTimeColumn` and what every row in this database was written
  /// with.
  static int _seconds(DateTime instant) =>
      instant.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
}
