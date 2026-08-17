import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [SettingsRepository] over SQLite. A new setting needs a column and a line
/// in each mapping below.
final class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this._database);

  final AppDatabase _database;

  @override
  Future<GardenSettings> load() async {
    final row = await _database.select(_database.settings).getSingleOrNull();
    if (row == null) return GardenSettings.defaults;

    // Built from defaults via the `with` setters because they clamp
    // out-of-range values from other builds.
    final stored = GardenSettings.defaults
        .withSessionLength(Duration(seconds: row.sessionLengthSeconds))
        .withBreakLength(Duration(seconds: row.breakLengthSeconds))
        .withLongBreakAfter(row.longBreakAfterSessions)
        .withHaptics(enabled: row.hapticsEnabled)
        .withLiveSurface(enabled: row.liveSurfaceEnabled)
        .withAutoStartBreak(enabled: row.autoStartBreak)
        .withAutoStartNextSession(enabled: row.autoStartNextSession)
        // The `named` lookups fall back on unknown values (silence, the
        // chime, the default theme).
        .withAmbientSound(AmbientSound.named(row.ambientSound))
        .withEndSound(EndSound.named(row.endSound))
        .withGardenTheme(GardenTheme.named(row.gardenTheme))
        .withQuietMode(enabled: row.quietModeEnabled);

    // These two only have one-way setters, so apply them conditionally.
    final hinted = row.quietModeHintDismissed
        ? stored.withQuietModeHintDismissed()
        : stored;

    return row.onboardingCompleted ? hinted.withOnboardingCompleted() : hinted;
  }

  @override
  Future<void> save(GardenSettings settings) {
    // Upsert on the fixed id creates the row on first save.
    return _database.into(_database.settings).insertOnConflictUpdate(
          SettingsRow(
            id: AppDatabase.settingsRowId,
            sessionLengthSeconds: settings.sessionLength.inSeconds,
            breakLengthSeconds: settings.breakLength.inSeconds,
            longBreakAfterSessions: settings.longBreakAfter,
            hapticsEnabled: settings.hapticsEnabled,
            liveSurfaceEnabled: settings.liveSurfaceEnabled,
            autoStartBreak: settings.autoStartBreak,
            autoStartNextSession: settings.autoStartNextSession,
            ambientSound: settings.ambientSound.name,
            endSound: settings.endSound.name,
            gardenTheme: settings.gardenTheme.name,
            quietModeEnabled: settings.quietModeEnabled,
            quietModeHintDismissed: settings.quietModeHintDismissed,
            onboardingCompleted: settings.onboardingCompleted,
          ),
        );
  }
}
