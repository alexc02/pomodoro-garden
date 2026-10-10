import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [SettingsRepository] over SQLite.
///
/// The whole translation between [GardenSettings] and the stored row lives
/// here: the domain never sees a column, and the database never sees a
/// [Duration]. A later ticket adding a setting adds a column, a line to each of
/// the two mappings below, and nothing else.
final class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this._database);

  final AppDatabase _database;

  @override
  Future<GardenSettings> load() async {
    final row = await _database.select(_database.settings).getSingleOrNull();
    if (row == null) return GardenSettings.defaults;

    // Built up from the defaults rather than constructed field by field, for
    // two reasons: the `with` setters clamp, so a row written by a build with
    // different bounds cannot hand the timer a length it would refuse; and a
    // column a later ticket adds arrives with a sane value on the day it is
    // added, before any row has been written with it.
    final stored = GardenSettings.defaults
        .withSessionLength(Duration(seconds: row.sessionLengthSeconds))
        .withBreakLength(Duration(seconds: row.breakLengthSeconds))
        .withLongBreakAfter(row.longBreakAfterSessions)
        .withHaptics(enabled: row.hapticsEnabled)
        .withLiveSurface(enabled: row.liveSurfaceEnabled)
        .withAutoStartBreak(enabled: row.autoStartBreak)
        .withAutoStartNextSession(enabled: row.autoStartNextSession)
        // Named rather than indexed, and read through the domain's own
        // fallback: a row naming a bed this build does not have is a row from
        // a future version, and silence is the reading that cannot be wrong.
        .withAmbientSound(AmbientSound.named(row.ambientSound))
        // Read through the domain's fallback for the same reason the bed is,
        // and it falls the other way: an unreadable row keeps the chime rather
        // than going quiet. See `EndSound.named`.
        .withEndSound(EndSound.named(row.endSound))
        // Read through the domain's fallback for the same reason the bed is:
        // a row this build cannot understand dresses the garden in the default
        // rather than in nothing.
        .withGardenTheme(GardenTheme.named(row.gardenTheme))
        .withQuietMode(enabled: row.quietModeEnabled);

    // Out of the chain, because the hint has no way back: it is dismissed by
    // the user and by nobody else, so the domain offers no setter that could
    // un-dismiss it and this is what reading a false column looks like.
    final hinted = row.quietModeHintDismissed
        ? stored.withQuietModeHintDismissed()
        : stored;

    // Onboarding has a way back — the debug reset — but it is still two setters
    // rather than a flag, so it is read the same way round.
    return row.onboardingCompleted ? hinted.withOnboardingCompleted() : hinted;
  }

  @override
  Future<void> save(GardenSettings settings) {
    // Upsert on the fixed key: the first change the user ever makes creates the
    // row, and every one after it replaces the same row. There is no "have they
    // saved before" for a caller to get wrong.
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
