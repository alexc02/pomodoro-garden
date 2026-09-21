import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/event_log.dart';

/// `garden_viewed`: how long the garden tab was in front and how far the user
/// zoomed. Recorded when the visit ends. The app opens on the garden, so a
/// launch starts one.
void main() {
  late FixedClock clock;
  late AppDatabase database;

  setUp(() {
    clock = FixedClock(testInstant);
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  // Portrait phone. In the default landscape window the fitted camera is
  // already at max zoom-in, so a pinch would change nothing.
  Future<void> launch(WidgetTester tester) => pumpApp(
        tester,
        clock: clock,
        database: database,
        surface: const Size(390, 844),
      );

  Future<List<LoggedEvent>> visits() =>
      eventsNamed(database, AnalyticsEventName.gardenViewed);

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
    // Nothing has moved the camera, so this is the fitted scale.
    expect(event.parameters['zoom_level'], isA<double>());
  });

  testWidgets('a garden still on screen is not yet a visit to record',
      (tester) async {
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
    // A pinched-in visit has to record differently from a fitted one. The
    // fitted scale comes from the first visit, not the widget.
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
    // On a phone most visits end this way, not by switching tabs.
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
    // The launch opens on the garden: one visit for that, none after.
    await launch(tester);
    await lookAway(tester);

    clock.advance(const Duration(minutes: 10));
    await tapTab(tester, AppTab.settings);
    await settle(tester);

    expect(await visits(), hasLength(1));
  });
}
