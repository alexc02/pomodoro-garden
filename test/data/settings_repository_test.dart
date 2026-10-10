import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_settings_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// Tested against real SQLite, in memory, for the same reason the session
/// repository is: this is where the schema, the mapping and the queries have to
/// agree with the database rather than with each other.
void main() {
  late AppDatabase database;
  late SettingsRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = DriftSettingsRepository(database);
  });

  tearDown(() => database.close());

  test('a database nobody has saved settings to loads the defaults', () async {
    // First run. There is no row, and that is not an error — it is what an app
    // that has just been installed looks like.
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

  test('haptics turned off stay off', () async {
    // A boolean that only ever goes false is the field an upsert built from a
    // data class gets wrong — see the note on `save` in the session repository.
    // Written out on its own because "the setting the user changed is the one
    // that did not survive" is the failure this whole ticket would be judged by.
    await repository.save(GardenSettings.defaults.withHaptics(enabled: false));
    expect((await repository.load()).hapticsEnabled, isFalse);

    await repository.save(GardenSettings.defaults.withHaptics(enabled: true));
    expect((await repository.load()).hapticsEnabled, isTrue);
  });

  test('quiet mode and the hint about it survive a relaunch each on their own',
      () async {
    // Two booleans that move independently, and the second one only ever moves
    // one way. A row that carried the hint's dismissal into quiet mode — or
    // either of them into the other — would silence a phone nobody asked to
    // silence, which is the worst bug this ticket could ship.
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

  test('onboarding, once finished, is finished on the next launch too',
      () async {
    // REQ-003's "shows once" is this line: the flag is what a relaunch reads,
    // so a column that did not survive the round trip would greet a returning
    // user with a welcome screen every morning.
    await repository.save(GardenSettings.defaults.withOnboardingCompleted());
    expect((await repository.load()).onboardingCompleted, isTrue);

    // And the debug reset really does put it back, rather than being a value
    // the row quietly refuses to move.
    await repository.save(
      (await repository.load()).withOnboardingReset(),
    );
    expect((await repository.load()).onboardingCompleted, isFalse);
  });

  test('the ambient bed comes back as the bed, not as its name', () async {
    // REQ-012's "persists as the default for the next session" is this line
    // and nothing else: there is no per-session ambience state, only a setting
    // that a running session happens to read.
    for (final sound in AmbientSound.values) {
      await repository.save(GardenSettings.defaults.withAmbientSound(sound));
      expect((await repository.load()).ambientSound, sound);
    }
  });

  test('a bed this build has never heard of reads as silence', () async {
    // A row written by a build that shipped a seventh sound. Silence is the
    // reading that cannot be wrong, and it is what the user of *this* build
    // would get if they had never chosen anything.
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

  test('saving twice updates the one row rather than adding another', () async {
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
    // The constraint, not the repository, is what makes "single row" true: a
    // later ticket writing its own insert must not be able to create a second
    // set of settings for the app to pick between.
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

  test('lengths survive the round trip to the second', () async {
    // ADR 0003: seconds all the way to the column. A length that is not a whole
    // number of minutes is not something the sliders can pick, but rounding it
    // here would be a lossy mapping at the persistence boundary, which is the
    // thing that ADR exists to avoid.
    await repository.save(
      GardenSettings.defaults
          .withSessionLength(const Duration(minutes: 5, seconds: 30)),
    );

    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 5, seconds: 30),
    );
  });

  test('a stored value outside its range is clamped on the way out', () async {
    // The row is the app's memory of a choice, and a future build may narrow a
    // bound under a row written by this one. Loading a 0-second session length
    // and handing it to SessionMachine would throw on the next START; loading
    // the nearest legal length gives the user a timer that works.
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
