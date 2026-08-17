import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/features/garden/milestone_card.dart';
import 'package:pip_garden/src/garden/milestone_keeper.dart';

import 'app_harness.dart';

/// Dismisses any milestone cards that are up. Anything seeding ten or more
/// sessions will hit one. Bounded so a stuck card fails instead of hanging.
Future<void> dismissCelebrations(WidgetTester tester) async {
  for (var guard = 0; guard <= Milestone.values.length; guard++) {
    await waitForCelebration(tester);
    if (find.byType(MilestoneCard).evaluate().isEmpty) return;

    await tester.tap(find.text('Lovely'));
    await settle(tester);
  }

  fail('a celebration would not go away');
}

/// Waits out the keeper's post-session delay plus the sheet animation.
Future<void> waitForCelebration(WidgetTester tester) async {
  await settle(tester, over: MilestoneKeeper.afterTheSession);
  await settle(tester);
}
