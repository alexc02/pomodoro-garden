import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/features/timer/potted_plant.dart';
import 'package:pomodoro_garden/src/features/timer/progress_strip.dart';
import 'package:pomodoro_garden/src/features/timer/timer_screen.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

/// PRD v2.3's timer: a countdown under a band of sky, the plant in a pot, and
/// a strip of paper filling across.
void main() {
  group('the progress strip', () {
    const size = Size(300, ProgressStrip.height);

    test('fills from the left in proportion to the session', () {
      final quarter = ProgressStripPainter.filled(size, 0.25).getBounds();
      expect(quarter.left, 0);
      // The torn edge reaches a little past the fill line, and no further.
      expect(quarter.right, greaterThan(75));
      expect(quarter.right, lessThan(75 + ProgressStrip.height));
    });

    test('has a torn leading edge, and none once it is full', () {
      final half = ProgressStripPainter.filled(size, 0.5);
      // Somewhere along the leading edge the paper reaches forward, and
      // somewhere it falls back to the fill line: a tear, not a clean cut.
      expect(half.contains(const Offset(153, 5)), isTrue);
      expect(half.contains(const Offset(153, ProgressStrip.height / 2)),
          isFalse);

      final full = ProgressStripPainter.filled(size, 1).getBounds();
      expect(full, Offset.zero & size);
    });
  });

  test('the pot and its plant stand as tall as they are asked to', () {
    for (final height in [64.0, 160.0, 280.0]) {
      final side = PottedPlant.plantSideFor(height);
      expect(side, lessThan(height),
          reason: 'the pot takes some of the height under the plant');
      expect(side, greaterThan(height / 2),
          reason: 'and the plant is still most of it');
    }
  });

  group('the timer screen', () {
    late FixedClock clock;
    setUp(() => clock = FixedClock(testInstant));

    testWidgets('has no app bar: the tab bar names it', (tester) async {
      await pumpApp(tester, clock: clock);
      await tapTab(tester, AppTab.timer);

      expect(
        find.descendant(
          of: find.byType(TimerScreen),
          matching: find.byType(AppBar),
        ),
        findsNothing,
      );
      expect(find.byType(PottedPlant), findsOneWidget);
    });

    testWidgets('says when the session was planted and when it will be ready',
        (tester) async {
      await pumpApp(tester, clock: clock);
      await startSession(tester);

      String line(String opening) => tester
          .widget<Text>(find.textContaining(RegExp('^$opening\\d')))
          .data!
          .substring(opening.length);

      final planted = line('Planted ');
      final ready = line('Ready ');
      expect(planted, isNot(ready));

      // A pause moves the ready time out by as long as it lasts, and leaves
      // the planting where it was.
      await advance(tester, clock, const Duration(minutes: 3));
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      expect(line('Planted '), planted);
      expect(line('Ready '), isNot(ready));
    });

    testWidgets('says nothing about times when nothing is running',
        (tester) async {
      await pumpApp(tester, clock: clock);
      await tapTab(tester, AppTab.timer);

      // "Ready to focus" is the heading; a time is what is not there.
      expect(find.textContaining(RegExp(r'^Planted \d')), findsNothing);
      expect(find.textContaining(RegExp(r'^Ready \d')), findsNothing);
    });
  });
}
