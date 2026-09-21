import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/features/timer/potted_plant.dart';
import 'package:pip_garden/src/features/timer/progress_strip.dart';
import 'package:pip_garden/src/features/timer/timer_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

void main() {
  group('the progress strip', () {
    const size = Size(300, ProgressStrip.height);

    test('fills from the left by progress', () {
      final quarter = ProgressStripPainter.filled(size, 0.25).getBounds();
      expect(quarter.left, 0);
      // The torn edge goes slightly past the fill line, no further.
      expect(quarter.right, greaterThan(75));
      expect(quarter.right, lessThan(75 + ProgressStrip.height));
    });

    test('torn edge until full', () {
      final half = ProgressStripPainter.filled(size, 0.5);
      // Some of the edge sticks out and some sits on the fill line.
      expect(half.contains(const Offset(153, 5)), isTrue);
      expect(half.contains(const Offset(153, ProgressStrip.height / 2)),
          isFalse);

      final full = ProgressStripPainter.filled(size, 1).getBounds();
      expect(full, Offset.zero & size);
    });
  });

  test('pot and plant fill the given height', () {
    for (final height in [64.0, 160.0, 280.0]) {
      final side = PottedPlant.plantSideFor(height);
      expect(side, lessThan(height),
          reason: 'the pot takes some of the height under the plant');
      expect(side, greaterThan(height / 2),
          reason: 'plant is most of the height');
    }
  });

  group('the timer screen', () {
    late FixedClock clock;
    setUp(() => clock = FixedClock(testInstant));

    testWidgets('has no app bar', (tester) async {
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

    testWidgets('shows planted and ready times', (tester) async {
      await pumpApp(tester, clock: clock);
      await startSession(tester);

      String line(String opening) => tester
          .widget<Text>(find.textContaining(RegExp('^$opening\\d')))
          .data!
          .substring(opening.length);

      final planted = line('Planted ');
      final ready = line('Ready ');
      expect(planted, isNot(ready));

      // A pause pushes the ready time out and leaves the planted time.
      await advance(tester, clock, const Duration(minutes: 3));
      await pauseSession(tester);
      await advance(tester, clock, const Duration(minutes: 4));
      expect(line('Planted '), planted);
      expect(line('Ready '), isNot(ready));
    });

    testWidgets('no times when idle', (tester) async {
      await pumpApp(tester, clock: clock);
      await tapTab(tester, AppTab.timer);

      expect(find.textContaining(RegExp(r'^Planted \d')), findsNothing);
      expect(find.textContaining(RegExp(r'^Ready \d')), findsNothing);
    });
  });
}
