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

/// The garden tab, driven through the real app.
///
/// What is under test here is everything that is not arithmetic: that the
/// garden the database holds is the garden that gets drawn, that dragging and
/// pinching move it and cannot lose it, that it is where the user left it when
/// they come back, and §5.3's entry.

/// The painter currently on the garden tab — the whole of what is being drawn,
/// including which camera it is being drawn from.
GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is GardenPainter,
        skipOffstage: false,
      ),
    )
    .painter! as GardenPainter;

GardenProjection _camera(WidgetTester tester) => _painter(tester).projection;

/// Puts the garden on screen, with [sessions] completed sessions and a plant
/// for each behind it.
Future<AppDatabase> _openGarden(WidgetTester tester, {int sessions = 0}) async {
  final database = AppDatabase.forTesting();
  addTearDown(database.close);
  await seedGarden(database, sessions: sessions);

  await pumpApp(tester, database: database, surface: const Size(400, 800));
  return database;
}

void main() {
  testWidgets('a new user opens on twelve plots of bare soil', (tester) async {
    // US-002: something to build towards, on the very first launch.
    await _openGarden(tester);

    final layout = _painter(tester).layout;
    expect(layout.plotCount, 12);
    expect(layout.emptyPlots, 12);
    expect(
      find.text('Finish a session and your first plant goes in here.'),
      findsOneWidget,
    );
  });

  // A painted surface has no widgets for a screen reader to walk, so it has to
  // say what it holds itself.
  testWidgets('the garden says what it holds, for a reader that cannot see it',
      (tester) async {
    await _openGarden(tester, sessions: 3);

    expect(find.bySemanticsLabel('Your garden: 3 plants in 12 plots.'),
        findsOneWidget);
  });

  testWidgets('and says that it is empty rather than saying nothing',
      (tester) async {
    await _openGarden(tester);

    expect(
      find.bySemanticsLabel(
          'Your garden: 12 plots of bare soil, nothing growing yet.'),
      findsOneWidget,
    );
  });

  testWidgets('every plant the user has grown is in the garden', (tester) async {
    await _openGarden(tester, sessions: 7);

    final layout = _painter(tester).layout;
    expect(layout.plants, hasLength(7));
    expect(layout.emptyPlots, 5);
    for (final plant in layout.plants) {
      expect(layout.plantIn(plant.plot!), plant);
    }
  });

  testWidgets('the plants are still there after a relaunch', (tester) async {
    // The product's whole premise, through the screen this time rather than
    // through the repository.
    final database = await _openGarden(tester, sessions: 4);
    final before = _painter(tester).layout;

    await killApp(tester);
    await pumpApp(tester, database: database, surface: const Size(400, 800));

    final after = _painter(tester).layout;
    expect(after.plants, before.plants);
    expect(
      after.plants.map((plant) => plant.plot),
      before.plants.map((plant) => plant.plot),
      reason: 'and standing in the same plots, not merely present',
    );
  });

  group('capacity', () {
    testWidgets('ten completed sessions unlock four more plots', (tester) async {
      await _openGarden(tester, sessions: 10);

      final layout = _painter(tester).layout;
      expect(layout.plotCount, 16);
      // Eleven plants in sixteen plots: ten the sessions grew, and REQ-021's
      // bonus plant for the tenth, which is awarded on this very launch and
      // takes a plot like anything else in the ground.
      expect(layout.emptyPlots, 5, reason: 'five plots to fill next');
    });

    testWidgets('a user who arrives with a history gets the plots they earned',
        (tester) async {
      // Derived from the count, not counted up from twelve: this user's first
      // launch on this build is their fiftieth session, not their first.
      await _openGarden(tester, sessions: 50);

      // Fifty session plants plus the three milestones fifty sessions have
      // reached — ten, twenty-five and fifty. The unlock schedule only opens
      // thirty-two plots, so this is the garden growing to hold what is planted
      // in it rather than the schedule deciding how big it is: ADR 0006.
      expect(_painter(tester).layout.plotCount, 53);
      expect(GardenPlots.unlockedAfter(50), 32);
    });

    testWidgets('a full garden says what it is holding', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 202);

      await pumpApp(tester, database: database, surface: const Size(400, 800));

      final layout = _painter(tester).layout;
      expect(layout.plotCount, 200);
      // The two session plants past the cap, and the four bonus plants two
      // hundred sessions have earned — ten, twenty-five, fifty and a hundred.
      // Every one of them is recorded and counted; none is standing anywhere.
      expect(layout.unplaced, hasLength(6));
      expect(
        find.text('Your garden is full. 6 more plants are waiting for space.'),
        findsOneWidget,
      );
    });
  });

  group('pan and zoom', () {
    /// A garden with something in most of its plots. How big it is on screen
    /// is decided by the zoom, not by this.
    const grownGarden = 60;

    /// Pinches the garden open.
    ///
    /// Where the pinch *lands* is [GardenProjection]'s business and is tested
    /// as arithmetic in `garden_projection_test.dart`, which can put the focal
    /// point exactly where it means to. A synthesised two-finger gesture cannot
    /// — the fingers move one at a time, so the focal point drifts between them
    /// — so what is asserted here is the half this layer owns: that a pinch
    /// reaches the camera at all.
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
      // A garden that fits on the screen is centred and stays centred — there
      // is nowhere to drag it to. Zoom in first, so there is.
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
          reason: 'dragged $fling and the garden left the screen entirely',
        );
        expect(
          _painter(tester).batchFor(window).transforms,
          isNotEmpty,
          reason: 'dragged $fling and there was nothing left to draw',
        );
      }
    });

    testWidgets('a garden smaller than the screen stays in the middle of it',
        (tester) async {
      await _openGarden(tester);
      final centred = _camera(tester);

      await tester.drag(find.byType(GardenView), const Offset(-2000, -2000));
      await tester.pump();

      expect(_camera(tester), centred,
          reason: 'twelve plots cannot be flung into a corner');
    });

    testWidgets('the view is where it was left when the tab comes back',
        (tester) async {
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
    /// §5.3's fade and scale, as the two animations driving them.
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

    testWidgets('the garden fades and scales in on launch', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 6);

      await pumpApp(tester, database: database, surface: const Size(400, 800));

      final settled = entry(tester);
      expect(settled.fade.value, 1);
      expect(settled.grow.value, 1);
    });

    testWidgets('and again every time the tab is returned to', (tester) async {
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
          reason: '§5.3: a gentle fade in, not an appearance');
      expect(starting.grow.value, lessThan(1));
      expect(starting.grow.value, greaterThanOrEqualTo(GardenView.entryScale));

      await tester.pump(GardenView.entryDuration);
      final settled = entry(tester);
      expect(settled.fade.value, 1);
      expect(settled.grow.value, 1);
    });
  });

  testWidgets('finishing a session puts its plant in the garden',
      (tester) async {
    // End to end: the timer completes, the garden refreshes on its own, and the
    // plant is standing in the middle of it.
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
