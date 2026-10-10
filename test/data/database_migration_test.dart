import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_analytics_event_log.dart';
import 'package:pomodoro_garden/src/data/drift_decor_repository.dart';
import 'package:pomodoro_garden/src/data/drift_journal_repository.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/data/drift_session_repository.dart';
import 'package:pomodoro_garden/src/data/drift_settings_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// The upgrade path, exercised against a database file that really is at the
/// old version rather than one the current code created.
///
/// This is the case no other test covers: an installed app whose file predates
/// this ticket. Opening it must add the settings table *and* leave the sessions
/// already in it alone — a migration that quietly recreated the database would
/// pass every other test in the suite and delete a user's garden.
void main() {
  late Directory directory;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('pomodoro_garden_test');
    file = File('${directory.path}/pomodoro_garden.sqlite');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  /// Writes the schema exactly as version 1 shipped it, with one completed
  /// session in it. Raw SQL, because the point is to produce a file the current
  /// Dart code could not have produced.
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

  /// The same file, brought up to the shape version 2 shipped: sessions, plus
  /// the settings table, plus a stored session length. Still raw SQL, and still
  /// a file no build of this app could produce today.
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

  /// The same file at version 3: sessions, settings and the garden, with one
  /// completed session and one that was started and never finished — the row
  /// shape ticket 05 has to make sense of.
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

  /// The same file at version 4: the shape ticket 05 left behind, with its
  /// unfinished session already closed as voided and a settings row that has
  /// never heard of haptics.
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

  /// The same file at version 5: the shape ticket 06 left behind, with a garden
  /// of three plants that have never heard of a plot.
  ///
  /// Inserted out of planted order on purpose. The backfill lays a garden out
  /// oldest-first, and rows come back in whatever order SQLite likes unless
  /// something asks otherwise — so an insertion order that disagrees with the
  /// planting order is what makes that `ORDER BY` load-bearing.
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

  /// The same file at version 6: the shape ticket 07 left behind, with its
  /// garden laid out and a settings row that has never heard of a live
  /// session surface.
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

  /// The same file at version 7: the shape ticket 08 left behind, with a
  /// settings row that has never heard of an auto-start switch.
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

  /// The same file at version 8: the shape ticket 09 left behind, with a
  /// settings row that has never heard of an ambient bed.
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

  /// The same file at version 9: the shape ticket 10 left behind, with a
  /// settings row that has never heard of quiet mode.
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

  /// The same file at version 10: the shape ticket 11 left behind, with a
  /// garden whose plants have never heard of a milestone and whose session
  /// duration is still a column that cannot be null.
  ///
  /// That NOT NULL is the point of this fixture. Ticket 13's step rebuilds the
  /// whole table to drop it, and a rebuild is the one kind of migration that
  /// can quietly lose rows — so the garden written here is the garden the test
  /// after it expects to find still standing.
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

  /// The same file at version 11: the shape ticket 13 left behind, with the
  /// plants table rebuilt around a nullable duration and a milestone, one
  /// milestone plant standing in the garden, and no index on anything.
  ///
  /// The rebuild is written out rather than run through the app's own migration
  /// so that this fixture stays what version 11 shipped even if a later ticket
  /// changes what that step does.
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

  /// The same file at version 12: ticket 15's two indexes, and a settings row
  /// that has never heard of onboarding.
  ///
  /// The settings row matters more here than the indexes do. It is what makes
  /// this file an *installed* app rather than a fresh one — a user with stored
  /// settings and a garden — which is the case the 12 → 13 step exists for.
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

  /// The same file at version 13: ticket 16's onboarding flag, set the way that
  /// step sets it for a user who was already here.
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

  /// The same file at version 14: ticket 17's event log, with a couple of rows
  /// in it, and no notion that there is anything to buy.
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

  /// The same file at version 15: ticket 18's entitlements table, empty,
  /// belonging to a user who has bought nothing and has never been offered a
  /// garden theme.
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

  /// The same file at version 16: everything ticket 19 shipped, and no decor.
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

  /// The same file at version 17: ticket 20's decor table, empty, on a device
  /// that bought the premium unlock while there was still one to buy.
  ///
  /// The entitlement is *granted* here on purpose. Version 18 drops that table,
  /// and the case worth covering is not the empty one — it is the user who
  /// actually paid, whose row is about to go.
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

  /// The same file at version 18: the paywall's table gone, and a settings row
  /// that has never heard of an end sound.
  ///
  /// The bed is set to something other than silence on purpose. Version 19 adds
  /// a *second* sound column beside it, and the case worth covering is that the
  /// two do not get crossed — a user listening to rain under their sessions
  /// must not come out of this upgrade with rain as their completion sound.
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

    // An upgrading user has never saved a setting, so they get the same
    // defaults a fresh install gets — and can then change one.
    expect(await repository.load(), GardenSettings.defaults);

    await repository.save(
      GardenSettings.defaults.withSessionLength(const Duration(minutes: 50)),
    );
    expect((await repository.load()).sessionLength, const Duration(minutes: 50));
  });

  testWidgets('upgrading from version 1 walks every step, not just the last',
      (tester) async {
    // A user who skipped a release arrives at version 1 and has to end up with
    // both of the tables added since — which is the case a migration that
    // jumped straight to the current version would get wrong.
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

    // The settings the user had chosen are untouched by the upgrade.
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
        // The chime, which is the sound this user has been hearing since
        // ticket 06 — see the version-18 case below.
        endSound: EndSound.windChime,
        // The free theme, which is what a row written before ticket 19 means
        // and the only thing an upgrade may hand out.
        gardenTheme: GardenTheme.zen,
        quietModeEnabled: false,
        quietModeHintDismissed: false,
        // A settings row on disk before ticket 16 is a user already using the
        // app, and the upgrade says so rather than welcoming them.
        onboardingCompleted: true,
      ),
    );

    // Their garden starts empty. The sessions they completed before this
    // version grew nothing that was ever written down, and inventing plants
    // for them would mean inventing which species they were.
    final garden = DriftPlantRepository(database);
    expect(await garden.plants(), isEmpty);

    // And it is a working garden, not just an empty one.
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

  testWidgets('upgrading from version 3 closes the sessions nobody ever '
      'finished', (tester) async {
    // The row that makes this step worth testing. Before version 4 an
    // unfinished session was just an unfinished row; from version 4 it is a
    // session the app finds at launch and puts back in flight. Left open, this
    // one — started long ago and abandoned — would be restored on the first
    // launch after the upgrade, found to be long past its 25 minutes, and would
    // hand the user a plant for work nobody did.
    createVersion3Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final sessions = DriftSessionRepository(database);

    expect(await sessions.inFlightSession(), isNull,
        reason: 'nothing an upgrading user left behind comes back to life');

    // Voided rather than cancelled: nobody decided to end it, the app went
    // away. And it grew nothing, then or now.
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

    // And the session the user did complete is still theirs.
    expect((await sessions.completedSessions()).single.id, 'older-session');
  });

  testWidgets('upgrading from version 3 leaves room for a pause', (tester) async {
    createVersion3Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final sessions = DriftSessionRepository(database);

    // The columns this version adds are usable, not merely present.
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

  testWidgets('upgrading from version 4 leaves haptics on for a user who chose '
      'their lengths before the switch existed', (tester) async {
    createVersion4Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final repository = DriftSettingsRepository(database);

    // Their stored lengths are untouched, and the setting they have never seen
    // reads as on rather than as off or as missing.
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
        // The chime, which is the sound this user has been hearing since
        // ticket 06 — see the version-18 case below.
        endSound: EndSound.windChime,
        // The free theme, which is what a row written before ticket 19 means
        // and the only thing an upgrade may hand out.
        gardenTheme: GardenTheme.zen,
        quietModeEnabled: false,
        quietModeHintDismissed: false,
        // A settings row on disk before ticket 16 is a user already using the
        // app, and the upgrade says so rather than welcoming them.
        onboardingCompleted: true,
      ),
    );

    // And the switch works from the moment it appears.
    await repository.save(
      (await repository.load()).withHaptics(enabled: false),
    );
    expect((await repository.load()).hapticsEnabled, isFalse);
  });

  testWidgets('upgrading from version 5 gives an existing garden its plots',
      (tester) async {
    // The step that makes this ticket work for a user who already has a garden.
    // Left null, every plant they have would be a plant with nowhere to stand,
    // and the garden they opened after the upgrade would be empty soil.
    createVersion5Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    final garden = await DriftPlantRepository(database).plants();
    expect(
      {for (final plant in garden) plant.id: plant.plot},
      {
        // Oldest nearest the middle, then outwards in the placement order —
        // the same order the app would have planted them in.
        'oldest': GardenPlots.inPlacementOrder[0],
        'middle': GardenPlots.inPlacementOrder[1],
        'newest': GardenPlots.inPlacementOrder[2],
      },
    );

    // And nothing else about the plants they already had moved.
    expect(garden.map((plant) => plant.species),
        containsAll(<PlantSpecies>[PlantSpecies.oak, PlantSpecies.basil]));
  });

  testWidgets('upgrading from version 5 lays a garden out somewhere the app can '
      'go on planting into', (tester) async {
    createVersion5Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final garden = DriftPlantRepository(database);

    // The backfilled plots are real occupancy, not decoration: the next plant
    // goes into the fourth plot rather than on top of the first.
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

    // REQ-033's default, reached the way an upgrading user reaches it: the
    // column's own default, over a row written before the switch existed. A
    // user who has never seen the control means "on", and a nullable column
    // read as false would silently turn the feature off for everyone who
    // already had the app.
    expect((await repository.load()).liveSurfaceEnabled, isTrue);
    // Their other settings came through untouched.
    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 50),
    );

    // And the switch works from the moment it appears.
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

    // The opposite default from the two steps before this one, and deliberately
    // so. REQ-032 ships both switches off, and a user who has never been asked
    // whether the app may start a timer for them must not find that it has
    // started one — which is exactly what a column defaulted to on would do to
    // everybody who already had the app.
    expect((await repository.load()).autoStartBreak, isFalse);
    expect((await repository.load()).autoStartNextSession, isFalse);

    // Their other settings came through untouched.
    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 50),
    );
    expect((await repository.load()).liveSurfaceEnabled, isTrue);

    // And the switches work from the moment they appear.
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

    // REQ-012's default, reached the way an upgrading user reaches it. Silence
    // rather than a bed, and this is the one migration default that would be
    // *noticed* if it were wrong: a user who upgrades and taps START should
    // not find their phone making rain, because nobody asked them.
    expect((await repository.load()).ambientSound, AmbientSound.silence);

    // Their other settings came through untouched.
    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 50),
    );
    expect((await repository.load()).liveSurfaceEnabled, isTrue);

    // And the picker works from the moment it appears.
    await repository.save(
      (await repository.load()).withAmbientSound(AmbientSound.rain),
    );
    expect((await repository.load()).ambientSound, AmbientSound.rain);
  });

  testWidgets('upgrading from version 9 leaves the phone as loud as it was',
      (tester) async {
    createVersion9Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final repository = DriftSettingsRepository(database);

    // REQ-014's default, reached the way an upgrading user reaches it, and the
    // most consequential of all the migration defaults: quiet mode decides
    // which of their calls a user misses. Nobody who has never seen the switch
    // has asked for that, so an upgrade must not turn it on.
    expect((await repository.load()).quietModeEnabled, isFalse);
    // And the hint about it has not been dismissed by somebody who has never
    // been shown it.
    expect((await repository.load()).quietModeHintDismissed, isFalse);

    // Their other settings came through untouched.
    expect(
      (await repository.load()).sessionLength,
      const Duration(minutes: 50),
    );
    expect((await repository.load()).liveSurfaceEnabled, isTrue);

    // And the switch works from the moment it appears.
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
    // The one step that rebuilds a table rather than adding to it: REQ-021's
    // plants have no session and so no duration, and SQLite cannot drop a NOT
    // NULL any other way. A copy-and-swap that dropped a row would take a
    // user's garden with it, so what this asserts is that every plant came
    // across whole — plot, species and duration included.
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
        // The plots version 6 wrote, not the plots today's placement rule
        // would choose: a rebuilt table is not a re-laid-out garden, and a
        // user opening this build finds their plants where they left them.
        'oldest': const GardenPlot(0, 0),
        'middle': const GardenPlot(1, 0),
        'newest': const GardenPlot(0, 1),
      },
    );

    // None of them was ever an award, which is the truth about a plant written
    // before this version existed.
    expect(plants.values.every((plant) => plant.milestone == null), isTrue);
    expect(await garden.awardedMilestones(), isEmpty);

    // And the new column works from the moment it appears, unique index and
    // all — which is what makes a second award of the same milestone a write
    // the database refuses rather than a duplicate plant.
    await garden.save(Plant.forMilestone(
      Milestone.ten,
      id: 'awarded',
      plantedAt: DateTime.utc(2026, 8, 11),
      plot: GardenPlots.nextFree(await garden.occupiedPlots()),
    ));
    expect(await garden.awardedMilestones(), {Milestone.ten});
  });

  testWidgets('upgrading from version 11 indexes the journal without touching '
      'a row', (tester) async {
    // Ticket 15's step is the only one so far that adds no column and changes
    // no shape — it exists to make the journal's aggregates cheap on a history
    // that has been accumulating since version 1. What it must not do is
    // disturb any of that history.
    createVersion11Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    final journal = DriftJournalRepository(database);
    // The two sessions version 1 wrote, one completed and one abandoned, plus
    // ticket 05's voided one — counted the way the journal counts them.
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

  testWidgets('upgrading from version 12 does not send an existing user '
      'through onboarding', (tester) async {
    // The only thing ticket 16's step has to get right. A settings row on disk
    // is a user who has been running sessions; the flag is added for the sake
    // of people installing the app tomorrow, and it must not greet the people
    // who installed it last month.
    createVersion12Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    final settings = await DriftSettingsRepository(database).load();

    expect(settings.onboardingCompleted, isTrue);
    // And nothing else about their settings moved. The row this file carries
    // has a 50-minute session and a 10-minute break in it, chosen at version 2.
    expect(settings.sessionLength, const Duration(minutes: 50));
    expect(settings.breakLength, const Duration(minutes: 10));
    expect(await DriftPlantRepository(database).plants(), hasLength(4));
  });

  testWidgets('upgrading from version 13 opens an empty event log beside the '
      'history it cannot account for', (tester) async {
    // Ticket 17's step adds a table and backfills nothing, which is the only
    // honest answer: §7.1's events are things that happened, and an upgrading
    // user's sessions are not a record of when they opened the app. What the
    // step must not do is disturb the garden they arrived with.
    createVersion13Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final log = DriftAnalyticsEventLog(database);

    expect(await log.recent(), isEmpty);
    expect(await DriftPlantRepository(database).plants(), hasLength(4));
    expect((await DriftSettingsRepository(database).load()).sessionLength,
        const Duration(minutes: 50));

    // And the table works from the moment it appears.
    await log.append(
      SessionStarted.of(const Duration(minutes: 25)),
      at: DateTime.utc(2026, 8, 20),
    );
    expect((await log.recent()).single.known, AnalyticsEventName.sessionStarted);
  });

  testWidgets('upgrading from version 14 keeps the garden, through a table '
      'that is created and later dropped', (tester) async {
    // Version 15 creates `entitlements` and version 18 drops it again, so a
    // file this old walks through both. What the round trip must not do is
    // disturb the sessions and the garden it arrived with.
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
    // Ticket 19's step is one column and its default, and the default is the
    // whole of it: Zen is the garden every upgrading user already had — §5.1's
    // palette *is* Zen's summer, so nothing about the garden they open looks
    // any different.
    createVersion15Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final settings = DriftSettingsRepository(database);

    expect((await settings.load()).gardenTheme, GardenTheme.zen);

    // The rest of their settings, and their garden, come through untouched.
    expect((await settings.load()).sessionLength, const Duration(minutes: 50));
    expect(await DriftPlantRepository(database).plants(), hasLength(4));

    // And the column works from the moment it appears.
    await settings.save(
      (await settings.load()).withGardenTheme(GardenTheme.wildflower),
    );
    expect((await settings.load()).gardenTheme, GardenTheme.wildflower);
  });

  testWidgets('upgrading from version 16 arrives with an empty garden to '
      'arrange', (tester) async {
    // Ticket 20's step adds a table and backfills nothing, and nothing could
    // be: there was no decor to place before this version. What it must not do
    // is disturb the settings and the garden the user arrived with.
    createVersion16Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final arrangement = DriftDecorRepository(database);

    expect(await arrangement.decor(), isEmpty);
    expect(await DriftPlantRepository(database).plants(), hasLength(4));
    expect((await DriftSettingsRepository(database).load()).sessionLength,
        const Duration(minutes: 50));

    // And the table works from the moment it appears.
    await arrangement.save(Decor(
      id: 'lantern-1',
      kind: DecorKind.lantern,
      plot: const GardenPlot(2, -1),
      placedAt: DateTime.utc(2026, 8, 26),
    ));
    expect((await arrangement.decor()).single.kind, DecorKind.lantern);
  });

  testWidgets('upgrading from version 17 drops the entitlement and keeps the '
      'garden', (tester) async {
    // The step that took the paywall out. A user who had paid walks through it:
    // the table they were recorded in goes, and everything they actually own —
    // their plants, their sessions, their arrangement, their settings — comes
    // through untouched, because those are other tables and this step writes to
    // none of them. See `docs/adr/0021-…`.
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

  testWidgets('and everything the paywall used to gate is open afterwards',
      (tester) async {
    // The other half of it, said as the thing the user would notice: the
    // premium theme they could not have applied is now one they can store and
    // read back.
    createVersion17Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final settings = DriftSettingsRepository(database);

    await settings.save(
      (await settings.load()).withGardenTheme(GardenTheme.tropical),
    );
    expect((await settings.load()).gardenTheme, GardenTheme.tropical);
  });

  testWidgets('upgrading from version 18 keeps the sound the user has been '
      'hearing', (tester) async {
    // Ticket 25's step is one column and its default, and the default is the
    // whole of it: the wind chime is what every upgrading user has heard at the
    // end of every session since ticket 06, so the first thing this ticket does
    // for them is nothing at all. A default of `none` would have turned off a
    // sound nobody asked to lose.
    createVersion18Database();

    final database = AppDatabase.inFile(file);
    addTearDown(database.close);
    final settings = DriftSettingsRepository(database);

    expect((await settings.load()).endSound, EndSound.windChime);

    // And the bed beside it is still the one they chose — the two sound
    // columns are not crossed.
    expect((await settings.load()).ambientSound, AmbientSound.rain);

    // The rest of their settings, and their garden, come through untouched.
    expect((await settings.load()).sessionLength, const Duration(minutes: 50));
    expect(await DriftPlantRepository(database).plants(), hasLength(4));
    expect((await DriftDecorRepository(database).decor()).single.kind,
        DecorKind.bench);

    // And the column works from the moment it appears, including the choice
    // that is the absence of a sound rather than a switch beside them.
    await settings.save((await settings.load()).withEndSound(EndSound.none));
    expect((await settings.load()).endSound, EndSound.none);
  });

  testWidgets('a fresh database is created at the current version, no upgrade '
      'step run', (tester) async {
    final database = AppDatabase.inFile(file);
    addTearDown(database.close);

    expect(database.schemaVersion, 19);
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
      ]),
    );
    // Never created, rather than created and dropped: `onCreate` builds the
    // schema as it is today, and today's has no such table.
    expect(tables, isNot(contains('entitlements')));
  });
}

/// Every table in [database], by name.
Future<List<String>> _tableNames(AppDatabase database) async {
  final rows = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return [for (final row in rows) row.read<String>('name')];
}
