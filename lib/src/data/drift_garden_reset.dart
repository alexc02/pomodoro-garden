import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [GardenReset] over SQLite: every delete in one transaction, so a failure
/// can't leave sessions behind with no plants (which would make milestones
/// look owed).
///
/// `settings` is deliberately not cleared. Don't add it here.
final class DriftGardenReset implements GardenReset {
  const DriftGardenReset(this._database);

  final AppDatabase _database;

  @override
  Future<void> clear() {
    return _database.transaction(() async {
      await _database.delete(_database.plants).go();
      await _database.delete(_database.sessions).go();
      // Decor goes too: it holds plots open in `GardenLayout`, so keeping it
      // would leave a reset garden bigger than the 12 plots it should have.
      await _database.delete(_database.gardenDecor).go();
      await _database.delete(_database.analyticsEvents).go();
      await _database.customStatement('DELETE FROM cycle');
    });
  }
}
