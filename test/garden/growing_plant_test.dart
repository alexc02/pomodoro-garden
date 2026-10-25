import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/theme.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/garden/plant_painter.dart';
import 'package:pip_garden/src/garden/plant_sway.dart';

/// §5.3's four plant animations, asserted on the pose the painter is handed
/// rather than on pixels: whether the plant overshoots is a question about a
/// number, and reading it off a rendered frame would prove less and break more.

const double _size = 200;

/// One frame at sixty hertz, which is what a test pumps when it only wants the
/// animation to have moved.
const Duration _frame = Duration(milliseconds: 16);

final _session = FocusSession(
  id: 'session-1',
  startedAt: DateTime.utc(2026, 8, 11, 9, 41),
  plannedDuration: const Duration(minutes: 25),
);

PlantGrowth _growth(double progress) =>
    PlantGrowth.forSession(_session, progress: progress);

/// The pose the plant is currently being drawn in.
PlantPainter _pose(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(GrowingPlant),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter! as PlantPainter;

/// Changes what the plant on screen is growing, and whether its session has
/// completed.
typedef _Grow = Future<void> Function(PlantGrowth? growth, {bool completed});

/// Puts one plant on screen, and returns a way to change what it is growing.
///
/// [completed] is how the plant starts rather than how it gets there: a plant
/// handed over already complete is one this widget *found*, which is the case
/// the bloom deliberately sits out.
Future<_Grow> _plant(
  WidgetTester tester,
  PlantGrowth? initial, {
  bool completed = false,
}) async {
  var growth = initial;
  var done = completed;
  late StateSetter setState;

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setter) {
              setState = setter;
              return GrowingPlant(
                growth: growth,
                size: _size,
                completed: done,
              );
            },
          ),
        ),
      ),
    ),
  );

  return (PlantGrowth? next, {bool completed = false}) async {
    setState(() {
      growth = next;
      done = completed;
    });
    await tester.pump();
  };
}

/// Turns the phone's reduce-motion setting on for the rest of this test.
///
/// The platform's own switch rather than a [MediaQuery] wrapped around the
/// plant, because that is where the setting comes from: §4.4 is a phone
/// setting, and a test that injected it below the app would prove the widget
/// reads a value nobody sets.
void _keepStill(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
    disableAnimations: true,
    reduceMotion: true,
  );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  group('an empty bed', () {
    testWidgets('draws soil and no plant', (tester) async {
      await _plant(tester, null);

      expect(_pose(tester).sprite, isNull);
      expect(_pose(tester).drop, 0);
      expect(_pose(tester).lean, 0);
    });
  });

  group('the seed drop', () {
    testWidgets('starts above the soil and lands in it', (tester) async {
      final grow = await _plant(tester, null);
      await grow(_growth(0));

      final fromHeight = _pose(tester).drop;
      expect(fromHeight, greaterThan(0),
          reason: 'the seed starts above the soil');

      await tester.pump(GrowingPlant.dropDuration ~/ 2);
      expect(_pose(tester).drop, lessThan(fromHeight),
          reason: 'and falls towards it');

      await tester.pump(GrowingPlant.dropDuration);
      expect(_pose(tester).drop, 0, reason: 'and lands');
    });

    testWidgets('kicks up soil as it lands', (tester) async {
      final grow = await _plant(tester, null);
      await grow(_growth(0));

      expect(_pose(tester).burst, 0, reason: 'nothing has landed yet');

      await tester.pump(GrowingPlant.dropDuration);
      expect(_pose(tester).burst, greaterThan(0));
    });

    testWidgets('a new session drops a new seed', (tester) async {
      final grow = await _plant(tester, null);
      await grow(_growth(0));
      await tester.pump(GrowingPlant.dropDuration);
      expect(_pose(tester).drop, 0);

      final second = FocusSession(
        id: 'session-2',
        startedAt: _session.startedAt,
        plannedDuration: const Duration(minutes: 25),
      );
      await grow(PlantGrowth.forSession(second, progress: 0));

      expect(_pose(tester).drop, greaterThan(0),
          reason: 'the next session plants its own seed');
    });

    testWidgets('growing on does not drop the seed again', (tester) async {
      final grow = await _plant(tester, null);
      await grow(_growth(0));
      await tester.pump(GrowingPlant.dropDuration);

      await grow(_growth(0.2));

      expect(_pose(tester).drop, 0);
    });
  });

  group('the stage transition', () {
    testWidgets('springs past its new size and settles back', (tester) async {
      final grow = await _plant(tester, _growth(0));
      await tester.pump(GrowingPlant.dropDuration);
      expect(_pose(tester).scale, 1, reason: 'a settled plant is at its size');

      await grow(_growth(0.2));
      expect(_pose(tester).scale, lessThan(1),
          reason: 'the new stage starts smaller than it ends');

      // §5.3: "plant scales up with slight overshoot". Sampled across the
      // spring's run, because the peak is somewhere in the middle of it.
      var peak = 0.0;
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        peak = peak > _pose(tester).scale ? peak : _pose(tester).scale;
      }

      expect(peak, greaterThan(1), reason: 'the spring is underdamped');
      expect(peak, lessThan(1.1), reason: 'and only slightly so');
    });

    testWidgets('is over in about the 1.2 seconds §5.3 allows it',
        (tester) async {
      final grow = await _plant(tester, _growth(0));
      await tester.pump(GrowingPlant.dropDuration);

      await grow(_growth(0.5));

      await tester.pump(const Duration(milliseconds: 200));
      expect(_pose(tester).scale, isNot(closeTo(1, 0.01)),
          reason: 'still moving a fifth of a second in');

      await tester.pump(const Duration(milliseconds: 1300));
      expect(_pose(tester).scale, closeTo(1, 0.01),
          reason: 'settled by 1.5 seconds');
    });

    testWidgets('a tick that changes nothing does not restart it',
        (tester) async {
      final grow = await _plant(tester, _growth(0.3));
      await tester.pump(GrowingPlant.dropDuration);

      // Progress moves every second; the stage does not. A spring that
      // restarted on every tick would leave the plant permanently twitching.
      await grow(_growth(0.31));
      await grow(_growth(0.32));

      expect(_pose(tester).scale, 1);
    });
  });

  group('the sway', () {
    testWidgets('only mature plants sway', (tester) async {
      final grow = await _plant(tester, _growth(0.5));
      await tester.pump(GrowingPlant.dropDuration);
      await tester.pump(const Duration(seconds: 2));

      expect(_pose(tester).lean, 0, reason: 'a young plant stands still');

      await grow(_growth(1));
      await tester.pump(const Duration(milliseconds: 500));

      expect(_pose(tester).lean, isNot(0));
    });

    testWidgets('eases into the sway rather than snapping into a lean',
        (tester) async {
      // The offset that keeps a garden from pulsing in unison puts each plant
      // at a different point in the sine, so at the instant one matures its
      // sine is already mid-swing. Without an ease-in the plant would jump
      // straight to that lean.
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);
      await grow(_growth(1));

      expect(_pose(tester).lean, 0, reason: 'upright at the moment it matures');

      var previous = 0.0;
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final lean = _pose(tester).lean.abs();
        expect(lean - previous, lessThan(PlantSway.amplitude / 4),
            reason: 'the lean should creep in, not jump');
        previous = lean;
      }
    });

    testWidgets('leans both ways, and no further than 2°', (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);
      await grow(_growth(1));

      var leftmost = 0.0;
      var rightmost = 0.0;
      for (var frame = 0; frame < 260; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final lean = _pose(tester).lean;
        leftmost = lean < leftmost ? lean : leftmost;
        rightmost = lean > rightmost ? lean : rightmost;
      }

      expect(rightmost, greaterThan(0));
      expect(leftmost, lessThan(0));
      expect(rightmost, lessThanOrEqualTo(PlantSway.amplitude));
      expect(leftmost, greaterThanOrEqualTo(-PlantSway.amplitude));
    });

    testWidgets('two plants do not sway in unison', (tester) async {
      // REQ-023. The offset comes from the session that grew the plant, so it
      // is the same on every launch and different between neighbours.
      final sessions = [
        for (var id = 1; id <= 4; id++)
          FocusSession(
            id: 'session-$id',
            startedAt: _session.startedAt,
            plannedDuration: const Duration(minutes: 25),
          ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Row(
                children: [
                  for (final session in sessions)
                    GrowingPlant(
                      growth: PlantGrowth.forSession(session, progress: 1),
                      size: 60,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final leans = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(GrowingPlant),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((paint) => (paint.painter! as PlantPainter).lean)
          .toSet();

      expect(leans, hasLength(sessions.length),
          reason: 'a garden of plants should not pulse together');
    });

    testWidgets('a plant stops swaying when a new seed replaces it',
        (tester) async {
      final grow = await _plant(tester, _growth(1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_pose(tester).lean, isNot(0));

      final next = FocusSession(
        id: 'session-2',
        startedAt: _session.startedAt,
        plannedDuration: const Duration(minutes: 25),
      );
      await grow(PlantGrowth.forSession(next, progress: 0));

      expect(_pose(tester).lean, 0);
    });
  });

  group('the bloom at the end of a session', () {
    testWidgets('throws petals as the session completes', (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);
      expect(_pose(tester).bloom, 0, reason: 'nothing has completed yet');

      await grow(_growth(1), completed: true);

      var last = 0.0;
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final bloom = _pose(tester).bloom;
        expect(bloom, greaterThanOrEqualTo(last),
            reason: 'petals go out and do not come back');
        last = bloom;
      }

      expect(last, greaterThan(0), reason: 'the bloom is under way');
      expect(last, lessThan(1), reason: 'and not over two-thirds of the way in');
    });

    testWidgets('is over in about the 2 seconds §5.3 allows it', (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);

      await grow(_growth(1), completed: true);
      await tester.pump(GrowingPlant.bloomDuration - _frame);
      expect(_pose(tester).bloom, lessThan(1), reason: 'still blooming');

      await tester.pump(_frame * 2);
      expect(_pose(tester).bloom, 1, reason: 'and done, two seconds in');
    });

    testWidgets('springs as well, so a plant already mature still blooms',
        (tester) async {
      // REQ-009's half-rate growth gets a long-enough pause to mature a plant
      // before its own countdown runs out, so the completion can arrive with
      // the stage transition already behind it. §5.3 asks for a spring either
      // way, and the bloom is what supplies it.
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);
      await grow(_growth(1));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(_pose(tester).scale, closeTo(1, 0.01),
          reason: 'the stage transition is over and done with');

      await grow(_growth(1), completed: true);

      var peak = 0.0;
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(_frame);
        peak = peak > _pose(tester).scale ? peak : _pose(tester).scale;
      }
      expect(peak, greaterThan(1), reason: 'the plant springs as it blooms');
      // Ninety frames is a second and a half — past the spring, and still
      // inside the two seconds of petals.
      expect(_pose(tester).bloom, greaterThan(0),
          reason: 'and the petals are flying');
    });

    testWidgets('plays once, not on every tick of a completed session',
        (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);

      await grow(_growth(1), completed: true);
      await tester.pump(GrowingPlant.bloomDuration + _frame);
      expect(_pose(tester).bloom, 1);

      // The screen rebuilds while a completed session sits there — the break
      // offer, the sessions-grown count, a tab coming back. None of it is a
      // second completion.
      await grow(_growth(1), completed: true);
      await tester.pump(_frame);

      expect(_pose(tester).bloom, 1, reason: 'the bloom is not restarted');
    });

    testWidgets('a session that is cancelled does not bloom',
        (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);

      // Cancelling clears the soil: the plant is not planted and nothing is
      // owed. A voided session arrives here identically.
      await grow(null);
      await tester.pump(GrowingPlant.bloomDuration);

      expect(_pose(tester).bloom, 0);
      expect(_pose(tester).sprite, isNull);
    });

    testWidgets('a session found complete rather than watched is not either',
        (tester) async {
      // The rule `SessionAnnouncer` applies to the chime: the user was told
      // when it happened. A bloom now would be a fuss made over an app being
      // opened.
      await _plant(tester, _growth(1), completed: true);
      await tester.pump(GrowingPlant.bloomDuration * 2);

      expect(_pose(tester).bloom, 0);
    });

    testWidgets('settles into the sway rather than ending and handing over',
        (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);
      await grow(_growth(1), completed: true);

      await tester.pump(GrowingPlant.bloomDuration ~/ 2);
      expect(_pose(tester).bloom, greaterThan(0), reason: 'mid-bloom');
      expect(_pose(tester).lean, isNot(0),
          reason: 'REQ-023 is already running underneath it');

      final midBloom = _pose(tester).lean;
      await tester.pump(GrowingPlant.bloomDuration);
      expect(_pose(tester).bloom, 1, reason: 'the petals are gone');
      expect(_pose(tester).lean, isNot(midBloom),
          reason: 'and the sway carries on without a seam');
    });

    group('a phone asking to be kept still', () {
      testWidgets('gets the mature plant and no petals at all', (tester) async {
        _keepStill(tester);

        final grow = await _plant(tester, _growth(0.9));
        await tester.pump(GrowingPlant.dropDuration);
        await grow(_growth(1), completed: true);

        for (var frame = 0; frame < 160; frame++) {
          await tester.pump(_frame);
          expect(_pose(tester).bloom, 0,
              reason: '§4.4: no bloom, and no still frame of one either');
        }

        expect(_pose(tester).sprite, isNotNull);
        expect(_pose(tester).scale, closeTo(1, 0.01),
            reason: 'the plant is at its full size, not a part-grown one');
      });

      testWidgets('ends a bloom that was already in flight', (tester) async {
        final grow = await _plant(tester, _growth(0.9));
        await tester.pump(GrowingPlant.dropDuration);
        await grow(_growth(1), completed: true);
        await tester.pump(GrowingPlant.bloomDuration ~/ 4);
        expect(_pose(tester).bloom, greaterThan(0));

        _keepStill(tester);
        await tester.pump();

        expect(_pose(tester).bloom, 0,
            reason: 'petals half way out are exactly what not to freeze');
      });
    });
  });

  group('the plant itself', () {
    testWidgets('is the sprite for its type and stage', (tester) async {
      final grow = await _plant(tester, _growth(0));

      expect(_pose(tester).sprite, isNotNull);
      final asSeed = _pose(tester).sprite;

      await grow(_growth(1));
      expect(_pose(tester).sprite, isNot(asSeed));
    });

    testWidgets('two species of the same type are drawn differently',
        (tester) async {
      // Until ticket 23's art arrives, species is a shift of the theme's own
      // green — but it is a visible one.
      final first = _growth(1);
      final other = [
        for (var id = 2; id < 20; id++)
          PlantGrowth.forSession(
            FocusSession(
              id: 'session-$id',
              startedAt: _session.startedAt,
              plannedDuration: const Duration(minutes: 25),
            ),
            progress: 1,
          ),
      ].firstWhere((growth) => growth.species != first.species);

      final grow = await _plant(tester, first);
      final firstPalette = _pose(tester).palette;

      await grow(other);
      expect(_pose(tester).palette, isNot(firstPalette));
    });
  });
}
