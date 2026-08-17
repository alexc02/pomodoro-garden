import 'database.dart';

/// The Pomodoro cycle's position, kept across launches. No row means 0
/// (fresh install, pre-v20 upgrade, or just reset).
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
