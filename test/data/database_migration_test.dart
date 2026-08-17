import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_analytics_event_log.dart';
import 'package:pip_garden/src/data/drift_cycle_store.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/data/drift_journal_repository.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:sqlite3/sqlite3.dart';

// Upgrade tests against database files written at each old schema version,
// not files the current code created.
void main() {
  late Directory directory;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('pip_garden_test');
    file = File('${directory.path}/pip_garden.sqlite');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  /// Version 1 schema with one completed session. Raw SQL so it can't drift
  /// with the current Dart code.
  void createVersion1Database() {
    final database = sqlite3.open(file.path)
      ..execute('''
        CREATE TABLE sessions (
          id TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          duration_seconds INTEGER NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
          paused_seconds INTEGER NOT NULL DEFAULT 0,
          ended_at INTEGER NULL,
          PRIMARY KEY (id)
        );
      ''')
      ..execute('''
        INSERT INTO sessions
          (id, started_at, duration_seconds, completed, paused_seconds, ended_at)
        VALUES ('older-session', 1786000000, 1500, 1, 0, 1786001500);
      ''')
      ..execute('PRAGMA user_version = 1;');
    database.close();
  }

  /// Version 2: sessions, settings and a stored session length.
  void createVersion2Database() {
    createVersion1Database();

    final database = sqlite3.open(file.path)
      ..execute('''
        CREATE TABLE settings (
          id INTEGER NOT NULL DEFAULT 1,
          session_length_seconds INTEGER NOT NULL,
          break_length_seconds INTEGER NOT NULL,
          long_break_after_sessions INTEGER NOT NULL,
          PRIMARY KEY (id),
          CHECK (id = 1)
        );
      ''')
      ..execute('''
        INSERT INTO settings
          (id, session_length_seconds, break_length_seconds,
           long_break_after_sessions)
        VALUES (1, 3000, 600, 3);
      ''')
      ..execute('PRAGMA user_version = 2;');
    database.close();
  }

  /// Version 3: sessions, settings and the garden, with one completed and one
  /// unfinished session.
  void createVersion3Database() {
    createVersion2Database();

    final database = sqlite3.open(file.path)
      ..execute('''
        CREATE TABLE plants (
          id TEXT NOT NULL,
          session_id TEXT NULL,
          type TEXT NOT NULL,
          species TEXT NOT NULL,
          growth_stage INTEGER NOT NULL,
          planted_at INTEGER NOT NULL,
          session_duration_seconds INTEGER NOT NULL,
          PRIMARY KEY (id),
          UNIQUE (session_id)
        );
      ''')
      ..execute('''
        INSERT INTO sessions
          (id, started_at, duration_seconds, completed, paused_seconds, ended_at)
        VALUES ('abandoned-session', 1786100000, 1500, 0, 0, NULL);
      ''')
      ..execute('PRAGMA user_version = 3;');
    database.close();
  }

  /// Version 4: unfinished session already voided, no haptics column.
  void createVersion4Database() {
    createVersion3Database();

    final database = sqlite3.open(file.path)
      ..execute('ALTER TABLE sessions ADD COLUMN outcome TEXT NULL;')
      ..execute('ALTER TABLE sessions ADD COLUMN paused_since INTEGER NULL;')
      ..execute("UPDATE sessions SET outcome = 'completed' WHERE completed = 1;")
      ..execute("UPDATE sessions SET outcome = 'voided' WHERE completed = 0;")
      ..execute('PRAGMA user_version = 4;');
    database.close();
  }

  /// Version 5: three plants with no plot.
  ///
  /// Inserted out of planted order on purpose so the backfill's ORDER BY
  /// actually matters.
  void createVersion5Database() {
    createVersion4Database();

    final database = sqlite3.open(file.path)
      ..execute(
        'ALTER TABLE settings ADD COLUMN haptics_enabled INTEGER NOT NULL '
        'DEFAULT 1 CHECK (haptics_enabled IN (0, 1));',
      )
      ..execute('''
        INSERT INTO plants
          (id, session_id, type, species, growth_stage, planted_at,
           session_duration_seconds)
        VALUES
          ('middle', NULL, 'herb', 'basil', 4, 1786200000, 900),
          ('newest', NULL, 'flower', 'tulip', 4, 1786300000, 1500),
          ('oldest', 'older-session', 'largeTree', 'oak', 4, 1786100000, 5400);
      ''')
      ..execute('PRAGMA user_version = 5;');
    database.close();
  }

  /// Version 6: plots assigned, no live surface column.
  void createVersion6Database() {
    createVersion5Database();

    final database = sqlite3.open(file.path)
      ..execute('ALTER TABLE plants ADD COLUMN plot_x INTEGER NULL;')
      ..execute('ALTER TABLE plants ADD COLUMN plot_y INTEGER NULL;')
      ..execute(
        'UPDATE plants SET plot_x = 0, plot_y = 0 WHERE id = @0;',
        ['oldest'],
      )
      ..execute(
        'UPDATE plants SET plot_x = 1, plot_y = 0 WHERE id = @0;',
        ['middle'],
      )
      ..execute(
        'UPDATE plants SET plot_x = 0, plot_y = 1 WHERE id = @0;',
        ['newest'],
      )
      ..execute('PRAGMA user_version = 6;');
    database.close();
  }

  /// Version 7: no auto-start columns.
  void createVersion7Database() {
    createVersion6Database();

    final database = sqlite3.open(file.path)
      ..execute(
        'ALTER TABLE settings ADD COLUMN live_surface_enabled INTEGER NOT NULL '
        'DEFAULT 1 CHECK (live_surface_enabled IN (0, 1));',
      )
      ..execute('PRAGMA user_version = 7;');
    database.close();
  }

  /// Version 8: no ambient sound column.
  void createVersion8Database() {
    createVersion7Database();

    final database = sqlite3.open(file.path)
      ..execute(
        'ALTER TABLE settings ADD COLUMN auto_start_break INTEGER NOT NULL '
        'DEFAULT 0 CHECK (auto_start_break IN (0, 1));',
      )
      ..execute(
        'ALTER TABLE settings ADD COLUMN auto_start_next_session INTEGER NOT '
        'NULL DEFAULT 0 CHECK (auto_start_next_session IN (0, 1));',
      )
      ..execute('PRAGMA user_version = 8;');
    database.close();
  }

  /// Version 9: no quiet mode columns.
  void createVersion9Database() {
    createVersion8Database();

    final database = sqlite3.open(file.path)
      ..execute(
        'ALTER TABLE settings ADD COLUMN ambient_sound TEXT NOT NULL '
        "DEFAULT 'silence';",
      )
      ..execute('PRAGMA user_version = 9;');
    database.close();
  }

  /// Version 10: no milestone column, and duration is still NOT NULL.
  ///
  /// The 10 -> 11 step rebuilds the table to drop that NOT NULL, so this garden
  /// is what the rebuild test expects to survive.
  void createVersion10Database() {
    createVersion9Database();

    final database = sqlite3.open(file.path)
      ..execute(
        'ALTER TABLE settings ADD COLUMN quiet_mode_enabled INTEGER NOT NULL '
        'DEFAULT 0 CHECK (quiet_mode_enabled IN (0, 1));',
      )
      ..execute(
        'ALTER TABLE settings ADD COLUMN quiet_mode_hint_dismissed INTEGER '
        'NOT NULL DEFAULT 0 CHECK (quiet_mode_hint_dismissed IN (0, 1));',
      )
      ..execute('PRAGMA user_version = 10;');
    database.close();
  }

  /// Version 11: plants rebuilt with nullable duration and milestone, one
  /// milestone plant, no indexes.
  ///
  /// The rebuild is written out by hand so this fixture doesn't change if the
  /// app's migration step does.
  void createVersion11Database() {
    createVersion10Database();

    final database = sqlite3.open(file.path)
      ..execute('''
        CREATE TABLE plants_v11 (
          id TEXT NOT NULL,
          session_id TEXT NULL,
          type TEXT NOT NULL,
          species TEXT NOT NULL,
          growth_stage INTEGER NOT NULL,
          planted_at INTEGER NOT NULL,
          session_duration_seconds INTEGER NULL,
          milestone_sessions INTEGER NULL,
          plot_x INTEGER NULL,
          plot_y INTEGER NULL,
          PRIMARY KEY (id),
          UNIQUE (session_id),
          UNIQUE (milestone_sessions)
        );
      ''')
      ..execute('''
        INSERT INTO plants_v11
          (id, session_id, type, species, growth_stage, planted_at,
           session_duration_seconds, milestone_sessions, plot_x, plot_y)
        SELECT
          id, session_id, type, species, growth_stage, planted_at,
          session_duration_seconds, NULL, plot_x, plot_y
        FROM plants;
      ''')
      ..execute('DROP TABLE plants;')
      ..execute('ALTER TABLE plants_v11 RENAME TO plants;')
      ..execute('''
        INSERT INTO plants
          (id, session_id, type, species, growth_stage, planted_at,
           session_duration_seconds, milestone_sessions, plot_x, plot_y)
        VALUES ('awarded', NULL, 'bonus', 'bonsai', 4, 1786200000, NULL, 10,
                1, 1);
      ''')
      ..execute('PRAGMA user_version = 11;');
    database.close();
  }

  /// Version 12: the two indexes, and a settings row with no onboarding flag.
  /// The stored settings make this an existing install, which is what the
  /// 12 -> 13 step cares about.
  void createVersion12Database() {
    createVersion11Database();

    final database = sqlite3.open(file.path)
      ..execute('CREATE INDEX IF NOT EXISTS sessions_completed_started_at '
          'ON sessions (completed, started_at);')
      ..execute('CREATE INDEX IF NOT EXISTS plants_planted_at '
          'ON plants (planted_at);')
      ..execute('PRAGMA user_version = 12;');
    database.close();
  }

  /// Version 13: onboarding flag set as the upgrade sets it for existing users.
  void createVersion13Database() {
    createVersion12Database();

    final database = sqlite3.open(file.path)
      ..execute(
        'ALTER TABLE settings ADD COLUMN onboarding_completed INTEGER NOT NULL '
        'DEFAULT 0 CHECK (onboarding_completed IN (0, 1));',
      )
      ..execute('UPDATE settings SET onboarding_completed = 1;')
      ..execute('PRAGMA user_version = 13;');
    database.close();
  }

  /// Version 14: the event log with a couple of rows.
  void createVersion14Database() {
    createVersion13Database();

    final database = sqlite3.open(file.path)
      ..execute('''
        CREATE TABLE analytics_events (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          parameters TEXT NOT NULL,
          recorded_at INTEGER NOT NULL
        );
      ''')
      ..execute('CREATE INDEX IF NOT EXISTS analytics_events_name '
          'ON analytics_events (name);')
      ..execute('''
        INSERT INTO analytics_events (name, parameters, recorded_at)
        VALUES ('app_opened', '{"days_since_last_open":null,"streak_days":0}',
                1786400000);
      ''')
      ..execute('PRAGMA user_version = 14;');
    database.close();
  }

  /// Version 15: empty entitlements table, no garden theme column.
  void createVersion15Database() {
    createVersion14Database();

    final database = sqlite3.open(file.path)
      ..execute('''
        CREATE TABLE entitlements (
          product_id TEXT NOT NULL,
          granted_at INTEGER NOT NULL,
          PRIMARY KEY (product_id)
        );
      ''')
      ..execute('PRAGMA user_version = 15;');
    database.close();
  }

  /// Version 16: no decor table.
  void createVersion16Database() {
    createVersion15Database();

    final database = sqlite3.open(file.path)
      ..execute(
        '''ALTER TABLE settings ADD COLUMN garden_theme TEXT NOT NULL '''
        """DEFAULT 'zen';""",
      )
      ..execute('PRAGMA user_version = 16;');
    database.close();
  }

  /// Version 17: empty decor table, and a granted premium entitlement.
  ///
  /// Granted on purpose: version 18 drops that table, and the interesting case
  /// is a user who paid.
  void createVersion17Database() {
    createVersion16Database();

    final database = sqlite3.open(file.path)
      ..execute('''
        CREATE TABLE decor (
          id TEXT NOT NULL,
          kind TEXT NOT NULL,
          plot_x INTEGER NOT NULL,
          plot_y INTEGER NOT NULL,
          placed_at INTEGER NOT NULL,
          PRIMARY KEY (id),
          UNIQUE (plot_x, plot_y)
        );
      ''')
      ..execute('''
        INSERT INTO decor (id, kind, plot_x, plot_y, placed_at)
        VALUES ('bench-1', 'bench', 2, -1, 1786400000);
      ''')
      ..execute('''
        INSERT INTO entitlements (product_id, granted_at)
        VALUES ('com.pomodorogarden.premium_unlock', 1786400000);
      ''')
      ..execute('PRAGMA user_version = 17;');
    database.close();
  }

  /// Version 18: entitlements gone, no end sound column.
  ///
  /// Ambient bed set to rain so we can check version 19's new sound column
  /// doesn't get mixed up with it.
  void createVersion18Database() {
    createVersion17Database();

    final database = sqlite3.open(file.path)
      ..execute('DROP TABLE IF EXISTS entitlements;')
      ..execute("""UPDATE settings SET ambient_sound = 'rain';""")
      ..execute('PRAGMA user_version = 18;');
    database.close();
  }

  testWidgets('upgrading from version 1 keeps the sessions already recorded',
      (tester) async {
    createVersion1Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    // The migration runs on first use, not on construction.
    final sessions = await DriftSessionRepository(database).completedSessions();

    expect(sessions, hasLength(1));
    expect(sessions.single.id, 'older-session');
    expect(sessions.single.plannedDuration, const Duration(minutes: 25));
  });

  testWidgets('upgrading from version 1 adds settings, on the defaults',
      (tester) async {
    createVersion1Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final repository = DriftSettingsRepository(database);

    // Same defaults as a fresh install.
    expect(await repository.load(), GardenSettings.defaults);

    await repository.save(
      GardenSettings.defaults.withSessionLength(const Duration(minutes: 50)),
    );
    expect((await repository.load()).sessionLength, const Duration(minutes: 50));
  });

  testWidgets('upgrading from version 1 walks every step, not just the last',
      (tester) async {
    // Skipping releases must still run every step, not jump to the latest.
    createVersion1Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    expect(await DriftPlantRepository(database).plants(), isEmpty);
    expect(await DriftSettingsRepository(database).load(),
        GardenSettings.defaults);
    expect((await DriftSessionRepository(database).completedSessions()).single.id,
        'older-session');
  });

  testWidgets('upgrading from version 2 adds the garden and keeps the settings',
      (tester) async {
    createVersion2Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    expect(
      await DriftSettingsRepository(database).load(),
      const GardenSettings(
        sessionLength: Duration(minutes: 50),
        breakLength: Duration(minutes: 10),
        longBreakAfter: 3,
        hapticsEnabled: true,
        liveSurfaceEnabled: true,
        autoStartBreak: false,
        autoStartNextSession: false,
        ambientSound: AmbientSound.silence,
        // Existing users keep the chime they've always had.
        endSound: EndSound.windChime,
        // Only the free theme can come from an upgrade.
        gardenTheme: GardenTheme.zen,
        quietModeEnabled: false,
        quietModeHintDismissed: false,
        // Existing settings row means an existing user, so skip onboarding.
        onboardingCompleted: true,
      ),
    );

    // Starts empty. Old sessions never recorded a species, so don't invent
    // plants for them.
    final garden = DriftPlantRepository(database);
    expect(await garden.plants(), isEmpty);

    await garden.save(
      Plant(
        id: 'plant-1',
        sessionId: 'older-session',
        type: PlantType.flower,
        species: PlantSpecies.sunflower,
        stage: GrowthStage.mature,
        plantedAt: DateTime.utc(2026, 8, 11, 9, 41),
        sessionDuration: const Duration(minutes: 25),
      ),
    );
    expect((await garden.plants()).single.species, PlantSpecies.sunflower);
  });

  testWidgets('upgrading from version 3 voids unfinished sessions',
      (tester) async {
    // From version 4 an unfinished session is restored at launch. Left open,
    // this stale one would be found long past 25 minutes and award a plant for
    // nothing.
    createVersion3Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final sessions = DriftSessionRepository(database);

    expect(await sessions.inFlightSession(), isNull,
        reason: 'no unfinished session should be restored');

    // Voided, not cancelled: the app went away, nobody chose to end it.
    final rows =
        await database.customSelect('SELECT id, outcome FROM sessions').get();
    expect(
      {
        for (final row in rows)
          row.read<String>('id'): row.readNullable<String>('outcome'),
      },
      {'older-session': 'completed', 'abandoned-session': 'voided'},
    );
    expect(await DriftPlantRepository(database).plants(), isEmpty);

    expect((await sessions.completedSessions()).single.id, 'older-session');
  });

  testWidgets('upgrading from version 3 leaves room for a pause', (tester) async {
    createVersion3Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final sessions = DriftSessionRepository(database);

    final anchor = DateTime.utc(2026, 8, 12, 10);
    await sessions.save(
      FocusSession(
        id: 'after-the-upgrade',
        startedAt: anchor,
        plannedDuration: const Duration(minutes: 25),
      ).pausedAt(anchor.add(const Duration(minutes: 3))),
    );

    final restored = (await sessions.inFlightSession())!;
    expect(restored.id, 'after-the-upgrade');
    expect(restored.pausedSince, anchor.add(const Duration(minutes: 3)));
  });

  testWidgets('upgrading from version 4 defaults haptics on', (tester) async {
    createVersion4Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final repository = DriftSettingsRepository(database);

    // Lengths untouched, and haptics reads as on.
    expect(
      await repository.load(),
      const GardenSettings(
        sessionLength: Duration(minutes: 50),
        breakLength: Duration(minutes: 10),
        longBreakAfter: 3,
        hapticsEnabled: true,
        liveSurfaceEnabled: true,
        autoStartBreak: false,
        autoStartNextSession: false,
        ambientSound: AmbientSound.silence,
        // Existing users keep the chime they've always had.
        endSound: EndSound.windChime,
        // Only the free theme can come from an upgrade.
        gardenTheme: GardenTheme.zen,
        quietModeEnabled: false,
        quietModeHintDismissed: false,
        // Existing settings row means an existing user, so skip onboarding.
        onboardingCompleted: true,
      ),
    );

    await repository.save(
      (await repository.load()).withHaptics(enabled: false),
    );
    expect((await repository.load()).hapticsEnabled, isFalse);
  });

  testWidgets('upgrading from version 5 gives an existing garden its plots',
      (tester) async {
    // Without the backfill every existing plant would have no plot and the
    // garden would render empty.
    createVersion5Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    final garden = await DriftPlantRepository(database).plants();
    expect(
      {for (final plant in garden) plant.id: plant.plot},
      {
        // Oldest nearest the middle, then outwards in placement order.
        'oldest': GardenPlots.inPlacementOrder[0],
        'middle': GardenPlots.inPlacementOrder[1],
        'newest': GardenPlots.inPlacementOrder[2],
      },
    );

    expect(garden.map((plant) => plant.species),
        containsAll(<PlantSpecies>[PlantSpecies.oak, PlantSpecies.basil]));
  });

  testWidgets('upgrading from version 5 leaves room for new plants',
      (tester) async {
    createVersion5Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final garden = DriftPlantRepository(database);

    // Backfilled plots count as occupied: the next plant goes in the fourth.
    expect(
      GardenPlots.nextFree(await garden.occupiedPlots()),
      GardenPlots.inPlacementOrder[3],
    );
  });

  testWidgets('upgrading from version 6 finds the live surface switch on',
      (tester) async {
    createVersion6Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final repository = DriftSettingsRepository(database);

    // Comes from the column default. Must be on, or the feature silently
    // turns off for every existing user.
    expect((await repository.load()).liveSurfaceEnabled, isTrue);
    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 50),
    );

    await repository.save(
      (await repository.load()).withLiveSurface(enabled: false),
    );
    expect((await repository.load()).liveSurfaceEnabled, isFalse);
  });

  testWidgets('upgrading from version 7 leaves both auto-start switches off',
      (tester) async {
    createVersion7Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final repository = DriftSettingsRepository(database);

    // Both switches ship off. Defaulting to on would start timers for existing
    // users who never asked for it.
    expect((await repository.load()).autoStartBreak, isFalse);
    expect((await repository.load()).autoStartNextSession, isFalse);

    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 50),
    );
    expect((await repository.load()).liveSurfaceEnabled, isTrue);

    await repository.save(
      (await repository.load())
          .withAutoStartBreak(enabled: true)
          .withAutoStartNextSession(enabled: true),
    );
    expect((await repository.load()).autoStartBreak, isTrue);
    expect((await repository.load()).autoStartNextSession, isTrue);
  });

  testWidgets('upgrading from version 8 leaves the session silent',
      (tester) async {
    createVersion8Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final repository = DriftSettingsRepository(database);

    // Silence. Upgrading and hearing rain on START would be very noticeable.
    expect((await repository.load()).ambientSound, AmbientSound.silence);

    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 50),
    );
    expect((await repository.load()).liveSurfaceEnabled, isTrue);

    await repository.save(
      (await repository.load()).withAmbientSound(AmbientSound.rain),
    );
    expect((await repository.load()).ambientSound, AmbientSound.rain);
  });

  testWidgets('upgrading from version 9 leaves quiet mode off',
      (tester) async {
    createVersion9Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final repository = DriftSettingsRepository(database);

    // Quiet mode decides which calls get missed, so an upgrade must never turn
    // it on.
    expect((await repository.load()).quietModeEnabled, isFalse);
    expect((await repository.load()).quietModeHintDismissed, isFalse);

    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 50),
    );
    expect((await repository.load()).liveSurfaceEnabled, isTrue);

    await repository.save(
      (await repository.load())
          .withQuietMode(enabled: true)
          .withQuietModeHintDismissed(),
    );
    expect((await repository.load()).quietModeEnabled, isTrue);
    expect((await repository.load()).quietModeHintDismissed, isTrue);
  });

  testWidgets('upgrading from version 10 keeps the garden through the rebuild',
      (tester) async {
    // The only step that rebuilds a table (SQLite can't drop NOT NULL any other
    // way). Every plant must come across with plot, species and duration.
    createVersion10Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final garden = DriftPlantRepository(database);

    final plants = {for (final plant in await garden.plants()) plant.id: plant};
    expect(plants.keys, containsAll(<String>['oldest', 'middle', 'newest']));
    expect(plants['oldest']!.species, PlantSpecies.oak);
    expect(plants['oldest']!.sessionDuration, const Duration(minutes: 90));
    expect(plants['oldest']!.sessionId, 'older-session');
    expect(
      plants.map((id, plant) => MapEntry(id, plant.plot)),
      {
        // The plots version 6 wrote, not what today's placement would pick.
        'oldest': const GardenPlot(0, 0),
        'middle': const GardenPlot(1, 0),
        'newest': const GardenPlot(0, 1),
      },
    );

    expect(plants.values.every((plant) => plant.milestone == null), isTrue);
    expect(await garden.awardedMilestones(), isEmpty);

    // The unique index makes a second award of the same milestone fail.
    await garden.save(Plant.forMilestone(
      Milestone.ten,
      id: 'awarded',
      plantedAt: DateTime.utc(2026, 8, 11),
      plot: GardenPlots.nextFree(await garden.occupiedPlots()),
    ));
    expect(await garden.awardedMilestones(), {Milestone.ten});
  });

  testWidgets('upgrading from version 11 adds indexes, keeps rows',
      (tester) async {
    // Adds indexes only. Must not disturb any existing history.
    createVersion11Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    final journal = DriftJournalRepository(database);
    // Version 1's completed and abandoned sessions, plus the voided one.
    expect((await journal.sessionsEver()).sessions, 1);
    expect((await journal.plantsEver()), const PlantTally(plants: 4, bonusPlants: 1));
    expect(await DriftPlantRepository(database).plants(), hasLength(4));

    final indexes = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')),
      containsAll(<String>['sessions_completed_started_at', 'plants_planted_at']),
    );
  });

  testWidgets('upgrading from version 12 skips onboarding', (tester) async {
    // A settings row on disk means an existing user. Don't onboard them.
    createVersion12Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    final settings = await DriftSettingsRepository(database).load();

    expect(settings.onboardingCompleted, isTrue);
    // The fixture has a 50 min session and 10 min break from version 2.
    expect(settings.sessionLength, const Duration(minutes: 50));
    expect(settings.breakLength, const Duration(minutes: 10));
    expect(await DriftPlantRepository(database).plants(), hasLength(4));
  });

  testWidgets('upgrading from version 13 adds an empty event log',
      (tester) async {
    // Nothing to backfill: old sessions say nothing about app opens.
    createVersion13Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final log = DriftAnalyticsEventLog(database);

    expect(await log.recent(), isEmpty);
    expect(await DriftPlantRepository(database).plants(), hasLength(4));
    expect((await DriftSettingsRepository(database).load()).sessionLength,
        const Duration(minutes: 50));

    await log.append(
      SessionStarted.of(const Duration(minutes: 25)),
      at: DateTime.utc(2026, 8, 20),
    );
    expect((await log.recent()).single.known, AnalyticsEventName.sessionStarted);
  });

  testWidgets('upgrading from version 14 keeps the garden', (tester) async {
    // Version 15 creates entitlements and 18 drops it, so this walks both.
    createVersion14Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    expect(await DriftPlantRepository(database).plants(), hasLength(4));
    expect((await DriftSettingsRepository(database).load()).sessionLength,
        const Duration(minutes: 50));
    expect(await _tableNames(database), isNot(contains('entitlements')));
  });

  testWidgets('upgrading from version 15 arrives in the default garden theme',
      (tester) async {
    // Zen is the old default palette, so the garden looks the same.
    createVersion15Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final settings = DriftSettingsRepository(database);

    expect((await settings.load()).gardenTheme, GardenTheme.zen);

    expect((await settings.load()).sessionLength, const Duration(minutes: 50));
    expect(await DriftPlantRepository(database).plants(), hasLength(4));

    await settings.save(
      (await settings.load()).withGardenTheme(GardenTheme.wildflower),
    );
    expect((await settings.load()).gardenTheme, GardenTheme.wildflower);
  });

  testWidgets('upgrading from version 16 adds an empty decor table',
      (tester) async {
    // Nothing to backfill, there was no decor before this version.
    createVersion16Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final arrangement = DriftDecorRepository(database);

    expect(await arrangement.decor(), isEmpty);
    expect(await DriftPlantRepository(database).plants(), hasLength(4));
    expect((await DriftSettingsRepository(database).load()).sessionLength,
        const Duration(minutes: 50));

    await arrangement.save(Decor(
      id: 'lantern-1',
      kind: DecorKind.lantern,
      plot: const GardenPlot(2, -1),
      placedAt: DateTime.utc(2026, 8, 26),
    ));
    expect((await arrangement.decor()).single.kind, DecorKind.lantern);
  });

  testWidgets('upgrading from version 17 drops entitlements, keeps the garden',
      (tester) async {
    // Removes the paywall table. Plants, sessions, decor and settings live in
    // other tables and must come through untouched. See ADR 0005
    createVersion17Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    expect(await _tableNames(database), isNot(contains('entitlements')));
    expect(await DriftPlantRepository(database).plants(), hasLength(4));
    expect((await DriftDecorRepository(database).decor()).single.kind,
        DecorKind.bench);
    expect((await DriftSettingsRepository(database).load()).sessionLength,
        const Duration(minutes: 50));
  });

  testWidgets('upgrading from version 17 unlocks premium themes',
      (tester) async {
    // A premium theme can now be stored and read back.
    createVersion17Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final settings = DriftSettingsRepository(database);

    await settings.save(
      (await settings.load()).withGardenTheme(GardenTheme.tropical),
    );
    expect((await settings.load()).gardenTheme, GardenTheme.tropical);
  });

  testWidgets('upgrading from version 18 keeps the wind chime', (tester) async {
    // Default is the wind chime, which every existing user already hears.
    // Defaulting to none would silently remove it.
    createVersion18Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final settings = DriftSettingsRepository(database);

    expect((await settings.load()).endSound, EndSound.windChime);

    // The ambient bed is still rain; the two sound columns aren't crossed.
    expect((await settings.load()).ambientSound, AmbientSound.rain);

    expect((await settings.load()).sessionLength, const Duration(minutes: 50));
    expect(await DriftPlantRepository(database).plants(), hasLength(4));
    expect((await DriftDecorRepository(database).decor()).single.kind,
        DecorKind.bench);

    await settings.save((await settings.load()).withEndSound(EndSound.none));
    expect((await settings.load()).endSound, EndSound.none);

    // 19 -> 20 runs too: the cycle row starts at session one.
    final cycle = DriftCycleStore(database);
    expect(await cycle.load(), 0);
    await cycle.save(3);
    expect(await cycle.load(), 3);
  });

  testWidgets('fresh database is created at the current version',
      (tester) async {
    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    expect(database.schemaVersion, 20);
    expect(await DriftSettingsRepository(database).load(),
        GardenSettings.defaults);
    expect(await DriftPlantRepository(database).plants(), isEmpty);

    final tables = await _tableNames(database);
    expect(
      tables,
      containsAll(<String>[
        'sessions',
        'settings',
        'plants',
        'analytics_events',
        'decor',
        'cycle',
      ]),
    );
    // onCreate builds today's schema, which never had this table.
    expect(tables, isNot(contains('entitlements')));
  });
}

Future<List<String>> _tableNames(AppDatabase database) async {
  final rows = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return [for (final row in rows) row.read<String>('name')];
}
