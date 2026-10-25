import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

part 'database.g.dart';

/// Every focus session the user has started.
///
/// Rows appear when a session starts, not when it finishes, so this table
/// contains sessions that were never completed — see
/// `docs/adr/0002-sessions-are-recorded-when-they-start.md`. Anything counting
/// sessions filters on [completed].
///
/// The index is ticket 15's, and it is what keeps the journal's aggregates
/// cheap: every one of them filters on [completed] and then either sums a range
/// of [startedAt] or groups the whole of it, so an index in that order turns a
/// week's totals into a seek over a handful of rows and the streak's distinct
/// days into a scan of the index rather than of the table. A user with four
/// years of history has thousands of rows here and the journal opens in one
/// frame either way; the index is what keeps that true at ten.
@DataClassName('SessionRow')
@TableIndex(
  name: 'sessions_completed_started_at',
  columns: {#completed, #startedAt},
)
class Sessions extends Table {
  @override
  String get tableName => 'sessions';

  TextColumn get id => text()();

  /// The anchor, stored as UTC. Drift keeps `DateTime` columns as Unix seconds,
  /// which carry no zone; the mapping in `drift_session_repository.dart` is
  /// what guarantees a UTC instant goes in and a UTC instant comes out.
  DateTimeColumn get startedAt => dateTime()();

  /// The planned duration, in seconds.
  ///
  /// PRD §4.3 names this column `durationMinutes`. Seconds instead — see
  /// `docs/adr/0003-durations-are-stored-in-seconds.md`.
  IntColumn get durationSeconds => integer()();

  /// Whether the session reached its planned duration.
  ///
  /// Derived from [outcome] and written alongside it by
  /// `drift_session_repository.dart`, which is the only writer of either — so
  /// the two cannot disagree. Kept as a column of its own because every count
  /// in the app filters on it (ADR 0002), and a boolean is what an index on
  /// that filter wants.
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// [SessionOutcome.name] — how the session ended, or null while it runs.
  ///
  /// Text rather than an ordinal, for the same reason [Plants.type] is: the
  /// rows stay readable, and stay correct if the enum is ever reordered.
  TextColumn get outcome => text().nullable()();

  /// How much of the session was spent paused, over every pause that finished.
  IntColumn get pausedSeconds => integer().withDefault(const Constant(0))();

  /// When the pause currently open began, or null if the session is not paused.
  ///
  /// Stored so that a session restored on a cold start comes back held if that
  /// is how the user left it. A session the user did *not* hold goes on
  /// counting down while the app is away, which is the whole of REQ-013's
  /// promise about backgrounding.
  DateTimeColumn get pausedSince => dateTime().nullable()();

  /// When the session stopped running. Null while it runs.
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Every plant in the garden.
///
/// One row per completed session — a session that was cancelled or voided grows
/// nothing, so this table is not a mirror of [Sessions]. Ticket 13's milestone
/// plants arrive here too, with no [sessionId], which is why that column is
/// nullable.
///
/// What a plant *is* — its type, its species, the stage it reached — is written
/// down rather than re-derived from the session that grew it. The growth rules
/// may change; a garden the user has been keeping for a year may not.
///
/// The index is ticket 15's, and it is the weekly card's: the journal asks for
/// the plants planted between two instants and draws them, which is a range of
/// [plantedAt] over a table that grows a row a session for as long as the user
/// keeps the app.
@DataClassName('PlantRow')
@TableIndex(name: 'plants_planted_at', columns: {#plantedAt})
class Plants extends Table {
  @override
  String get tableName => 'plants';

  TextColumn get id => text()();

  /// The session this plant grew from. Null for a plant no session earned.
  ///
  /// Not a foreign key, and ticket 22 is what settled that it does not need to
  /// be. The only thing in the app that deletes a session is REQ-036's reset,
  /// and it deletes every plant in the same transaction — see
  /// `DriftGardenReset`. A cascade would be a rule for a case that cannot
  /// arise: there is no way in this app to delete one session and leave its
  /// plant standing, and adding a constraint to forbid it would be adding a
  /// migration to say something already true.
  TextColumn get sessionId => text().nullable()();

  /// [PlantType.name]. Text rather than an ordinal so the rows stay readable
  /// and stay correct if the enum is ever reordered.
  TextColumn get type => text()();

  /// [PlantSpecies.name].
  TextColumn get species => text()();

  /// [GrowthStage.index], 0 to 4, as PRD §4.3 specifies.
  IntColumn get growthStage => integer()();

  /// When the seed went into the soil: the session's anchor, in UTC.
  DateTimeColumn get plantedAt => dateTime()();

  /// The planned duration of the session that grew this, in seconds. §4.3 names
  /// this `sessionDurationMinutes`; seconds instead, per ADR 0003.
  ///
  /// Nullable from version 11, for REQ-021's bonus plants: no session grew one,
  /// so it has no duration. Zero would have avoided a migration and would have
  /// been a lie — "a session of no length" is a different claim from "no
  /// session", and it is the one a card would read out.
  IntColumn get sessionDurationSeconds => integer().nullable()();

  /// [Milestone.sessions] — which milestone awarded this plant, or null if a
  /// session grew it: §4.3's `milestoneSessions`.
  ///
  /// The count rather than the enum's name, because the count *is* the
  /// milestone's identity — renaming a member then costs nothing and changing
  /// one of REQ-021's numbers is a migration, which is the right way round.
  ///
  /// §4.3 also carries an `isBonusPlant` boolean beside this. It is not here:
  /// a plant is a bonus plant exactly when this column is set, and a second
  /// column that could disagree with the first is a bug waiting for the write
  /// that sets only one of them.
  IntColumn get milestoneSessions => integer().nullable()();

  /// Where in the isometric grid this plant stands — §4.3's `plotX`/`plotY`.
  ///
  /// Written down rather than recomputed on the way out, which is what makes
  /// the garden look the same on every launch: the plot is chosen once, against
  /// the garden as it stood at that moment, and never chosen again.
  ///
  /// Nullable, and the two columns are null together: a plant the garden has no
  /// plot for. Only reachable past two hundred plants — see
  /// `docs/adr/0006-the-garden-has-a-plot-for-every-plant-it-can-hold.md`.
  IntColumn get plotX => integer().nullable()();
  IntColumn get plotY => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// One plant per session and one per milestone, enforced by the database
  /// rather than by the caller remembering to look first.
  ///
  /// A completion can be noticed more than once — by the ticker and by the tap
  /// that starts the next session — and each notice mints a fresh plant id, so
  /// the upsert on the primary key would not catch a double planting. SQLite
  /// allows any number of NULLs in a unique index, which is what lets one index
  /// cover the plants a session grew and the other cover the awards.
  ///
  /// The second index is REQ-021's "exactly once, and idempotent" as a
  /// constraint rather than as a convention. `MilestoneAwards` asks which
  /// milestones are already in the ground before awarding any — but two awards
  /// racing each other would both read the same empty answer, and only the
  /// database is in a position to refuse the second write.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {sessionId},
        {milestoneSessions},
      ];
}

/// The user's settings: one row, always.
///
/// PRD §4.3 describes this table as "single row", and that is enforced here by
/// a check constraint rather than by convention — a second row would leave the
/// app choosing between two sets of settings, and nothing sensible to choose
/// on. The row is written the first time a setting changes; until then there is
/// no row and `GardenSettings.defaults` is what the app runs on.
///
/// Later tickets add their own columns here — sounds, auto-start, haptics,
/// theme — rather than a settings table of their own. Each addition is a
/// schema-version bump with a migration step, and a field on `GardenSettings`.
@DataClassName('SettingsRow')
class Settings extends Table {
  @override
  String get tableName => 'settings';

  /// Pinned to 1 by [customConstraints]. Present at all because SQLite wants a
  /// key, not because there is ever a second row to tell apart.
  ///
  /// The 1 is written out here and in the constraint rather than read from
  /// [AppDatabase.settingsRowId], because both are read at build time by
  /// drift's generator, which resolves literals and not references.
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// The planned duration of the next session, in seconds. PRD §4.3 names this
  /// `sessionLengthMinutes`; seconds instead, for the reasons in
  /// `docs/adr/0003-durations-are-stored-in-seconds.md`.
  IntColumn get sessionLengthSeconds => integer()();

  /// How long a break runs, in seconds. Same departure from §4.3's
  /// `breakLengthMinutes`, same reason.
  IntColumn get breakLengthSeconds => integer()();

  /// How many focus sessions run before the break becomes a long one.
  IntColumn get longBreakAfterSessions => integer()();

  /// REQ-037: whether a completing session and a growing plant are allowed to
  /// buzz. Defaulted rather than nullable, so a row written before ticket 06
  /// reads as on — which is what a user who never turned it off means.
  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// REQ-033: whether a running session is shown outside the app. Defaulted to
  /// on for the same reason [hapticsEnabled] is — a row written before ticket
  /// 08 belongs to a user who never had the switch to turn off.
  BoolColumn get liveSurfaceEnabled =>
      boolean().withDefault(const Constant(true))();

  /// REQ-032: whether a break begins on its own when a session finishes.
  ///
  /// Defaulted to *off*, unlike the two switches above it, and that is the
  /// requirement rather than an oversight: a user upgrading into ticket 09 has
  /// never asked the app to start anything for them, and the first thing they
  /// should not meet is a timer that began counting without being asked.
  BoolColumn get autoStartBreak =>
      boolean().withDefault(const Constant(false))();

  /// REQ-032: whether a focus session begins on its own when a break ends. Off
  /// by default, for the reason [autoStartBreak] is.
  BoolColumn get autoStartNextSession =>
      boolean().withDefault(const Constant(false))();

  /// REQ-012: [AmbientSound.name] — which bed plays under a focus session.
  ///
  /// Text rather than an ordinal, for the reason [Plants.type] is: the rows
  /// stay readable, and stay correct if the enum is ever reordered. Defaulted
  /// to silence, which is both the setting a row written before this ticket
  /// means and the one a fresh install starts on — an app that began making
  /// rain because a user upgraded would have decided something about the room
  /// they are sitting in.
  TextColumn get ambientSound =>
      text().withDefault(const Constant('silence'))();

  /// REQ-031: [EndSound.name] — which sound a finished session makes.
  ///
  /// Text rather than an ordinal, for the reason [ambientSound] is. Defaulted
  /// to the wind chime rather than to `none`, which is the opposite of the bed
  /// above it and right for the opposite reason: a user upgrading into this
  /// ticket has been hearing the chime since ticket 06, and a default of
  /// silence would take away a sound they never asked to lose.
  TextColumn get endSound =>
      text().withDefault(const Constant('windChime'))();

  /// REQ-034: [GardenTheme.name] — which biome the garden is dressed in.
  ///
  /// Text rather than an ordinal, for the reason [ambientSound] is: the rows
  /// stay readable and stay correct if the enum is ever reordered. Defaulted to
  /// `zen` — so a row written before this ticket, and a row naming a theme this
  /// build does not have, both read as the garden every install starts in.
  TextColumn get gardenTheme => text().withDefault(const Constant('zen'))();

  /// REQ-014: whether the phone is asked to go quiet for the length of a
  /// session.
  ///
  /// Defaulted to *off*, like the two auto-start switches and for a sharper
  /// version of their reason: this one decides which of the user's calls get
  /// through, and nobody upgrading into this ticket has asked for that.
  BoolColumn get quietModeEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Whether the one-time hint about silencing a phone the app cannot silence
  /// itself has been put away.
  ///
  /// Not a preference, and stored here anyway: this is the app's single-row
  /// store, and a second table for one boolean would be a table to migrate for
  /// the rest of the app's life. PRD §4.3 keeps `onboardingCompleted` here for
  /// the same reason.
  BoolColumn get quietModeHintDismissed =>
      boolean().withDefault(const Constant(false))();

  /// REQ-003: whether the user has been through onboarding.
  ///
  /// Defaulted to *false*, which reads oddly beside the columns above it and is
  /// right for the same reason they are: a fresh install has no row at all, so
  /// what this default describes is only the value a row written before this
  /// column existed would take. The migration step that adds it does not leave
  /// it at that default — see the 12 → 13 case in [AppDatabase.migration] —
  /// because a row on disk means a user who has been using the app, and showing
  /// them a welcome screen on upgrade would be the app forgetting them.
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const ['CHECK (id = 1)'];
}

/// PRD §7.1's events, on the device and nowhere else.
///
/// §7.2's privacy stance said as a table: there is no SDK, no network call and
/// no account behind analytics in this app, so the events are simply rows here —
/// a name, when it happened, and the parameters §7.1 gives that event. See
/// `packages/pomodoro_domain/lib/src/analytics/` for the port they arrive
/// through and `drift_analytics_event_log.dart` for the writing.
///
/// **The only autoincrementing key in the schema, and it is load-bearing.**
/// Everything else here is keyed by a domain id, because a session and a plant
/// are things the app knows the identity of. An event is not: two `app_opened`s
/// a fortnight apart are the same event twice, and what tells them apart is the
/// order they were written in. That order is also what makes the log cheap to
/// bound — see [DriftAnalyticsEventLog], which drops everything below a row id
/// rather than sorting a table to find out what is old.
///
/// The parameters are one JSON object rather than a column each, and that is
/// the one place this schema is deliberately loose: thirteen events have
/// thirteen different parameter lists, and a table with a union of their columns
/// would be mostly nulls and a migration every time a ticket adds an event. The
/// typing that matters is at the call site, where `AnalyticsEvent` is sealed.
/// The index is the app-open check's: "when was an event of this name last
/// recorded" is one seek into it, and SQLite carries the row id along in every
/// index, so an index on the name alone is already ordered by the id underneath
/// it — which is the order the answer is wanted in.
@DataClassName('AnalyticsEventRow')
@TableIndex(name: 'analytics_events_name', columns: {#name})
class AnalyticsEvents extends Table {
  @override
  String get tableName => 'analytics_events';

  /// Insertion order, and the log's idea of "recent".
  ///
  /// Not the timestamp: a device clock corrected backwards would otherwise
  /// shuffle the log, and the row that was written last is the row that
  /// happened last whatever the clock says about it.
  IntColumn get id => integer().autoIncrement()();

  /// [AnalyticsEventName.recorded] — §7.1's name for this event.
  ///
  /// Text rather than an ordinal, for the reason [Plants.type] is: the rows stay
  /// readable, and stay correct if the enum is ever reordered.
  TextColumn get name => text()();

  /// The event's parameters, as a JSON object.
  TextColumn get parameters => text()();

  /// When it happened, stored as UTC like every other instant in the schema.
  DateTimeColumn get recordedAt => dateTime()();
}

/// REQ-040's arrangement: what the user has stood in the empty plots.
///
/// **A table beside [Plants] rather than rows in it.** A plant is written once
/// and never moves; an item exists to be moved and removed. Folding them
/// together would mean every query that counts the garden filtering out the
/// furniture, and the first one that forgot would tell the user they had grown
/// a bench.
@DataClassName('DecorRow')
class GardenDecor extends Table {
  @override
  String get tableName => 'decor';

  TextColumn get id => text()();

  /// [DecorKind.name]. Text rather than an ordinal, for the reason
  /// [Plants.type] is: the rows stay readable, and stay correct if the enum is
  /// ever reordered — and ticket 23 may well add to it.
  TextColumn get kind => text()();

  /// Where in the isometric grid this item stands.
  ///
  /// **Not nullable, unlike [Plants.plotX].** A plant with no plot is a plant
  /// the garden is holding for the user (ADR 0006); an item with no plot is
  /// nothing at all. See `docs/adr/0017-…`.
  IntColumn get plotX => integer()();
  IntColumn get plotY => integer()();

  /// When the user put it down, in UTC. The order an arrangement is read back
  /// in, so that two reads of one garden hand back one arrangement.
  DateTimeColumn get placedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// One thing to a plot, enforced by the database rather than by the caller
  /// remembering to look first.
  ///
  /// The placement rules do look first — a picker only offers empty plots — but
  /// two taps racing each other would both read the same empty plot, and only
  /// the database is in a position to refuse the second write. The same
  /// reasoning [Plants.uniqueKeys] is written down with.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {plotX, plotY},
      ];
}

/// The app's SQLite database.
///
/// One database for the whole app; later tickets add their tables here rather
/// than opening databases of their own.
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
  /// Opens the database file in the app's documents directory, creating it on
  /// first launch.
  AppDatabase() : super(_openOnDevice());

  /// An empty in-memory database, for tests.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  /// A database in [file], for tests that need one to outlive the process that
  /// wrote it — the closest a test on a workstation gets to the app being
  /// killed and launched again.
  AppDatabase.inFile(File file) : super(NativeDatabase(file));

  /// The single settings row's key. See [Settings.id].
  static const int settingsRowId = 1;

  /// Bumped whenever a table changes shape. Version 1 was ticket 02's
  /// `sessions` table; version 2 adds ticket 03's `settings`; version 3 adds
  /// ticket 04's `plants`; version 4 adds ticket 05's `outcome` and
  /// `pausedSince`; version 5 adds ticket 06's `hapticsEnabled`; version 6 adds
  /// ticket 07's `plotX`/`plotY`; version 7 adds ticket 08's
  /// `liveSurfaceEnabled`; version 8 adds ticket 09's two auto-start switches;
  /// version 9 adds ticket 10's `ambientSound`; version 10 adds ticket 11's
  /// `quietModeEnabled` and `quietModeHintDismissed`; version 11 adds ticket
  /// 13's `milestoneSessions` and lets `sessionDurationSeconds` be null;
  /// version 12 adds ticket 15's two indexes and no columns at all; version 13
  /// adds ticket 16's `onboardingCompleted`; version 14 adds ticket 17's
  /// `analytics_events`; version 15 adds ticket 18's `entitlements`; version
  /// 16 adds ticket 19's `gardenTheme`; version 17 adds ticket 20's `decor`;
  /// version 18 **drops** `entitlements` again, with the paywall it belonged
  /// to; version 19 adds ticket 25's `endSound`; version 20 adds the `cycle`
  /// row that keeps the Pomodoro cycle's position across launches.
  /// [migration] says what happens at each step.
  ///
  /// A dropped version is not a reused one: 15 still means what it meant, and 18
  /// is the version in which the table it created is gone. A device that never
  /// ran a build between them walks 14 → 15 → … → 18 and creates the table only
  /// to drop it three steps later, which is the price of steps that each leave
  /// behind the shape of their own version.
  /// Where the user is in the Pomodoro cycle — `SessionSnapshot.cyclePosition`
  /// — so that a relaunch does not start the cycle over. Raw SQL rather than a
  /// table class: one row, one number, read and written in
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
        // The path from empty: a fresh install has no file, and gets every
        // table at the current version without running an upgrade step.
        onCreate: (m) async {
          await m.createAll();
          await customStatement(createCycle);
        },
        // One step at a time, in order. A user who skipped three releases
        // arrives here at an old version and walks all the way up rather than
        // jumping — which is what keeps each step able to assume the shape the
        // step before it left behind.
        //
        // A step that creates a table writes the SQL out rather than calling
        // `Migrator.createTable`, and ticket 06 is why: `createTable` builds
        // the table as it is defined *today*, so the step that first created
        // `settings` was quietly creating a version-5 table and the step that
        // adds version 5's column to it then failed on a duplicate. A step has
        // to leave behind the shape of the version it introduces, or the steps
        // after it are running against a schema that never existed.
        onUpgrade: (m, from, to) async {
          for (var version = from; version < to; version++) {
            switch (version) {
              // 1 → 2: settings gets a table, as version 2 shaped it. Nothing
              // is seeded into it; an upgrading user has no stored settings yet
              // and runs on `GardenSettings.defaults` until they change one,
              // exactly as a fresh install does.
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
              // 2 → 3: the garden gets a table, as version 3 shaped it. Nothing
              // is backfilled into it. An upgrading user's completed sessions
              // are in `sessions`, but the plants they would have grown were
              // never chosen — species included — and inventing a garden they
              // never watched grow is worse than starting their garden here.
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
              // 3 → 4: a session gains how it ended and where it is paused.
              //
              // Both columns are backfilled, and the second half of this step
              // matters more than the first: before this version an unfinished
              // row was simply an unfinished row, and from this version on it
              // is a session the app will find and put back in flight. Left
              // alone, the first launch after upgrading would restore a
              // session abandoned weeks ago, notice its time had run out, and
              // hand the user a plant for work nobody did.
              //
              // So every unfinished row is closed as voided, which is what it
              // always was — the app went away and nobody decided to end it.
              // `endedAt` stays null on those rows: no build of this app ever
              // wrote down when they stopped, and a made-up instant would be
              // worse than an absent one.
              case 3:
                await m.addColumn(sessions, sessions.outcome);
                await m.addColumn(sessions, sessions.pausedSince);
                await customStatement(
                  "UPDATE sessions SET outcome = 'completed' WHERE completed = 1",
                );
                await customStatement(
                  "UPDATE sessions SET outcome = 'voided' WHERE completed = 0",
                );
              // 4 → 5: settings gain REQ-037's haptics switch. The column
              // carries its own default, so every row already there reads as
              // on — the setting a user who has never seen the switch means.
              case 4:
                await m.addColumn(settings, settings.hapticsEnabled);
              // 5 → 6: a plant gains the plot it stands in, and every plant
              // already in the ground is given one.
              //
              // Backfilled rather than left null, and this is the half of the
              // step that matters: an upgrading user's garden is not a fresh
              // one, and a garden of unplaced plants is a garden that does not
              // draw. They are laid out in the order they were planted, oldest
              // nearest the middle, which is the same order the app would have
              // put them in had it been assigning plots all along — so the
              // garden they open after the upgrade is the garden they would
              // have had.
              case 5:
                await m.addColumn(plants, plants.plotX);
                await m.addColumn(plants, plants.plotY);
                await _fillPlots();
              // 6 → 7: settings gain REQ-033's live-surface switch, on the same
              // terms as the haptics one — the column carries its own default,
              // so every row already there reads as on. That is the setting a
              // user who has never seen the switch means, and it is also the
              // default the ticket asks for.
              case 6:
                await m.addColumn(settings, settings.liveSurfaceEnabled);
              // 7 → 8: settings gain REQ-032's two auto-start switches. Their
              // columns default to *off*, which is the opposite of the two
              // steps above and is the point: an upgrading user has never been
              // asked whether the app may start a timer for them, and the
              // answer the app has to assume until they say otherwise is no.
              case 7:
                await m.addColumn(settings, settings.autoStartBreak);
                await m.addColumn(settings, settings.autoStartNextSession);
              // 8 → 9: settings gain REQ-012's ambient bed. Its column defaults
              // to silence, which is the same answer the two auto-start
              // switches give and for the same reason: an upgrading user has
              // never been asked what they want playing, and the only safe
              // assumption about somebody's room is nothing.
              case 8:
                await m.addColumn(settings, settings.ambientSound);
              // 9 → 10: settings gain REQ-014's quiet mode, and the flag that
              // remembers the hint about it having been put away. Both default
              // to off, and the first of the two is the one that matters: a
              // user who upgrades and starts a session must not find that their
              // phone has stopped ringing, because the decision about which
              // calls they miss is not one an upgrade gets to make for them.
              case 9:
                await m.addColumn(settings, settings.quietModeEnabled);
                await m.addColumn(settings, settings.quietModeHintDismissed);
              // 10 → 11: a plant gains the milestone that awarded it, and the
              // session duration beside it becomes optional.
              //
              // The whole table is rebuilt rather than altered, because the
              // second half of that sentence cannot be done any other way:
              // SQLite's `ALTER TABLE` can add a column but cannot drop a NOT
              // NULL, and REQ-021's plants have no session and so no duration.
              // Storing a zero to dodge this rebuild would have put "0 minutes"
              // on the card for an award earned by a thousand of them.
              //
              // Written out as SQL, for the reason every other step here is:
              // `Migrator.createTable` would build the table as it is defined
              // *today*, and a step has to leave behind the shape of the version
              // it introduces.
              case 10:
                await _rebuildPlantsAtVersion11();
              // 11 → 12: ticket 15's two indexes, and nothing else. No column
              // changes shape and no row is touched, so an upgrading user's
              // sessions and garden come through untouched by construction.
              //
              // Written as SQL for the same reason the other steps are — a
              // future index on either table must not be created retroactively
              // by this step — and `IF NOT EXISTS` because a database that has
              // been to version 12 and back is a database this has already run
              // against.
              case 11:
                await customStatement(
                  'CREATE INDEX IF NOT EXISTS sessions_completed_started_at '
                  'ON sessions (completed, started_at)',
                );
                await customStatement(
                  'CREATE INDEX IF NOT EXISTS plants_planted_at '
                  'ON plants (planted_at)',
                );
              // 12 → 13: settings gain REQ-003's onboarding flag, and every row
              // already there is marked as having seen it.
              //
              // The backfill is the whole of this step. The column's own
              // default is false, because false is what a *fresh install*
              // means — but a settings row that exists before this version
              // belongs to somebody who has been running sessions for weeks,
              // and greeting them with "welcome to Pomodoro Garden" and three
              // steps to their first session would be the upgrade telling them
              // they had never been here.
              //
              // Written as an UPDATE rather than as a DEFAULT on the ALTER, so
              // that the column means the same thing wherever it is read from
              // and the reason it was backfilled is a line of code rather than
              // an implication.
              case 12:
                await m.addColumn(settings, settings.onboardingCompleted);
                await customStatement(
                  'UPDATE settings SET onboarding_completed = 1',
                );
              // 13 → 14: the event log gets a table, as version 14 shaped it.
              //
              // Nothing is backfilled and nothing could be: §7.1's events are
              // things that happened, and an upgrading user's sessions are not
              // a record of when they opened the app or how long they looked at
              // their garden. Their log starts here, which is the honest answer
              // and also the only one — see ADR 0014.
              //
              // Written out as SQL for the reason every other step here is: a
              // column a later ticket adds to this table must not appear
              // retroactively in the version this step introduces.
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
              // 14 → 15: ticket 18's premium unlock gets a table, as version
              // 15 shaped it, and it is left empty.
              //
              // **This step still runs, and the table it creates is dropped
              // three versions later.** The app no longer sells anything —
              // version 18 is where `entitlements` goes, see `case 17` — but a
              // step describes the version it introduces and cannot be edited
              // to describe a later one. Deleting this would make every step
              // after it run against a schema that never existed.
              //
              // Written out as SQL for the reason every other step here is: a
              // column a later ticket adds to this table must not appear
              // retroactively in the version this step introduces.
              case 14:
                await customStatement('''
                  CREATE TABLE entitlements (
                    product_id TEXT NOT NULL,
                    granted_at INTEGER NOT NULL,
                    PRIMARY KEY (product_id)
                  )
                ''');
              // 15 → 16: settings gain REQ-034's garden theme. Its column
              // defaults to `zen`, and that default is the whole step.
              //
              // Zen is the free theme, so an upgrading user arrives in the
              // garden they already had — §5.1's palette *is* Zen's, and every
              // plant in the ground was grown in it.
              case 15:
                await m.addColumn(settings, settings.gardenTheme);
              // 16 → 17: REQ-040's decor gets a table, as version 17 shaped it,
              // and it is left empty.
              //
              // Empty is the only thing it could be: nobody upgrading into this
              // version has placed anything, because there was nothing to
              // place. Their garden and their plants come through untouched by
              // construction — this step adds a table and writes no row of any
              // other.
              //
              // Written out as SQL for the reason every other step here is: a
              // column a later ticket adds to this table must not appear
              // retroactively in the version this step introduces.
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
              // 17 → 18: `entitlements` is dropped, because the app is free and
              // there is nothing left that could read it.
              //
              // **Dropped rather than left standing**, and that is a decision
              // rather than tidiness: a table nothing reads is a table the next
              // person to open this file has to work out the status of. Nobody
              // is charged twice by it — there is nothing to buy — and no user's
              // garden is touched: the plants, the sessions, the arrangement and
              // the settings are all in other tables and this step writes to
              // none of them. See `docs/adr/0021-…`.
              //
              // `IF EXISTS` because a database created at version 18 or later
              // never had the table, and a step that threw on its absence would
              // turn a future rebuild of this schema into a crash.
              case 17:
                await customStatement('DROP TABLE IF EXISTS entitlements');
              // 18 → 19: settings gain REQ-031's end sound. Its column defaults
              // to `windChime`, and that default is the whole step.
              //
              // The chime is what every user upgrading into this version has
              // been hearing since ticket 06, so the first thing this ticket
              // does for them is nothing: the choice appears, and what they
              // already had is what it is already on.
              case 18:
                await m.addColumn(settings, settings.endSound);
              // 19 → 20: the cycle's position gets a row of its own. Nothing is
              // backfilled: a missing row reads as session one of the cycle.
              case 19:
                await customStatement(createCycle);
              // A version with no step out of it. Loud rather than silent: the
              // alternative is an app running against a schema it only assumes
              // it has.
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
          // Off by default in SQLite, and off per-connection rather than
          // per-database, so it has to be asked for on every open.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Rebuilds `plants` in the shape version 11 gives it, carrying every plant
  /// already in the ground across unchanged.
  ///
  /// The copy-and-swap SQLite asks for when a column's nullability changes.
  /// Every existing row keeps the duration it had and gets no milestone, which
  /// is the truth about it: a plant written before this version was grown by a
  /// session, and none of them was ever an award.
  ///
  /// The columns are listed on both sides of the `INSERT` rather than left to
  /// `SELECT *`, so a future column added to the new table cannot silently
  /// shift the copy one place along.
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

  /// Gives every plant already in the ground the plot it would have been
  /// planted in, oldest first.
  ///
  /// Dart rather than SQL because the placement order is a domain rule and not
  /// an expression: which plot is nearest the middle is decided in
  /// [GardenPlots], and a `CASE` statement two hundred branches long that
  /// restated it would be a second copy of the rule waiting to disagree with
  /// the first.
  ///
  /// A garden of more than two hundred plants — reachable only by a user who
  /// arrives here having done that many sessions — leaves the excess with no
  /// plot, which is exactly what a full garden does to a new plant.
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
    final file = File(p.join(directory.path, 'pomodoro_garden.sqlite'));
    // Opened on a background isolate: a query that touches a large garden must
    // not be able to drop a frame on the UI thread.
    return NativeDatabase.createInBackground(file);
  });
}
