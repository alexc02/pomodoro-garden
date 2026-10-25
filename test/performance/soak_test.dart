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

/// PRD §11, ticket 24: **crash-free rate above the §11 target across a soak
/// test on both platforms.** The target is *crashes under 0.5% of sessions*.
///
/// **What a soak test on a workstation is and is not.** §11's number is a field
/// measurement — Xcode Organizer and Play vitals, over real installs, and the
/// PRD says so in the row itself. Nothing here produces that number, and ticket
/// 24 cannot close that criterion without shipping to two stores. What this
/// file does is the part that is worth doing *before* shipping: drive the app
/// through a hundred sessions of ordinary and awkward use and assert that
/// nothing anywhere threw.
///
/// That is a lower bar than 0.5% and a much sharper one. A crash rate is a
/// statistic that tolerates failures; this tolerates none. If the hundredth
/// session behaves differently from the first — a listener never removed, a
/// controller left running, a query that grows, a provider that rebuilds
/// forever — it shows up here as an exception rather than as a percentage six
/// weeks after release.
///
/// **Every uncaught exception is a failure, including the ones Flutter would
/// only print.** `flutter_test` fails a test when an exception reaches
/// `FlutterError.onError`, which covers the framework; [_Quiet] additionally
/// records them so that the count can be asserted as zero rather than relied on
/// implicitly, and so the first one is reported with the iteration it happened
/// on rather than at the end of a hundred.

const Size _window = Size(400, 800);

/// How many sessions the soak runs.
///
/// A hundred is roughly seven weeks of the §11 target usage — 2.5 sessions a
/// day — and it is also past every milestone REQ-021 awards, so the awkward
/// paths (a celebration over the garden, a plot count that grows, a garden that
/// fills up) are all inside the run rather than beyond it.
const int _sessions = 100;

/// Counts everything that reaches the error handler while it is installed.
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
      // Not a hundred identical laps. Every fourth session is interrupted and
      // every seventh goes through a suspend, so the run exercises the paths a
      // real week of use takes rather than the happy one a hundred times.
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

      // Every tenth lap, look at the app the way a user does: the garden, the
      // journal and back. This is where a leaked listener or a provider that
      // rebuilds forever surfaces, because it is the only thing here that
      // builds and disposes screens repeatedly.
      if (n % 10 == 9) {
        await tapTab(tester, AppTab.garden);
        await settle(tester);
        await tapTab(tester, AppTab.journal);
        await settle(tester);
      }

      // The gap between one session and the next, so that sessions land on a
      // spread of days rather than all on the fifth of January — which is what
      // makes the journal, the streak and the season all do real work.
      await advance(tester, clock, const Duration(hours: 5));

      expect(
        quiet.failures,
        isEmpty,
        reason: 'session $n threw: ${quiet.failures.firstOrNull?.exception}',
      );
    }

    // The garden agrees with the sessions that built it.
    final recorded =
        await DriftSessionRepository(database).completedSessions();
    expect(recorded, hasLength(completed));
    expect(completed, _sessions);

    await tapTab(tester, AppTab.garden);
    await settle(tester);

    final planted = _painter(tester).layout.plants;

    // One plant per session, and then REQ-021's awards on top — a bonus plant
    // has no session, which is exactly how it is told apart. Counting them
    // separately rather than asserting a total, because the total is a fact
    // about the milestone table and this test is not about that.
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
    // The other shape a soak takes: not a hundred sessions but one very long
    // look at the result of them, with the screen animating the whole time.
    // Two hundred plants, the sway, the seasonal overlay and a camera that
    // never stops moving, for three simulated minutes.
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

    // Three simulated minutes at sixty frames a second, dragging throughout.
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
