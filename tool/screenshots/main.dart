// The store screenshots' launch: the real app over a seeded, in-memory garden.
//
// Not part of the shipped app — it is only ever built with `-t`, by
// `tool/screenshots/capture.sh`, which picks what to show by writing
// `shot.env` (one NAME=value per line) into the app's Documents folder before
// each launch, so one build serves every shot. A file rather than the launch
// environment because Dart sees an empty environment on iOS.
//
//   SHOT_TAB      garden | timer | journal | settings   (default garden)
//   SHOT_THEME    zen | tropical | wildflower           (default zen)
//   SHOT_SEASON   spring | summer | autumn | winter     (default spring)
//   SHOT_SESSION  true to launch into a session part-way through
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pip_garden/src/app.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/database_providers.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:pip_garden/src/garden/season_providers.dart';
import 'package:pip_garden/src/notifications/notification_providers.dart';
import 'package:pip_garden/src/notifications/session_notifications.dart';
import 'package:pip_garden/src/shell/shell_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';
import 'package:pip_garden/src/time/clock_provider.dart';

late final Map<String, String> _shot;
String get _tab => _shot['SHOT_TAB'] ?? 'garden';
String get _theme => _shot['SHOT_THEME'] ?? 'zen';
String get _season => _shot['SHOT_SEASON'] ?? 'spring';
bool get _inSession => _shot['SHOT_SESSION'] == 'true';

/// How many sessions the seeded user has completed: enough for a full garden
/// and the first three milestone plants, few enough to look grown rather than
/// generated.
const _completed = 80;

/// Fixed, so every capture shows the same garden and the same journal.
/// Twenty to ten this morning, the time the status bar is set to.
final _today = DateTime.now();
final _now = DateTime(_today.year, _today.month, _today.day, 9, 41).toUtc();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _shot = await _readShot();

  final database = AppDatabase.forTesting();
  await _seed(database);

  runApp(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_now)),
        databaseProvider.overrideWithValue(database),
        // A restored session schedules its completion notice, and the
        // permission prompt that comes with it would sit over the screenshot.
        sessionNotificationsProvider.overrideWithValue(_SilentNotifications()),
        forcedSeasonProvider.overrideWith(
          () => _PinnedSeason(Season.values.byName(_season)),
        ),
        selectedTabProvider.overrideWith(
          () => _OpenTab(AppTab.values.byName(_tab)),
        ),
      ],
      child: const PipGardenApp(),
    ),
  );
}

Future<Map<String, String>> _readShot() async {
  final file = File(
    p.join((await getApplicationDocumentsDirectory()).path, 'shot.env'),
  );
  if (!file.existsSync()) return const {};
  return {
    for (final line in file.readAsLinesSync())
      if (line.contains('='))
        line.substring(0, line.indexOf('=')): line.substring(
          line.indexOf('=') + 1,
        ),
  };
}

Future<void> _seed(AppDatabase database) async {
  final sessions = DriftSessionRepository(database);
  final plants = DriftPlantRepository(database);
  final decor = DriftDecorRepository(database);

  final settings = DriftSettingsRepository(database);
  await settings.save(
    (await settings.load()).withOnboardingCompleted().withGardenTheme(
      GardenTheme.values.byName(_theme),
    ),
  );

  // Two plots left empty, so the garden reads as still growing rather than full.
  final unlocked = GardenPlots.unlockedAfter(_completed) - 2;
  final occupied = <GardenPlot>{};
  GardenPlot? nextPlot() {
    if (occupied.length >= unlocked) return null;
    final plot = GardenPlots.nextFree(occupied);
    if (plot != null) occupied.add(plot);
    return plot;
  }

  // Decor first, on plots spread through the garden, so the plants fill in
  // around it the way they would around anything a user placed.
  for (final (i, kind) in DecorKind.values.indexed) {
    final plot = GardenPlots.inPlacementOrder[6 + i * 9];
    occupied.add(plot);
    await decor.save(
      Decor(id: 'shot-${kind.name}', kind: kind, plot: plot, placedAt: _now),
    );
  }

  // Every milestone this user has passed gets a plot kept for it: one left
  // unplanted would be awarded at launch, and its celebration would sit over
  // the screenshot.
  final milestonePlots = [
    for (final _ in Milestone.values.where((m) => m.sessions <= _completed))
      nextPlot()!,
  ];

  // The last couple of months, newest first: one to three sessions on a
  // working day and the odd day off, so the journal's calendar has texture
  // rather than a solid block. Yesterday is the newest, so this week is never
  // empty.
  final daysAgo = <int>[];
  for (var ago = 1; daysAgo.length < _completed; ago++) {
    if ((ago * 7) % 11 < 3) continue;
    for (var k = 0; k <= (ago * 5) % 3 && daysAgo.length < _completed; k++) {
      daysAgo.add(ago);
    }
  }

  for (var n = 0; n < _completed; n++) {
    final anchor = DateTime(
      _today.year,
      _today.month,
      _today.day - daysAgo[_completed - 1 - n],
      8 + (n * 5) % 9,
      (n * 17) % 60,
    ).toUtc();
    final session = FocusSession(
      id: 'shot-session-$n',
      startedAt: anchor,
      plannedDuration: Duration(minutes: 10 + (n % 6) * 20),
    ).completedAt(anchor.add(Duration(minutes: 10 + (n % 6) * 20)));

    await sessions.save(session);
    // Only the plants there is room for: one held back for want of space puts
    // a "garden is full" banner over the screenshot.
    final plot = nextPlot();
    if (plot != null) {
      await plants.save(
        Plant.fromSession(session, id: 'shot-plant-$n', plot: plot),
      );
    }

    final milestone = Milestone.values
        .where((m) => m.sessions == n + 1)
        .firstOrNull;
    if (milestone != null) {
      await plants.save(
        Plant.forMilestone(
          milestone,
          id: 'shot-milestone-${milestone.sessions}',
          plantedAt: session.endedAt!,
          plot: milestonePlots.removeAt(0),
        ),
      );
    }
  }

  if (_inSession) {
    await sessions.save(
      FocusSession(
        id: 'shot-in-flight',
        startedAt: _now.subtract(const Duration(minutes: 14, seconds: 23)),
        plannedDuration: const Duration(minutes: 25),
      ),
    );
  }
}

final class _SilentNotifications implements SessionNotifications {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleCompletion(SessionCompletionNotice notice) async {}

  @override
  Future<void> scheduleFollowUp(SessionCompletionNotice notice) async {}

  @override
  Future<void> cancelCompletion() async {}
}

class _PinnedSeason extends ForcedSeason {
  _PinnedSeason(this._season);

  final Season _season;

  @override
  Season? build() => _season;
}

class _OpenTab extends SelectedTab {
  _OpenTab(this._tab);

  final AppTab _tab;

  @override
  AppTab build() => _tab;
}
