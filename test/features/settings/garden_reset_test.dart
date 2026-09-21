import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/database_providers.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/features/garden/decor_picker.dart';
import 'package:pip_garden/src/features/garden/milestone_card.dart';
import 'package:pip_garden/src/features/settings/reset_garden.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/analytics_fakes.dart';
import '../../support/app_harness.dart';
import '../../support/celebrations.dart';
import '../../support/event_log.dart';
import '../../support/garden_seed.dart';
import '../../support/live_surface_fake.dart';

// Garden reset through the real app: the settings row, both confirmations,
// and the screens afterwards. Which rows get cleared is covered in
// test/data/garden_reset_test.dart.
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  Future<void> launch(
    WidgetTester tester, {
    int sessions = 6,
    GardenSettings? settings,
  }) async {
    await seedGarden(database, sessions: sessions);

    await pumpApp(
      tester,
      database: database,
      settings: settings,
      surface: const Size(500, 1200),
    );
    // 10+ sessions earns the milestone and its sheet covers the tab bar.
    await dismissCelebrations(tester);
  }

  Future<void> openSettings(WidgetTester tester) =>
      tapTab(tester, AppTab.settings);

  /// Taps the reset row and answers both dialogs per [confirming].
  Future<void> tapReset(
    WidgetTester tester, {
    bool confirmFirst = true,
    bool confirming = true,
  }) async {
    await tester.tap(await scrollToSetting(tester, ResetGardenKeys.control));
    await settle(tester);

    await tester.tap(find.descendant(
      of: find.byKey(ResetGardenKeys.firstConfirmation),
      matching: find.text(confirmFirst ? 'Continue' : 'Keep my garden'),
    ));
    await settle(tester);
    if (!confirmFirst) return;

    await tester.tap(find.descendant(
      of: find.byKey(ResetGardenKeys.secondConfirmation),
      matching: find.text(confirming ? 'Reset my garden' : 'Keep my garden'),
    ));
    await settle(tester);
  }

  Future<int> countOf(String table) async {
    final rows =
        await database.customSelect('SELECT COUNT(*) AS n FROM $table').get();
    return rows.single.read<int>('n');
  }

  group('confirmations', () {
    testWidgets('reset is in settings', (tester) async {
      await launch(tester);
      await openSettings(tester);

      expect(await scrollToSetting(tester, ResetGardenKeys.control),
          findsOneWidget);
      expect(find.text('Reset your garden'), findsOneWidget);
    });

    testWidgets('tapping the row clears nothing', (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tester.tap(await scrollToSetting(tester, ResetGardenKeys.control));
      await settle(tester);

      expect(find.byKey(ResetGardenKeys.firstConfirmation), findsOneWidget);
      expect(await countOf('plants'), 6);
    });

    testWidgets('cancelling the first dialog clears nothing', (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tapReset(tester, confirmFirst: false);

      expect(find.byKey(ResetGardenKeys.secondConfirmation), findsNothing);
      expect(await countOf('plants'), 6);
      expect(await countOf('sessions'), 6);
    });

    testWidgets('confirming only the first dialog clears nothing',
        (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tapReset(tester, confirming: false);

      expect(await countOf('plants'), 6);
      expect(await countOf('sessions'), 6);
      expect(find.byKey(ResetGardenKeys.outcome), findsNothing);
    });

    testWidgets('second dialog wording', (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tester.tap(await scrollToSetting(tester, ResetGardenKeys.control));
      await settle(tester);
      await tester.tap(find.descendant(
        of: find.byKey(ResetGardenKeys.firstConfirmation),
        matching: find.text('Continue'),
      ));
      await settle(tester);

      expect(
        find.descendant(
          of: find.byKey(ResetGardenKeys.secondConfirmation),
          matching: find.text(
            'This will clear all plants and stats. This cannot be undone.',
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('clears', () {
    testWidgets('plants, sessions and the event log', (tester) async {
      await launch(tester);
      // Launch logs app_opened, so the log isn't empty.
      expect(await recordedEvents(database), isNotEmpty);

      await openSettings(tester);
      await tapReset(tester);

      expect(await countOf('plants'), 0);
      expect(await countOf('sessions'), 0);
      expect(await recordedEvents(database), isEmpty);
    });

    testWidgets('milestone awards', (tester) async {
      // 12 sessions is past the first milestone, so it's awarded at launch.
      await launch(tester, sessions: 12);
      await settle(tester);

      final garden = DriftPlantRepository(database);
      expect(await garden.awardedMilestones(), contains(Milestone.ten));

      await openSettings(tester);
      await tapReset(tester);

      expect(await garden.awardedMilestones(), isEmpty);
    });

    testWidgets('first milestone can be earned again', (tester) async {
      await launch(tester, sessions: 12);
      await openSettings(tester);
      await tapReset(tester);

      // Launch catch-up decides which milestones are due; should match a user
      // who never reached ten.
      await killApp(tester);
      await seedGarden(database, sessions: 10);
      await pumpApp(
        tester,
        database: database,
        surface: const Size(500, 1200),
      );
      await settle(tester);
      await settle(tester);

      expect(find.byType(MilestoneCard), findsOneWidget);
      expect(
        await DriftPlantRepository(database).awardedMilestones(),
        {Milestone.ten},
      );
    });

    testWidgets('decor', (tester) async {
      await launch(tester, sessions: 6);
      await DriftDecorRepository(database).save(Decor(
        id: 'bench',
        kind: DecorKind.bench,
        plot: const GardenPlot(2, 1),
        placedAt: testInstant,
      ));

      await openSettings(tester);
      await tapReset(tester);

      expect(await countOf('decor'), 0);
    });
  });

  group('keeps', () {
    testWidgets('the chosen theme', (tester) async {
      await launch(
        tester,
        settings: GardenSettings.defaults.withGardenTheme(GardenTheme.tropical),
      );
      await openSettings(tester);
      await tapReset(tester);

      expect(
        await scrollToSetting(tester, SettingsKeys.gardenTheme),
        findsOneWidget,
      );
      expect(find.text('Theme: ${GardenTheme.tropical.label}'), findsOneWidget);
    });

    testWidgets('arranging', (tester) async {
      await launch(tester, sessions: 6);
      await openSettings(tester);
      await tapReset(tester);

      await tapTab(tester, AppTab.garden);
      expect(find.byKey(DecorKeys.arrange), findsOneWidget);
    });

    testWidgets('all preferences', (tester) async {
      await launch(
        tester,
        settings: GardenSettings.defaults
            .withSessionLength(const Duration(minutes: 50))
            .withBreakLength(const Duration(minutes: 12))
            .withLongBreakAfter(6)
            .withHaptics(enabled: false),
      );
      await openSettings(tester);
      await tapReset(tester);

      // Scroll back up; ListView doesn't build offscreen controls.
      await scrollToSetting(tester, SettingsKeys.sessionLength);
      expect(find.text('50 min'), findsOneWidget);
      expect(find.text('12 min'), findsOneWidget);
      expect(find.text('6 sessions'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
                await scrollToSetting(tester, SettingsKeys.haptics))
            .value,
        isFalse,
      );
    });

    testWidgets('onboarding state', (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tapReset(tester);

      // Reset must not bring back onboarding.
      expect(find.text('Welcome to Pip Garden'), findsNothing);
    });
  });

  group('afterwards', () {
    testWidgets('garden shows twelve empty plots', (tester) async {
      await launch(tester, sessions: 30);
      // Open the garden first so IndexedStack keeps it alive, which is when a
      // stale garden could survive.
      await tapTab(tester, AppTab.garden);
      expect(
        find.bySemanticsLabel(RegExp(r'Your garden: \d+ plants')),
        findsOneWidget,
      );

      await openSettings(tester);
      await tapReset(tester);
      await tapTab(tester, AppTab.garden);

      expect(
        find.bySemanticsLabel(
          'Your garden: 12 plots of bare soil, nothing growing yet.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Finish a session and your first plant goes in here.'),
        findsOneWidget,
      );
    });

    testWidgets('journal is empty', (tester) async {
      await launch(tester, sessions: 12);
      // Open first so the journal has loaded and is kept alive.
      await tapTab(tester, AppTab.journal);
      expect(find.text('Lifetime'), findsOneWidget);

      await openSettings(tester);
      await tapReset(tester);
      await tapTab(tester, AppTab.journal);

      // Same empty state as a fresh install.
      expect(find.text('Nothing pressed between these pages yet.'),
          findsOneWidget);
      expect(find.text('This week'), findsNothing);
      expect(find.text('Lifetime'), findsNothing);
    });

    testWidgets('settings shows a confirmation', (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tapReset(tester);

      expect(find.byKey(ResetGardenKeys.outcome), findsOneWidget);
      expect(
        find.text("Your garden's clear. Your next session plants the first "
            'thing in it.'),
        findsOneWidget,
      );
    });

    testWidgets('confirmation shows once', (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tapReset(tester);

      // Wait for the snack bar to go. The tab stays alive, so a message held in
      // state would still be here and soon be wrong.
      await settle(tester, over: const Duration(seconds: 8));

      expect(find.byKey(ResetGardenKeys.outcome), findsNothing);
    });

    testWidgets('live surface is clear', (tester) async {
      final surface = FakeLiveSessionSurface();
      await seedGarden(database, sessions: 6);
      await pumpApp(
        tester,
        database: database,
        liveSurface: surface,
        surface: const Size(500, 1200),
      );
      await dismissCelebrations(tester);

      await openSettings(tester);
      await tapReset(tester);

      // The surface only shows an in-flight session, and reset is refused while
      // one exists, so there's nothing stale to show.
      expect(surface.showing, isNull);
    });

    testWidgets('garden stays empty after relaunch', (tester) async {
      await launch(tester, sessions: 6);
      await openSettings(tester);
      await tapReset(tester);

      await killApp(tester);
      await pumpApp(tester, database: database, surface: const Size(500, 1200));
      await tapTab(tester, AppTab.garden);

      expect(
        find.bySemanticsLabel(
          'Your garden: 12 plots of bare soil, nothing growing yet.',
        ),
        findsOneWidget,
      );
    });
  });

  group('failure', () {
    testWidgets('reports the error and keeps the garden', (tester) async {
      final errors = captureErrors();
      await seedGarden(database, sessions: 6);
      await pumpApp(
        tester,
        database: database,
        surface: const Size(500, 1200),
        overrides: [
          gardenResetProvider.overrideWithValue(const _UnclearableGarden()),
        ],
      );
      await dismissCelebrations(tester);

      await openSettings(tester);
      await tapReset(tester);

      expect(
        find.text("Your garden couldn't be cleared just now. Nothing's been "
            'removed.'),
        findsOneWidget,
      );
      // The message says nothing was removed, so check that's true.
      expect(await countOf('plants'), 6);
      expect(await countOf('sessions'), 6);
      expect(errors, hasLength(1));
      expect(errors.single.context.toString(), contains('resetting the garden'));
    });
  });

  group('with a timer in flight', () {
    testWidgets('reset is refused while running', (tester) async {
      await launch(tester);
      await startSession(tester);
      await openSettings(tester);

      expect(await scrollToSetting(tester, ResetGardenKeys.heldBack),
          findsOneWidget);
      expect(find.byKey(ResetGardenKeys.control), findsNothing);
      expect(find.textContaining('A session or break is running'),
          findsOneWidget);

      await tapTab(tester, AppTab.timer);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('refused while paused', (tester) async {
      await launch(tester);
      await startSession(tester);
      await pauseSession(tester);
      await openSettings(tester);

      expect(await scrollToSetting(tester, ResetGardenKeys.heldBack),
          findsOneWidget);
    });

    testWidgets('refused on the completion screen', (tester) async {
      final clock = FixedClock(testInstant);
      await seedGarden(database, sessions: 6);
      await pumpApp(
        tester,
        clock: clock,
        database: database,
        surface: const Size(500, 1200),
      );
      await dismissCelebrations(tester);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);
      expect(find.text('Session complete'), findsOneWidget);

      // The user is looking at the plant they just grew, so clearing now would
      // leave stale data on screen.
      await openSettings(tester);
      expect(await scrollToSetting(tester, ResetGardenKeys.heldBack),
          findsOneWidget);
      // Nothing is running, so the note must not say so.
      expect(find.textContaining('is running'), findsNothing);
      expect(find.textContaining('just finished'), findsOneWidget);
    });

    testWidgets('allowed again once idle', (tester) async {
      await launch(tester);
      await startSession(tester);
      await openSettings(tester);
      expect(find.byKey(ResetGardenKeys.control), findsNothing);

      await tapTab(tester, AppTab.timer);
      await cancelSession(tester, confirm: true);
      await openSettings(tester);

      expect(await scrollToSetting(tester, ResetGardenKeys.control),
          findsOneWidget);
    });
  });
}

/// A reset that always throws. A closed database would take the rest of the
/// app down before the message could be checked.
final class _UnclearableGarden implements GardenReset {
  const _UnclearableGarden();

  @override
  Future<void> clear() async {
    throw StateError('the database would not answer');
  }
}
