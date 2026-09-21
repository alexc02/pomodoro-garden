import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../support/app_harness.dart';
import '../../support/plant_pose.dart';

// Which completions bloom. How the bloom looks is tested in
// test/garden/growing_plant_test.dart.

void main() {
  testWidgets('blooms when completed on screen', (tester) async {
    final clock = FixedClock(testInstant);
    await pumpApp(tester, clock: clock);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Session complete'), findsOneWidget);
    expect(bloomOnScreen(tester), allOf(greaterThan(0), lessThan(1)));
  });

  testWidgets('no bloom when completed in the background', (tester) async {
    // Same rule as SessionAnnouncer: the notification already told the user.
    final clock = FixedClock(testInstant);
    await pumpApp(tester, clock: clock);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 5));
    await sendToBackground(tester);
    clock.advance(const Duration(minutes: 30));
    await bringToForeground(tester);

    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(bloomOnScreen(tester), 0, reason: 'completed while away');
    }
    expect(find.text('Session complete'), findsOneWidget);
  });

  testWidgets('no bloom when cancelled', (tester) async {
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
