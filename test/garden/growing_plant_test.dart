import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/theme.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/garden/plant_painter.dart';
import 'package:pip_garden/src/garden/plant_sway.dart';

// The four plant animations, checked via the painter's pose rather than
// pixels.

const double _size = 200;

/// One 60Hz frame.
const Duration _frame = Duration(milliseconds: 16);

final _session = FocusSession(
  id: 'session-1',
  startedAt: DateTime.utc(2026, 8, 11, 9, 41),
  plannedDuration: const Duration(minutes: 25),
);

PlantGrowth _growth(double progress) =>
    PlantGrowth.forSession(_session, progress: progress);

PlantPainter _pose(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(GrowingPlant),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter! as PlantPainter;

/// Changes what the plant is growing and whether its session completed.
typedef _Grow = Future<void> Function(PlantGrowth? growth, {bool completed});

/// Shows one plant and returns a way to change it.
///
/// [completed] is the starting state: a plant that starts complete was found,
/// not watched, so it doesn't bloom.
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

/// Turns on the platform reduce-motion setting for the rest of the test.
/// Set on the platform rather than a MediaQuery, since that's where it really
/// comes from.
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
          reason: 'falling');

      await tester.pump(GrowingPlant.dropDuration);
      expect(_pose(tester).drop, 0, reason: 'landed');
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
    testWidgets('overshoots and settles', (tester) async {
      final grow = await _plant(tester, _growth(0));
      await tester.pump(GrowingPlant.dropDuration);
      expect(_pose(tester).scale, 1, reason: 'a settled plant is at its size');

      await grow(_growth(0.2));
      expect(_pose(tester).scale, lessThan(1),
          reason: 'the new stage starts smaller than it ends');

      // Sample across the spring; the peak is somewhere in the middle.
      var peak = 0.0;
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        peak = peak > _pose(tester).scale ? peak : _pose(tester).scale;
      }

      expect(peak, greaterThan(1), reason: 'the spring is underdamped');
      expect(peak, lessThan(1.1), reason: 'only slightly');
    });

    testWidgets('finishes in about 1.2 seconds', (tester) async {
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

    testWidgets('no-op tick does not restart it', (tester) async {
      final grow = await _plant(tester, _growth(0.3));
      await tester.pump(GrowingPlant.dropDuration);

      // Progress ticks every second but the stage doesn't. Restarting on every
      // tick would make the plant twitch.
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

    testWidgets('eases into the sway', (tester) async {
      // Each plant has its own phase, so it's already mid-swing when it
      // matures. Without an ease-in it would jump to that lean.
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

    testWidgets('leans both ways, max 2°', (tester) async {
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
      // Phase comes from the session id: stable across launches, different per
      // neighbour.
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

    testWidgets('stops swaying when replaced by a seed', (tester) async {
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

  group('bloom', () {
    testWidgets('throws petals on completion', (tester) async {
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
      expect(last, lessThan(1), reason: 'not finished two-thirds in');
    });

    testWidgets('finishes in about 2 seconds', (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);

      await grow(_growth(1), completed: true);
      await tester.pump(GrowingPlant.bloomDuration - _frame);
      expect(_pose(tester).bloom, lessThan(1), reason: 'still blooming');

      await tester.pump(_frame * 2);
      expect(_pose(tester).bloom, 1, reason: 'done at two seconds');
    });

    testWidgets('springs even if already mature', (tester) async {
      // With half-rate growth during a pause, a plant can mature before the
      // session ends, so the bloom supplies the spring.
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
      // 90 frames = 1.5s, past the spring, still within the petals.
      expect(_pose(tester).bloom, greaterThan(0),
          reason: 'petals still out');
    });

    testWidgets('plays once', (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);

      await grow(_growth(1), completed: true);
      await tester.pump(GrowingPlant.bloomDuration + _frame);
      expect(_pose(tester).bloom, 1);

      // The screen rebuilds while completed (break offer, count, tab return).
      // None of that is a second completion.
      await grow(_growth(1), completed: true);
      await tester.pump(_frame);

      expect(_pose(tester).bloom, 1, reason: 'the bloom is not restarted');
    });

    testWidgets('no bloom on cancel', (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);

      // Cancelling clears the soil. Voided sessions look the same here.
      await grow(null);
      await tester.pump(GrowingPlant.bloomDuration);

      expect(_pose(tester).bloom, 0);
      expect(_pose(tester).sprite, isNull);
    });

    testWidgets('no bloom when found complete', (tester) async {
      // Same rule as SessionAnnouncer: the user was already told.
      await _plant(tester, _growth(1), completed: true);
      await tester.pump(GrowingPlant.bloomDuration * 2);

      expect(_pose(tester).bloom, 0);
    });

    testWidgets('hands off to the sway seamlessly', (tester) async {
      final grow = await _plant(tester, _growth(0.9));
      await tester.pump(GrowingPlant.dropDuration);
      await grow(_growth(1), completed: true);

      await tester.pump(GrowingPlant.bloomDuration ~/ 2);
      expect(_pose(tester).bloom, greaterThan(0), reason: 'mid-bloom');
      expect(_pose(tester).lean, isNot(0),
          reason: 'sway already running');

      final midBloom = _pose(tester).lean;
      await tester.pump(GrowingPlant.bloomDuration);
      expect(_pose(tester).bloom, 1, reason: 'the petals are gone');
      expect(_pose(tester).lean, isNot(midBloom),
          reason: 'sway continues seamlessly');
    });

    group('reduce motion', () {
      testWidgets('shows the mature plant with no petals', (tester) async {
        _keepStill(tester);

        final grow = await _plant(tester, _growth(0.9));
        await tester.pump(GrowingPlant.dropDuration);
        await grow(_growth(1), completed: true);

        for (var frame = 0; frame < 160; frame++) {
          await tester.pump(_frame);
          expect(_pose(tester).bloom, 0,
              reason: 'no bloom with reduce motion');
        }

        expect(_pose(tester).sprite, isNotNull);
        expect(_pose(tester).scale, closeTo(1, 0.01),
            reason: 'the plant is at its full size, not a part-grown one');
      });

      testWidgets('ends an in-flight bloom', (tester) async {
        final grow = await _plant(tester, _growth(0.9));
        await tester.pump(GrowingPlant.dropDuration);
        await grow(_growth(1), completed: true);
        await tester.pump(GrowingPlant.bloomDuration ~/ 4);
        expect(_pose(tester).bloom, greaterThan(0));

        _keepStill(tester);
        await tester.pump();

        expect(_pose(tester).bloom, 0,
            reason: 'must not freeze mid-bloom');
      });
    });
  });

  group('sprite', () {
    testWidgets('uses the sprite for its type and stage', (tester) async {
      final grow = await _plant(tester, _growth(0));

      expect(_pose(tester).sprite, isNotNull);
      final asSeed = _pose(tester).sprite;

      await grow(_growth(1));
      expect(_pose(tester).sprite, isNot(asSeed));
    });

    testWidgets('same type, different species look different', (tester) async {
      // Until the art arrives, species is a visible shift of the theme green.
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
