import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/features/garden/garden_view.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/event_log.dart';

/// PRD §7.1's `garden_viewed`: how long the user spent looking at their garden,
/// and how far into it they went.
///
/// A visit is a stretch of the garden being the tab in front of the user, and it
/// is recorded when it *ends* — which is the first moment there is a length to
/// record. The app opens on the garden, so a launch starts one.
void main() {
  late FixedClock clock;
  late AppDatabase database;

  setUp(() {
    clock = FixedClock(testInstant);
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  // A phone, held upright. On the suite's default landscape window the
  // garden's fitted camera is already at the closest zoom allowed, and a pinch
  // could not be told from no pinch.
  Future<void> launch(WidgetTester tester) => pumpApp(
        tester,
        clock: clock,
        database: database,
        surface: const Size(390, 844),
      );

  Future<List<LoggedEvent>> visits() =>
      eventsNamed(database, AnalyticsEventName.gardenViewed);

  /// Leaves the garden for the timer, ending the visit.
  Future<void> lookAway(WidgetTester tester) async {
    await tapTab(tester, AppTab.timer);
    await settle(tester);
  }

  testWidgets('leaving the garden records how long it was on screen',
      (tester) async {
    await launch(tester);

    clock.advance(const Duration(seconds: 40));
    await lookAway(tester);

    final event = await theEventNamed(
      database,
      AnalyticsEventName.gardenViewed,
    );

    expect(event.parameters['time_spent_seconds'], 40);
    // The camera opens fitted to the screen and nothing has moved it, so what
    // is recorded is the garden at the scale the user was handed.
    expect(event.parameters['zoom_level'], isA<double>());
  });

  testWidgets('a garden still on screen is not yet a visit to record',
      (tester) async {
    // Recorded when the user leaves, because that is when there is a length.
    await launch(tester);

    clock.advance(const Duration(seconds: 30));
    await settle(tester);

    expect(await visits(), isEmpty);
  });

  testWidgets('coming back is a second visit, timed from the return',
      (tester) async {
    await launch(tester);

    clock.advance(const Duration(seconds: 15));
    await lookAway(tester);
    clock.advance(const Duration(minutes: 5));
    await tapTab(tester, AppTab.garden);
    clock.advance(const Duration(seconds: 25));
    await lookAway(tester);

    expect(
      (await visits()).map((event) => event.parameters['time_spent_seconds']),
      [15, 25],
      reason: 'the five minutes on the timer belong to neither visit',
    );
  });

  testWidgets('the zoom recorded is where the user left the camera',
      (tester) async {
    // §7.1 asks how far *into* their garden people go, and the camera opens
    // fitted to the screen — so what makes the parameter worth having is that a
    // user who pinched in is recorded differently from one who did not. The
    // fitted scale is read off the first visit rather than out of the widget,
    // so this test knows nothing the log does not.
    await launch(tester);
    await lookAway(tester);
    await tapTab(tester, AppTab.garden);

    final focus = tester.getCenter(find.byType(GardenView));
    final first = await tester.startGesture(focus - const Offset(30, 0));
    final second = await tester.startGesture(focus + const Offset(30, 0));
    for (var step = 0; step < 8; step++) {
      await first.moveBy(const Offset(-15, 0));
      await second.moveBy(const Offset(15, 0));
      await tester.pump();
    }
    await first.up();
    await second.up();
    await settle(tester);

    await lookAway(tester);

    final zooms = (await visits())
        .map((event) => event.parameters['zoom_level'] as double)
        .toList();

    expect(zooms.last, greaterThan(zooms.first),
        reason: 'the camera the user pinched open to');
  });

  testWidgets('a visit the user was still on when the app went away is '
      'recorded too', (tester) async {
    // On a phone, most garden visits end this way rather than by switching
    // tabs — a view that only recorded the ones that were left behind would be
    // missing most of what §7.1 is asking about.
    await launch(tester);

    clock.advance(const Duration(seconds: 12));
    await killApp(tester);

    expect(
      (await visits()).single.parameters['time_spent_seconds'],
      12,
    );
  });

  testWidgets('a user who never looks at the garden records nothing',
      (tester) async {
    // The launch itself opens on the garden, so this is a user who walked away
    // from it and stayed away: one visit for the launch, and none after.
    await launch(tester);
    await lookAway(tester);

    clock.advance(const Duration(minutes: 10));
    await tapTab(tester, AppTab.settings);
    await settle(tester);

    expect(await visits(), hasLength(1));
  });
}
