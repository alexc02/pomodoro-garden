import 'database.dart';

/// The Pomodoro cycle's position, kept across launches.
///
/// A missing row is session one of the cycle: a fresh install, an upgrade
/// from before the row existed, and a garden that has just been reset all read
/// as zero.
final class DriftCycleStore {
  const DriftCycleStore(this._database);

  final AppDatabase _database;

  Future<int> load() async {
    final row = await _database
        .customSelect('SELECT position FROM cycle WHERE id = 1')
        .getSingleOrNull();
    return row?.read<int>('position') ?? 0;
  }

  Future<void> save(int position) => _database.customStatement(
        'INSERT INTO cycle (id, position) VALUES (1, ?) '
        'ON CONFLICT (id) DO UPDATE SET position = excluded.position',
        [position],
      );
}
