import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/features/garden/garden_view.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/garden_projection.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

// The garden tab through the real app: drawing what's in the database,
// pan/zoom, keeping position across tabs, and the entry animation.

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is GardenPainter,
        skipOffstage: false,
      ),
    )
    .painter! as GardenPainter;

GardenProjection _camera(WidgetTester tester) => _painter(tester).projection;

/// Shows the garden with [sessions] completed sessions, a plant each.
Future<AppDatabase> _openGarden(WidgetTester tester, {int sessions = 0}) async {
  final database = AppDatabase.forTesting();
  addTearDown(database.close);
  await seedGarden(database, sessions: sessions);

  await pumpApp(tester, database: database, surface: const Size(400, 800));
  return database;
}

void main() {
  testWidgets('new user sees twelve empty plots', (tester) async {
    await _openGarden(tester);

    final layout = _painter(tester).layout;
    expect(layout.plotCount, 12);
    expect(layout.emptyPlots, 12);
    expect(
      find.text('Finish a session and your first plant goes in here.'),
      findsOneWidget,
    );
  });

  // Painted surface, so it needs its own semantics label.
  testWidgets('has a semantics label', (tester) async {
    await _openGarden(tester, sessions: 3);

    expect(find.bySemanticsLabel('Your garden: 3 plants in 12 plots.'),
        findsOneWidget);
  });

  testWidgets('labels an empty garden', (tester) async {
    await _openGarden(tester);

    expect(
      find.bySemanticsLabel(
          'Your garden: 12 plots of bare soil, nothing growing yet.'),
      findsOneWidget,
    );
  });

  testWidgets('shows every plant', (tester) async {
    await _openGarden(tester, sessions: 7);

    final layout = _painter(tester).layout;
    expect(layout.plants, hasLength(7));
    expect(layout.emptyPlots, 5);
    for (final plant in layout.plants) {
      expect(layout.plantIn(plant.plot!), plant);
    }
  });

  testWidgets('plants survive relaunch', (tester) async {
    final database = await _openGarden(tester, sessions: 4);
    final before = _painter(tester).layout;

    await killApp(tester);
    await pumpApp(tester, database: database, surface: const Size(400, 800));

    final after = _painter(tester).layout;
    expect(after.plants, before.plants);
    expect(
      after.plants.map((plant) => plant.plot),
      before.plants.map((plant) => plant.plot),
      reason: 'same plots',
    );
  });

  group('capacity', () {
    testWidgets('ten completed sessions unlock four more plots', (tester) async {
      await _openGarden(tester, sessions: 10);

      final layout = _painter(tester).layout;
      expect(layout.plotCount, 16);
      // 11 plants in 16 plots: ten from sessions plus the bonus plant for the
      // tenth, awarded on this launch.
      expect(layout.emptyPlots, 5, reason: 'five plots to fill next');
    });

    testWidgets('existing history gets earned plots', (tester) async {
      // Derived from the count: their first launch on this build is session 50.
      await _openGarden(tester, sessions: 50);

      // 50 session plants plus milestones at 10, 25 and 50. The schedule only
      // opens 32 plots, so the garden grows to fit.
      expect(_painter(tester).layout.plotCount, 53);
      expect(GardenPlots.unlockedAfter(50), 32);
    });

    testWidgets('full garden reports unplaced plants', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 202);

      await pumpApp(tester, database: database, surface: const Size(400, 800));

      final layout = _painter(tester).layout;
      expect(layout.plotCount, 200);
      // Two session plants past the cap and four bonus plants (10, 25, 50,
      // 100). All recorded, none placed.
      expect(layout.unplaced, hasLength(6));
      expect(
        find.text('Your garden is full. 6 more plants are waiting for space.'),
        findsOneWidget,
      );
    });
  });

  group('pan and zoom', () {
    /// Mostly full garden. On-screen size comes from the zoom.
    const grownGarden = 60;

    /// Pinches the garden open.
    ///
    /// Where the pinch lands is tested in garden_projection_test.dart;
    /// synthetic two-finger gestures drift the focal point, so this only checks
    /// a pinch reaches the camera.
    Future<void> pinchOpen(WidgetTester tester) async {
      final focus = tester.getCenter(find.byType(GardenView));
      final first = await tester.startGesture(focus - const Offset(30, 0));
      final second = await tester.startGesture(focus + const Offset(30, 0));

      for (var step = 0; step < 8; step++) {
        await first.moveBy(const Offset(-15, 0));
        await second.moveBy(const Offset(15, 0));
        await tester.pump();
      }

      await first.up();
      await second.up();
      await tester.pump();
    }

    testWidgets('a pinch zooms the garden in', (tester) async {
      await _openGarden(tester, sessions: grownGarden);
      final before = _camera(tester);

      await pinchOpen(tester);

      expect(_camera(tester).scale, greaterThan(before.scale));
      expect(
        _camera(tester).scale,
        lessThanOrEqualTo(GardenProjection.maximumScale),
      );
    });

    testWidgets('dragging moves the garden', (tester) async {
      await _openGarden(tester, sessions: grownGarden);
      // A garden that fits stays centred, so zoom in first.
      await pinchOpen(tester);
      final before = _camera(tester);

      await tester.drag(find.byType(GardenView), const Offset(-40, -25));
      await tester.pump();

      final after = _camera(tester);
      expect(after.pan, isNot(before.pan));
      expect(after.scale, before.scale, reason: 'a drag is not a zoom');
    });

    testWidgets('the garden cannot be dragged off the screen', (tester) async {
      await _openGarden(tester, sessions: grownGarden);
      await pinchOpen(tester);
      final window = tester.getSize(find.byType(GardenView));

      for (final fling in const [
        Offset(-3000, 0),
        Offset(3000, 0),
        Offset(0, -3000),
        Offset(0, 3000),
      ]) {
        await tester.drag(find.byType(GardenView), fling);
        await tester.pump();

        final camera = _camera(tester);
        final bounds = camera.boundsOf(_painter(tester).layout.plots);
        expect(
          bounds.overlaps(Offset.zero & window),
          isTrue,
          reason: 'dragged $fling and the garden left the screen',
        );
        expect(
          _painter(tester).batchFor(window).transforms,
          isNotEmpty,
          reason: 'dragged $fling and nothing was drawn',
        );
      }
    });

    testWidgets('small garden stays centred', (tester) async {
      await _openGarden(tester);
      final centred = _camera(tester);

      await tester.drag(find.byType(GardenView), const Offset(-2000, -2000));
      await tester.pump();

      expect(_camera(tester), centred,
          reason: 'stays centred');
    });

    testWidgets('keeps the view across tab switches', (tester) async {
      await _openGarden(tester, sessions: grownGarden);

      await pinchOpen(tester);
      await tester.drag(find.byType(GardenView), const Offset(-50, -30));
      await tester.pump();
      final moved = _camera(tester);

      await tapTab(tester, AppTab.timer);
      await tapTab(tester, AppTab.garden);

      expect(_camera(tester), moved);
    });
  });

  group('entry', () {
    /// The entry fade and scale animations.
    ({Animation<double> fade, Animation<double> grow}) entry(
      WidgetTester tester,
    ) =>
        (
          fade: tester
              .widget<FadeTransition>(find.descendant(
                of: find.byType(GardenView, skipOffstage: false),
                matching: find.byType(FadeTransition, skipOffstage: false),
              ))
              .opacity,
          grow: tester
              .widget<ScaleTransition>(find.descendant(
                of: find.byType(GardenView, skipOffstage: false),
                matching: find.byType(ScaleTransition, skipOffstage: false),
              ))
              .scale,
        );

    testWidgets('fades and scales in on launch', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 6);

      await pumpApp(tester, database: database, surface: const Size(400, 800));

      final settled = entry(tester);
      expect(settled.fade.value, 1);
      expect(settled.grow.value, 1);
    });

    testWidgets('and on returning to the tab', (tester) async {
      await _openGarden(tester, sessions: 6);

      await tapTab(tester, AppTab.timer);
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(AppTab.garden.label),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final starting = entry(tester);
      expect(starting.fade.value, lessThan(0.5),
          reason: 'fades in');
      expect(starting.grow.value, lessThan(1));
      expect(starting.grow.value, greaterThanOrEqualTo(GardenView.entryScale));

      await tester.pump(GardenView.entryDuration);
      final settled = entry(tester);
      expect(settled.fade.value, 1);
      expect(settled.grow.value, 1);
    });
  });

  testWidgets('finished session appears in the garden', (tester) async {
    // End to end: timer completes, garden refreshes, plant is in the middle.
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final clock = FixedClock(testInstant);

    await pumpApp(tester, clock: clock, database: database);
    expect(_painter(tester).layout.plants, isEmpty);

    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
    await tapTab(tester, AppTab.garden);

    final layout = _painter(tester).layout;
    expect(layout.plants, hasLength(1));
    expect(layout.plants.single.plot, GardenPlots.inPlacementOrder.first);
    expect(await DriftPlantRepository(database).plants(), hasLength(1));
    expect(
      (await DriftSessionRepository(database).completedSessions()),
      hasLength(1),
    );
  });
}
