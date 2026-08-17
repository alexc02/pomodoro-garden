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

/// One connection for the whole process. Tests override with
/// [AppDatabase.forTesting].
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => DriftSessionRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(databaseProvider)),
);

final plantRepositoryProvider = Provider<PlantRepository>(
  (ref) => DriftPlantRepository(ref.watch(databaseProvider)),
);

final decorRepositoryProvider = Provider<DecorRepository>(
  (ref) => DriftDecorRepository(ref.watch(databaseProvider)),
);

/// Aggregates over the sessions and plants tables.
final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => DriftJournalRepository(ref.watch(databaseProvider)),
);

/// Storage behind analytics. The app records through
/// `analytics_providers.dart`; only the debug screen and the reset use this
/// directly.
final analyticsEventLogProvider = Provider<AnalyticsEventLog>(
  (ref) => DriftAnalyticsEventLog(ref.watch(databaseProvider)),
);

/// Empties plants, sessions, decor and the event log in one transaction
/// (see [GardenReset]).
final gardenResetProvider = Provider<GardenReset>(
  (ref) => DriftGardenReset(ref.watch(databaseProvider)),
);

final cycleStoreProvider = Provider<DriftCycleStore>(
  (ref) => DriftCycleStore(ref.watch(databaseProvider)),
);
