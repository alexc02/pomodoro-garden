import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/features/garden/milestone_card.dart';
import 'package:pomodoro_garden/src/garden/milestone_keeper.dart';

import 'app_harness.dart';

/// Puts REQ-021's celebration away, however many are owed.
///
/// A test that is not about the card still has to get past it: an award made on
/// launch raises a sheet [MilestoneKeeper.afterTheSession] later, and a test
/// asserting on the screen underneath would be asserting through it. Bounded
/// rather than a bare `while`, so a card that will not close fails the test it
/// is in rather than hanging the suite.
///
/// Shared rather than kept beside the milestone tests, because any test that
/// seeds ten or more completed sessions meets it — and a seeded garden big
/// enough to be worth looking at is always one of those.
Future<void> dismissCelebrations(WidgetTester tester) async {
  for (var guard = 0; guard <= Milestone.values.length; guard++) {
    await waitForCelebration(tester);
    if (find.byType(MilestoneCard).evaluate().isEmpty) return;

    await tester.tap(find.text('Lovely'));
    await settle(tester);
  }

  fail('a celebration would not go away');
}

/// Waits out everything between a lull and REQ-021's card being up: the
/// keeper's hold-back after a session, then the sheet rising.
///
/// Measured from the keeper's own constant rather than counted in settles, so a
/// change to how long §5.3's bloom is given moves every test that waits on it.
Future<void> waitForCelebration(WidgetTester tester) async {
  await settle(tester, over: MilestoneKeeper.afterTheSession);
  await settle(tester);
}
