import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';
import 'drift_analytics_event_log.dart';
import 'drift_cycle_store.dart';
import 'drift_decor_repository.dart';
import 'drift_garden_reset.dart';
import 'drift_journal_repository.dart';
import 'drift_plant_repository.dart';
import 'drift_session_repository.dart';
import 'drift_settings_repository.dart';

/// The app's one database connection.
///
/// One for the process: SQLite serialises writers anyway, and a second
/// connection to the same file buys contention rather than throughput. Tests
/// override this with [AppDatabase.forTesting].
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Where sessions are stored. The domain sees only the port.
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => DriftSessionRepository(ref.watch(databaseProvider)),
);

/// Where settings are stored. Same database, same pattern: the domain sees only
/// the port.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(databaseProvider)),
);

/// Where the garden is stored.
final plantRepositoryProvider = Provider<PlantRepository>(
  (ref) => DriftPlantRepository(ref.watch(databaseProvider)),
);

/// Where REQ-040's arrangement is kept.
///
/// A port of its own beside the garden's, for the reason the table is a table of
/// its own: a plant is written once and an item exists to be moved.
final decorRepositoryProvider = Provider<DecorRepository>(
  (ref) => DriftDecorRepository(ref.watch(databaseProvider)),
);

/// Where the journal's figures are counted — the same two tables, asked for
/// totals rather than for rows.
final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => DriftJournalRepository(ref.watch(databaseProvider)),
);

/// Where PRD §7.1's events are kept: the same database, a table of its own, and
/// nothing outside the device. See `analytics_providers.dart` for the port the
/// app records *through* — this is only the storage behind it, and the two
/// things that read it directly are the debug screen and ticket 22's reset.
final analyticsEventLogProvider = Provider<AnalyticsEventLog>(
  (ref) => DriftAnalyticsEventLog(ref.watch(databaseProvider)),
);

/// REQ-036's reset: the four tables above emptied together, or not at all.
///
/// A port beside the repositories rather than a method on each of them, because
/// what makes a reset correct is that the plants, the sessions, the arrangement
/// and the log go in one transaction — see [GardenReset]. `garden_reset_providers
/// .dart` is what calls it, and it is the only thing that does.
final gardenResetProvider = Provider<GardenReset>(
  (ref) => DriftGardenReset(ref.watch(databaseProvider)),
);

final cycleStoreProvider = Provider<DriftCycleStore>(
  (ref) => DriftCycleStore(ref.watch(databaseProvider)),
);
