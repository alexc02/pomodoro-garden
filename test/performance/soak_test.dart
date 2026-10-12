import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/garden_seed.dart';

// Soak test: a hundred sessions of normal and awkward use, asserting nothing
// throws. The real crash-free target (< 0.5% of sessions) is a field metric
// from Xcode Organizer and Play vitals; this is a stricter bar run before
// shipping, to catch leaks and runaway rebuilds that only show up over time.
//
// [_Quiet] records errors so the first one is reported with its session
// number.

const Size _window = Size(400, 800);

/// About seven weeks at 2.5 sessions a day, and past every milestone award.
const int _sessions = 100;

class _Quiet {
  _Quiet.listen() {
    _was = FlutterError.onError;
    FlutterError.onError = (details) {
      failures.add(details);
      _was?.call(details);
    };
  }

  final List<FlutterErrorDetails> failures = [];
  FlutterExceptionHandler? _was;

  void stop() => FlutterError.onError = _was;
}

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
    ))
    .painter! as GardenPainter;

void main() {
  testWidgets('a hundred sessions, and the hundredth behaves like the first',
      (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final clock = FixedClock(DateTime.utc(2026, 1, 5, 9));

    final quiet = _Quiet.listen();
    addTearDown(quiet.stop);

    await pumpApp(
      tester,
      database: database,
      clock: clock,
      settings: GardenSettings.defaults
          .withSessionLength(const Duration(minutes: 25))
          .withBreakLength(const Duration(minutes: 5)),
      surface: _window,
    );

    var completed = 0;

    for (var n = 0; n < _sessions; n++) {
      // Every fourth session is paused, every seventh is backgrounded.
      final interrupted = n % 4 == 3;
      final backgrounded = n % 7 == 5;

      await tapTab(tester, AppTab.timer);
      await startSession(tester);

      if (interrupted) {
        await advance(tester, clock, const Duration(minutes: 6));
        await pauseSession(tester);
        await advance(tester, clock, const Duration(minutes: 2));
        await resumeSession(tester);
      }

      if (backgrounded) {
        await sendToBackground(tester);
        clock.advance(const Duration(minutes: 25));
        await bringToForeground(tester);
        await settle(tester);
      } else {
        await advance(tester, clock, const Duration(minutes: 25));
      }

      completed++;
      await dismissCelebrations(tester);

      // Every tenth, visit the garden and journal; building and disposing
      // screens is where leaked listeners show up.
      if (n % 10 == 9) {
        await tapTab(tester, AppTab.garden);
        await settle(tester);
        await tapTab(tester, AppTab.journal);
        await settle(tester);
      }

      // Spread sessions over days so the journal, streak and season get
      // exercised.
      await advance(tester, clock, const Duration(hours: 5));

      expect(
        quiet.failures,
        isEmpty,
        reason: 'session $n threw: ${quiet.failures.firstOrNull?.exception}',
      );
    }

    final recorded =
        await DriftSessionRepository(database).completedSessions();
    expect(recorded, hasLength(completed));
    expect(completed, _sessions);

    await tapTab(tester, AppTab.garden);
    await settle(tester);

    final planted = _painter(tester).layout.plants;

    // Bonus plants have no session. Counted separately so this doesn't depend
    // on the milestone table.
    expect(
      planted.where((plant) => plant.sessionId != null),
      hasLength(_sessions),
      reason: 'a session somewhere along the hundred did not grow its plant',
    );
    expect(
      planted.where((plant) => plant.sessionId == null),
      isNotEmpty,
      reason: 'a hundred sessions passes several milestones',
    );
  });

  testWidgets('a full garden survives a long visit with everything running',
      (tester) async {
    // One long look at a full garden with everything animating and the camera
    // being dragged.
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await seedGarden(database, sessions: GardenPlots.maximum);

    final quiet = _Quiet.listen();
    addTearDown(quiet.stop);

    await pumpApp(tester, database: database, surface: _window);
    await dismissCelebrations(tester);
    await tapTab(tester, AppTab.garden);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GardenView)),
    );

    const frames = 60 * 60 * 3;
    for (var frame = 0; frame < frames; frame++) {
      await gesture.moveBy(Offset(frame % 120 < 60 ? 1 : -1, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    expect(quiet.failures, isEmpty);
    expect(_painter(tester).layout.plants, hasLength(200));
  });
}
