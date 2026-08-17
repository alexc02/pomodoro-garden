import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

part 'database.g.dart';

/// Every focus session the user has started.
///
/// Rows are written when a session starts, so unfinished sessions are in here
/// too (ADR 0002). Anything counting sessions filters on [completed].
///
/// The index covers the journal's queries, which all filter on [completed]
/// and then range over or group by [startedAt].
@DataClassName('SessionRow')
@TableIndex(
  name: 'sessions_completed_started_at',
  columns: {#completed, #startedAt},
)
class Sessions extends Table {
  @override
  String get tableName => 'sessions';

  TextColumn get id => text()();

  /// Stored as UTC. Drift keeps `DateTime` as Unix seconds with no zone, so
  /// `drift_session_repository.dart` does the UTC conversion both ways.
  DateTimeColumn get startedAt => dateTime()();

  /// Planned duration, in seconds (ADR 0003).
  IntColumn get durationSeconds => integer()();

  /// Derived from [outcome] and written with it by
  /// `drift_session_repository.dart`, the only writer. Its own column so the
  /// index can use it.
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// [SessionOutcome.name], or null while the session runs.
  ///
  /// Enums are stored by name throughout, so reordering one doesn't corrupt
  /// existing rows.
  TextColumn get outcome => text().nullable()();

  /// Total time spent in finished pauses.
  IntColumn get pausedSeconds => integer().withDefault(const Constant(0))();

  /// Start of the current pause, or null if not paused. Lets a cold start
  /// restore a paused session as paused.
  DateTimeColumn get pausedSince => dateTime().nullable()();

  /// Null while the session runs.
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Every plant in the garden.
///
/// One per completed session, plus milestone plants (which have no
/// [sessionId]). Type, species and stage are stored rather than re-derived so
/// a change to the growth rules doesn't rewrite an existing garden.
@DataClassName('PlantRow')
@TableIndex(name: 'plants_planted_at', columns: {#plantedAt})
class Plants extends Table {
  @override
  String get tableName => 'plants';

  TextColumn get id => text()();

  /// Null for milestone plants.
  ///
  /// Not a foreign key: the only thing that deletes sessions is the reset,
  /// which deletes every plant in the same transaction (`DriftGardenReset`).
  TextColumn get sessionId => text().nullable()();

  /// [PlantType.name].
  TextColumn get type => text()();

  /// [PlantSpecies.name].
  TextColumn get species => text()();

  /// [GrowthStage.index], 0 to 4.
  IntColumn get growthStage => integer()();

  /// The session's start time, in UTC.
  DateTimeColumn get plantedAt => dateTime()();

  /// In seconds. Null for milestone plants, since no session grew them (zero
  /// would show up on the card as a zero-minute session).
  IntColumn get sessionDurationSeconds => integer().nullable()();

  /// [Milestone.sessions] for a milestone plant, null otherwise. Stored as
  /// the count, not the enum name, so renaming a member is free. A plant is a
  /// bonus plant exactly when this is set; there's deliberately no separate
  /// flag.
  IntColumn get milestoneSessions => integer().nullable()();

  /// Grid position, picked once at planting so the garden looks the same on
  /// every launch. Both null when the garden is full.
  IntColumn get plotX => integer().nullable()();
  IntColumn get plotY => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// One plant per session and one per milestone.
  ///
  /// A completion can be noticed twice (ticker and next-session tap), each
  /// with a fresh plant id, so the primary key alone won't catch it. Two
  /// racing milestone awards would also both see "not awarded yet". SQLite
  /// allows multiple NULLs in a unique index, so both keys work.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {sessionId},
        {milestoneSessions},
      ];
}

/// The user's settings. Always at most one row, enforced by a check.
///
/// No row until the first setting changes; until then the app runs on
/// `GardenSettings.defaults`. Column defaults are what a row written before
/// that column existed reads as, so they're picked for upgrading users.
@DataClassName('SettingsRow')
class Settings extends Table {
  @override
  String get tableName => 'settings';

  /// Always 1. The literal is repeated here and in the constraint instead of
  /// using [AppDatabase.settingsRowId] because drift's generator only
  /// resolves literals.
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// In seconds (ADR 0003).
  IntColumn get sessionLengthSeconds => integer()();

  /// In seconds.
  IntColumn get breakLengthSeconds => integer()();

  /// Focus sessions before the break becomes a long one.
  IntColumn get longBreakAfterSessions => integer()();

  /// Defaults on: existing users had haptics before the switch existed.
  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Whether a running session is shown outside the app. Defaults on, same
  /// reason as [hapticsEnabled].
  BoolColumn get liveSurfaceEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Defaults off: don't start timers for an upgrading user who never asked.
  BoolColumn get autoStartBreak =>
      boolean().withDefault(const Constant(false))();

  /// Defaults off, same as [autoStartBreak].
  BoolColumn get autoStartNextSession =>
      boolean().withDefault(const Constant(false))();

  /// [AmbientSound.name]. Defaults to silence so an upgrade never starts
  /// playing something.
  TextColumn get ambientSound =>
      text().withDefault(const Constant('silence'))();

  /// [EndSound.name]. Defaults to the chime because that's what users heard
  /// before this was configurable.
  TextColumn get endSound =>
      text().withDefault(const Constant('windChime'))();

  /// [GardenTheme.name]. Unknown names also fall back to `zen`.
  TextColumn get gardenTheme => text().withDefault(const Constant('zen'))();

  /// Whether to ask the phone to go quiet during a session. Defaults off:
  /// it decides which calls get through.
  BoolColumn get quietModeEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Whether the one-time "silence your phone yourself" hint was dismissed.
  /// Not really a setting, but not worth its own table.
  BoolColumn get quietModeHintDismissed =>
      boolean().withDefault(const Constant(false))();

  /// Defaults false, but the migration that adds it sets it to true on
  /// existing rows: a row on disk means the user has already used the app.
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const ['CHECK (id = 1)'];
}

/// Analytics events, kept on the device only. No SDK, no network.
///
/// Autoincrement id because events have no identity of their own; insertion
/// order is what distinguishes them, and lets [DriftAnalyticsEventLog] trim
/// by id. Parameters are a JSON blob since every event has a different shape;
/// the typing lives in the sealed `AnalyticsEvent`.
///
/// SQLite includes the rowid in every index, so the name index is already
/// ordered by id for "last event with this name" lookups.
@DataClassName('AnalyticsEventRow')
@TableIndex(name: 'analytics_events_name', columns: {#name})
class AnalyticsEvents extends Table {
  @override
  String get tableName => 'analytics_events';

  /// Insertion order. Used for "recent" instead of [recordedAt] so a clock
  /// moved backwards doesn't shuffle the log.
  IntColumn get id => integer().autoIncrement()();

  /// [AnalyticsEventName.recorded].
  TextColumn get name => text()();

  /// JSON object.
  TextColumn get parameters => text()();

  /// UTC.
  DateTimeColumn get recordedAt => dateTime()();
}

/// Decor items placed in empty plots.
///
/// Separate from [Plants] so nothing that counts plants has to filter decor
/// out.
@DataClassName('DecorRow')
class GardenDecor extends Table {
  @override
  String get tableName => 'decor';

  TextColumn get id => text()();

  /// [DecorKind.name].
  TextColumn get kind => text()();

  /// Unlike [Plants.plotX], never null: an item without a plot is meaningless
  ///.
  IntColumn get plotX => integer()();
  IntColumn get plotY => integer()();

  /// UTC. Also the read-back order, so reads are stable.
  DateTimeColumn get placedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// One item per plot. The picker only offers empty plots, but two racing
  /// taps could both see the same one as empty.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {plotX, plotY},
      ];
}

/// The app's single SQLite database.
@DriftDatabase(
  tables: [
    Sessions,
    Settings,
    Plants,
    AnalyticsEvents,
    GardenDecor,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens (or creates) the file in the app's documents directory.
  AppDatabase() : super(_openOnDevice());

  /// In-memory, for tests.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  /// File-backed, for tests that simulate the app being killed and relaunched.
  AppDatabase.inFile(File file) : super(NativeDatabase(file));

  /// See [Settings.id].
  static const int settingsRowId = 1;

  /// Single-row table holding `SessionSnapshot.cyclePosition`, so a relaunch
  /// doesn't restart the Pomodoro cycle. Read and written in
  /// `drift_cycle_store.dart`.
  static const String createCycle = '''
    CREATE TABLE cycle (
      id INTEGER NOT NULL DEFAULT 1,
      position INTEGER NOT NULL,
      PRIMARY KEY (id),
      CHECK (id = 1)
    )
  ''';

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(createCycle);
        },
        // Steps run one version at a time. Tables are created with raw SQL,
        // not `Migrator.createTable`, because createTable uses today's
        // definition and later addColumn steps would then hit duplicates.
        // Each step must leave exactly the shape of its own version, so old
        // steps are never edited or removed (even 14 -> 15, whose table is
        // dropped again at 18).
        onUpgrade: (m, from, to) async {
          for (var version = from; version < to; version++) {
            switch (version) {
              case 1:
                await customStatement('''
                  CREATE TABLE settings (
                    id INTEGER NOT NULL DEFAULT 1,
                    session_length_seconds INTEGER NOT NULL,
                    break_length_seconds INTEGER NOT NULL,
                    long_break_after_sessions INTEGER NOT NULL,
                    PRIMARY KEY (id),
                    CHECK (id = 1)
                  )
                ''');
              // No backfill from old sessions: their species were never
              // chosen.
              case 2:
                await customStatement('''
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
                  )
                ''');
              // Unfinished rows get closed as voided. Otherwise the first
              // launch would restore a weeks-old session, see it had run out,
              // and award a plant. endedAt stays null since it was never known.
              case 3:
                await m.addColumn(sessions, sessions.outcome);
                await m.addColumn(sessions, sessions.pausedSince);
                await customStatement(
                  "UPDATE sessions SET outcome = 'completed' WHERE completed = 1",
                );
                await customStatement(
                  "UPDATE sessions SET outcome = 'voided' WHERE completed = 0",
                );
              case 4:
                await m.addColumn(settings, settings.hapticsEnabled);
              // Existing plants get plots in planting order, the same layout
              // they'd have had if plots had been assigned all along.
              case 5:
                await m.addColumn(plants, plants.plotX);
                await m.addColumn(plants, plants.plotY);
                await _fillPlots();
              case 6:
                await m.addColumn(settings, settings.liveSurfaceEnabled);
              case 7:
                await m.addColumn(settings, settings.autoStartBreak);
                await m.addColumn(settings, settings.autoStartNextSession);
              case 8:
                await m.addColumn(settings, settings.ambientSound);
              case 9:
                await m.addColumn(settings, settings.quietModeEnabled);
                await m.addColumn(settings, settings.quietModeHintDismissed);
              // Full rebuild: SQLite can't drop NOT NULL with ALTER TABLE.
              case 10:
                await _rebuildPlantsAtVersion11();
              case 11:
                await customStatement(
                  'CREATE INDEX IF NOT EXISTS sessions_completed_started_at '
                  'ON sessions (completed, started_at)',
                );
                await customStatement(
                  'CREATE INDEX IF NOT EXISTS plants_planted_at '
                  'ON plants (planted_at)',
                );
              // Existing rows belong to people who've used the app; don't
              // show them onboarding.
              case 12:
                await m.addColumn(settings, settings.onboardingCompleted);
                await customStatement(
                  'UPDATE settings SET onboarding_completed = 1',
                );
              case 13:
                await customStatement('''
                  CREATE TABLE analytics_events (
                    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    parameters TEXT NOT NULL,
                    recorded_at INTEGER NOT NULL
                  )
                ''');
                await customStatement(
                  'CREATE INDEX IF NOT EXISTS analytics_events_name '
                  'ON analytics_events (name)',
                );
              // Paywall table, dropped again at 18 (ADR 0005). Must stay.
              case 14:
                await customStatement('''
                  CREATE TABLE entitlements (
                    product_id TEXT NOT NULL,
                    granted_at INTEGER NOT NULL,
                    PRIMARY KEY (product_id)
                  )
                ''');
              case 15:
                await m.addColumn(settings, settings.gardenTheme);
              case 16:
                await customStatement('''
                  CREATE TABLE decor (
                    id TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    plot_x INTEGER NOT NULL,
                    plot_y INTEGER NOT NULL,
                    placed_at INTEGER NOT NULL,
                    PRIMARY KEY (id),
                    UNIQUE (plot_x, plot_y)
                  )
                ''');
              case 17:
                await customStatement('DROP TABLE IF EXISTS entitlements');
              case 18:
                await m.addColumn(settings, settings.endSound);
              // Missing row reads as the start of the cycle.
              case 19:
                await customStatement(createCycle);
              default:
                throw UnsupportedError(
                  'No migration from schema $version to ${version + 1}. Add '
                  'one alongside the schemaVersion bump that introduced '
                  '${version + 1}.',
                );
            }
          }
        },
        beforeOpen: (details) async {
          // Per-connection in SQLite, so it has to be set on every open.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Copy-and-swap rebuild of `plants` into its version 11 shape. Columns are
  /// listed explicitly rather than `SELECT *` so the copy can't shift.
  Future<void> _rebuildPlantsAtVersion11() async {
    await customStatement('''
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
      )
    ''');
    await customStatement('''
      INSERT INTO plants_v11
        (id, session_id, type, species, growth_stage, planted_at,
         session_duration_seconds, milestone_sessions, plot_x, plot_y)
      SELECT
        id, session_id, type, species, growth_stage, planted_at,
        session_duration_seconds, NULL, plot_x, plot_y
      FROM plants
    ''');
    await customStatement('DROP TABLE plants');
    await customStatement('ALTER TABLE plants_v11 RENAME TO plants');
  }

  /// Assigns plots to existing plants, oldest first. Done in Dart so the
  /// placement order comes from [GardenPlots] instead of a copy in SQL.
  /// Anything past [GardenPlots.maximum] gets no plot, same as a full garden.
  Future<void> _fillPlots() async {
    final rows = await customSelect(
      'SELECT id FROM plants ORDER BY planted_at ASC, id ASC',
    ).get();

    final placements = rows.length < GardenPlots.maximum
        ? rows.length
        : GardenPlots.maximum;
    for (var index = 0; index < placements; index++) {
      final plot = GardenPlots.inPlacementOrder[index];
      await customStatement(
        'UPDATE plants SET plot_x = ?, plot_y = ? WHERE id = ?',
        [plot.x, plot.y, rows[index].read<String>('id')],
      );
    }
  }
}

QueryExecutor _openOnDevice() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'pip_garden.sqlite'));
    // Background isolate so big queries can't drop UI frames.
    return NativeDatabase.createInBackground(file);
  });
}
