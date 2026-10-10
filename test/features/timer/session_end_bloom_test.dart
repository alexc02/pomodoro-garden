import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../support/app_harness.dart';
import '../../support/plant_pose.dart';

/// Ticket 27: §5.3's session end bloom, through the real timer screen.
///
/// What the bloom *looks* like — how long, which way, settling into the sway —
/// is `test/garden/growing_plant_test.dart`, which can hand the plant whatever
/// it likes. What only the app can answer is which completions the screen
/// counts as watched, and that is the whole of what is asked here.

void main() {
  testWidgets('a session that completes on screen blooms', (tester) async {
    final clock = FixedClock(testInstant);
    await pumpApp(tester, clock: clock);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Session complete'), findsOneWidget);
    expect(bloomOnScreen(tester), allOf(greaterThan(0), lessThan(1)));
  });

  testWidgets('a session that completed with the app away does not',
      (tester) async {
    // SessionAnnouncer's rule: the notification told the user when it
    // happened. Petals on the way back in would celebrate the app being
    // opened, ten minutes after the news.
    final clock = FixedClock(testInstant);
    await pumpApp(tester, clock: clock);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 5));
    await sendToBackground(tester);
    clock.advance(const Duration(minutes: 30));
    await bringToForeground(tester);

    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(bloomOnScreen(tester), 0, reason: 'found complete, not watched');
    }
    expect(find.text('Session complete'), findsOneWidget);
  });

  testWidgets('a cancelled session does not', (tester) async {
    final clock = FixedClock(testInstant);
    await pumpApp(tester, clock: clock);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 5));
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.text('Cancel session'));
    await settle(tester);

    expect(find.text('Ready to focus'), findsOneWidget);
    expect(bloomOnScreen(tester), 0);
  });
}
