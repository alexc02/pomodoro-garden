import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = DriftSettingsRepository(database);
  });

  tearDown(() => database.close());

  test('loads defaults when nothing is saved', () async {
    // First run: no row yet, which isn't an error.
    expect(await repository.load(), GardenSettings.defaults);
  });

  test('saved settings come back', () async {
    final chosen = GardenSettings.defaults
        .withSessionLength(const Duration(minutes: 50))
        .withBreakLength(const Duration(minutes: 12))
        .withLongBreakAfter(3)
        .withHaptics(enabled: false);

    await repository.save(chosen);

    expect(await repository.load(), chosen);
  });

  test('haptics off persists', () async {
    // A field that only goes false is what a data-class upsert gets wrong.
    await repository.save(GardenSettings.defaults.withHaptics(enabled: false));
    expect((await repository.load()).hapticsEnabled, isFalse);

    await repository.save(GardenSettings.defaults.withHaptics(enabled: true));
    expect((await repository.load()).hapticsEnabled, isTrue);
  });

  test('quiet mode and its hint persist independently', () async {
    // Independent booleans. Crossing them could silence a phone by mistake.
    await repository.save(GardenSettings.defaults.withQuietMode(enabled: true));
    expect((await repository.load()).quietModeEnabled, isTrue);
    expect((await repository.load()).quietModeHintDismissed, isFalse);

    await repository
        .save(GardenSettings.defaults.withQuietModeHintDismissed());
    expect((await repository.load()).quietModeEnabled, isFalse);
    expect((await repository.load()).quietModeHintDismissed, isTrue);

    await repository
        .save(GardenSettings.defaults.withQuietMode(enabled: false));
    expect((await repository.load()).quietModeEnabled, isFalse);
  });

  test('onboarding completed persists', () async {
    // Relaunch reads this flag, so it must survive.
    await repository.save(GardenSettings.defaults.withOnboardingCompleted());
    expect((await repository.load()).onboardingCompleted, isTrue);

    // And the debug reset can clear it.
    await repository.save(
      (await repository.load()).withOnboardingReset(),
    );
    expect((await repository.load()).onboardingCompleted, isFalse);
  });

  test('round-trips ambient sound', () async {
    for (final sound in AmbientSound.values) {
      await repository.save(GardenSettings.defaults.withAmbientSound(sound));
      expect((await repository.load()).ambientSound, sound);
    }
  });

  test('unknown ambient sound reads as silence', () async {
    // Row from a newer build with an extra sound. Fall back to silence.
    await database.customStatement(
      "UPDATE settings SET ambient_sound = 'thunderstorm'",
    );
    await repository.save(
      GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
    );
    await database.customStatement(
      "UPDATE settings SET ambient_sound = 'thunderstorm'",
    );

    expect((await repository.load()).ambientSound, AmbientSound.silence);
  });

  test('saving twice keeps one row', () async {
    await repository.save(
      GardenSettings.defaults.withSessionLength(const Duration(minutes: 50)),
    );
    await repository.save(
      GardenSettings.defaults.withSessionLength(const Duration(minutes: 15)),
    );

    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 15),
    );
    final rows = await database.select(database.settings).get();
    expect(rows, hasLength(1), reason: 'settings is a single-row table');
  });

  test('a second settings row cannot be inserted', () async {
    // Enforced by the table constraint, not the repository.
    await repository.save(GardenSettings.defaults);

    await expectLater(
      database.into(database.settings).insert(
            SettingsCompanion.insert(
              id: const Value(2),
              sessionLengthSeconds: 60,
              breakLengthSeconds: 60,
              longBreakAfterSessions: 4,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('lengths round-trip to the second', () async {
    // ADR 0003: stored in seconds, no rounding at the persistence boundary.
    await repository.save(
      GardenSettings.defaults
          .withSessionLength(const Duration(minutes: 5, seconds: 30)),
    );

    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 5, seconds: 30),
    );
  });

  test('clamps out-of-range values on load', () async {
    // A later build may tighten a bound. A 0s length would throw on START,
    // so clamp to the nearest legal value.
    await database.into(database.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            sessionLengthSeconds: 0,
            breakLengthSeconds: 60 * 60 * 5,
            longBreakAfterSessions: 99,
          ),
        );

    final loaded = await repository.load();

    expect(loaded.sessionLength, SettingsRanges.sessionLength.min);
    expect(loaded.breakLength, SettingsRanges.breakLength.max);
    expect(loaded.longBreakAfter, SettingsRanges.longBreakAfter.max);
  });
}
