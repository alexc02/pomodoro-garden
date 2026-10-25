import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/database_providers.dart';
import 'package:pomodoro_garden/src/data/drift_decor_repository.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/features/garden/decor_picker.dart';
import 'package:pomodoro_garden/src/features/garden/milestone_card.dart';
import 'package:pomodoro_garden/src/features/settings/reset_garden.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../../support/analytics_fakes.dart';
import '../../support/app_harness.dart';
import '../../support/celebrations.dart';
import '../../support/event_log.dart';
import '../../support/garden_seed.dart';
import '../../support/live_surface_fake.dart';

/// REQ-036's reset, driven through the real app.
///
/// Everything here is a tap a user makes: the row in settings, the first
/// question, the second question, and then the tab the emptiness has to have
/// arrived on. `test/data/garden_reset_test.dart` is the narrower test of which
/// rows go; this is the one about the two confirmations in front of them and
/// the screens behind them.
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
    // A seeded garden of ten or more sessions is owed REQ-021's award, and the
    // sheet it raises stands over the tab bar. Every test here has to get past
    // it before it can do anything, and none of them is about it.
    await dismissCelebrations(tester);
  }

  Future<void> openSettings(WidgetTester tester) =>
      tapTab(tester, AppTab.settings);

  /// Taps the row, and answers both questions the way [confirming] says.
  ///
  /// Written as one helper because the flow is one thing the user does, and
  /// because every test below has to get through the same two dialogs to reach
  /// what it is actually about.
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

  group('the two confirmations', () {
    testWidgets('the reset lives in settings', (tester) async {
      await launch(tester);
      await openSettings(tester);

      expect(await scrollToSetting(tester, ResetGardenKeys.control),
          findsOneWidget);
      expect(find.text('Reset your garden'), findsOneWidget);
    });

    testWidgets('the row alone clears nothing', (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tester.tap(await scrollToSetting(tester, ResetGardenKeys.control));
      await settle(tester);

      expect(find.byKey(ResetGardenKeys.firstConfirmation), findsOneWidget);
      expect(await countOf('plants'), 6);
    });

    testWidgets('backing out of the first question clears nothing',
        (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tapReset(tester, confirmFirst: false);

      expect(find.byKey(ResetGardenKeys.secondConfirmation), findsNothing);
      expect(await countOf('plants'), 6);
      expect(await countOf('sessions'), 6);
    });

    testWidgets('answering the first question is not enough to clear anything',
        (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tapReset(tester, confirming: false);

      expect(await countOf('plants'), 6);
      expect(await countOf('sessions'), 6);
      expect(find.byKey(ResetGardenKeys.outcome), findsNothing);
    });

    testWidgets('the second question says REQ-036 plainly', (tester) async {
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

  group('what a reset clears', () {
    testWidgets('the plants, the sessions and the event log', (tester) async {
      await launch(tester);
      // The launch itself records an `app_opened`, so the log has something in
      // it to lose before anything else is asked of it.
      expect(await recordedEvents(database), isNotEmpty);

      await openSettings(tester);
      await tapReset(tester);

      expect(await countOf('plants'), 0);
      expect(await countOf('sessions'), 0);
      expect(await recordedEvents(database), isEmpty);
    });

    testWidgets('the milestone awards, so they can be earned again',
        (tester) async {
      // Twelve sessions is past REQ-021's first milestone, so the launch awards
      // the bonus plant before anything is reset.
      await launch(tester, sessions: 12);
      await settle(tester);

      final garden = DriftPlantRepository(database);
      expect(await garden.awardedMilestones(), contains(Milestone.ten));

      await openSettings(tester);
      await tapReset(tester);

      expect(await garden.awardedMilestones(), isEmpty);
    });

    testWidgets('and the first of them is earned all over again from zero',
        (tester) async {
      await launch(tester, sessions: 12);
      await openSettings(tester);
      await tapReset(tester);

      // Ten sessions from an empty garden, and then the app opens on them: the
      // catch-up at launch is what asks which milestones are due, and the
      // answer has to be the one a user who had never reached ten would get.
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

    testWidgets('the arrangement, so the garden really is bare soil',
        (tester) async {
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

  group('what a reset leaves alone', () {
    testWidgets('the chosen theme, still chosen and still applied',
        (tester) async {
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

    testWidgets('being able to arrange the garden', (tester) async {
      await launch(tester, sessions: 6);
      await openSettings(tester);
      await tapReset(tester);

      // The door into arranging is still there over a garden with nothing in
      // it — which is the whole of "placed-decor availability survives".
      await tapTab(tester, AppTab.garden);
      expect(find.byKey(DecorKeys.arrange), findsOneWidget);
    });

    testWidgets('the user preferences, every one of them', (tester) async {
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

      // Back to the top of the list first: the reset lives at the bottom, and a
      // control scrolled out of a ListView is a control that is not built.
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

    testWidgets('onboarding, which does not come back', (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tapReset(tester);

      // A first-run user meets the welcome step. A user who has just reset
      // their garden is not one, and greeting them as a stranger would be the
      // app forgetting them rather than forgetting their garden.
      expect(find.text('Welcome to Pomodoro Garden'), findsNothing);
    });
  });

  group('what the screens show afterwards', () {
    testWidgets('the garden is twelve plots of bare soil, immediately',
        (tester) async {
      await launch(tester, sessions: 30);
      // Looked at first, so the garden tab is built and kept alive by the
      // shell's IndexedStack — which is the state in which a stale garden would
      // survive a reset done on another tab.
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

    testWidgets('the journal is back to having nothing in it', (tester) async {
      await launch(tester, sessions: 12);
      // Opened first, so the journal's six aggregates have been run and the tab
      // is being kept alive with their answers on it.
      await tapTab(tester, AppTab.journal);
      expect(find.text('Lifetime'), findsOneWidget);

      await openSettings(tester);
      await tapReset(tester);
      await tapTab(tester, AppTab.journal);

      // The invitation a first-run user gets, rather than three cards of
      // zeroes: the journal has nothing to count, and it says so the same way
      // it does on a fresh install.
      expect(find.text('Nothing pressed between these pages yet.'),
          findsOneWidget);
      expect(find.text('This week'), findsNothing);
      expect(find.text('Lifetime'), findsNothing);
    });

    testWidgets('settings says it happened', (tester) async {
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

    testWidgets('and says it once rather than for the rest of the run',
        (tester) async {
      await launch(tester);
      await openSettings(tester);
      await tapReset(tester);

      // Long enough for the snack bar to have gone by itself. The settings tab
      // is kept alive by the shell, so a message held as state under the
      // control would still be sitting here — and by then the user may have
      // grown something, and "your garden is empty" would be a lie.
      await settle(tester, over: const Duration(seconds: 8));

      expect(find.byKey(ResetGardenKeys.outcome), findsNothing);
    });

    testWidgets('nothing is left on the live surface', (tester) async {
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

      // Down, and it was down before the reset too — REQ-033's surface only
      // ever shows a session in flight, and a reset is refused while there is
      // one. That is the whole reason the two criteria do not fight: there is
      // no state in which the lock screen could be showing a garden that has
      // just been cleared.
      expect(surface.showing, isNull);
    });

    testWidgets('an empty garden survives the relaunch', (tester) async {
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

  group('a reset that could not be done', () {
    testWidgets('says so, reports it, and leaves the garden standing',
        (tester) async {
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
      // The sentence has to be true: a message saying nothing was removed, over
      // a garden that lost half of itself, is the worst outcome available here.
      expect(await countOf('plants'), 6);
      expect(await countOf('sessions'), 6);
      expect(errors, hasLength(1));
      expect(errors.single.context.toString(), contains('resetting the garden'));
    });
  });

  group('a timer in flight', () {
    testWidgets('is not something a reset ends', (tester) async {
      await launch(tester);
      await startSession(tester);
      await openSettings(tester);

      expect(await scrollToSetting(tester, ResetGardenKeys.heldBack),
          findsOneWidget);
      expect(find.byKey(ResetGardenKeys.control), findsNothing);
      expect(find.textContaining('A session or break is running'),
          findsOneWidget);

      // And the session is still running, which is the point of refusing.
      await tapTab(tester, AppTab.timer);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('held rather than running is still in flight', (tester) async {
      await launch(tester);
      await startSession(tester);
      await pauseSession(tester);
      await openSettings(tester);

      expect(await scrollToSetting(tester, ResetGardenKeys.heldBack),
          findsOneWidget);
    });

    testWidgets('a session that has just finished is still in flight',
        (tester) async {
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

      // The sharpest case of the four: the user is looking at the plant they
      // just grew, and clearing the garden from under that screen is exactly
      // the stale data the last criterion is about.
      await openSettings(tester);
      expect(await scrollToSetting(tester, ResetGardenKeys.heldBack),
          findsOneWidget);
      // BUG-04: nothing is running, so the note must not say so.
      expect(find.textContaining('is running'), findsNothing);
      expect(find.textContaining('just finished'), findsOneWidget);
    });

    testWidgets('lets the reset back in once it is at rest', (tester) async {
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

/// A database that will not empty: the failure the controller has to absorb.
///
/// Modelled as a throwing port rather than as a closed database, because what
/// is under test is what the *screen* does about it — and a closed database
/// would take the rest of the app down with it before the message could be
/// looked at.
final class _UnclearableGarden implements GardenReset {
  const _UnclearableGarden();

  @override
  Future<void> clear() async {
    throw StateError('the database would not answer');
  }
}
