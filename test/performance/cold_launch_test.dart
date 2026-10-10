import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/garden_seed.dart';

/// PRD §4.4, ticket 24: **cold launch to a visible garden is under 1.5
/// seconds.**
///
/// **A workstation cannot measure a cold launch and this file does not pretend
/// to.** Half of that 1.5 seconds is the operating system: `fork`/`exec`,
/// linking the Flutter engine, the Dart isolate spinning up, the first
/// rasterised frame reaching the display. None of that happens under
/// `flutter test`, and none of it is this app's code. The device procedure is in
/// `docs/garden-performance-baseline.md`.
///
/// What *is* this app's code is the work between the engine being ready and the
/// garden being on screen: opening SQLite, reading the settings row, querying
/// the plants, laying out the plots and baking the texture. That is the half a
/// regression can land in, and it is the half measured here.
///
/// **The assertion that matters is not a millisecond count, it is a shape.**
/// A budget in milliseconds measured on a debug build on whatever box CI
/// happens to give us is worth very little. What is worth a great deal is that
/// launch cost does not *scale with the garden*: a user two years and four
/// hundred sessions in must launch as fast as one on their second day. A
/// launch that walked the plants, or built a widget per plot, or baked a cell
/// per plant, would pass a millisecond budget on an empty garden and fail the
/// user who has actually been using the app. That is what these tests are
/// built to catch, and it is catchable without a phone.

const Size _window = Size(400, 800);

/// How long the app's own launch work took, and what it had to show for it.
typedef _Launch = ({Duration took, int bakes});

/// Launches the app over [database] and stops the clock when the garden is on
/// screen with a painter holding its plants.
Future<_Launch> _launchToGarden(
  WidgetTester tester,
  AppDatabase database,
) async {
  var bakes = 0;
  final wasCreate = ui.Image.onCreate;
  ui.Image.onCreate = (_) => bakes++;

  final elapsed = Stopwatch()..start();
  try {
    await pumpApp(tester, database: database, surface: _window);
    await tapTab(tester, AppTab.garden);
  } finally {
    elapsed.stop();
    ui.Image.onCreate = wasCreate;
  }

  return (took: elapsed.elapsed, bakes: bakes);
}

/// The painter the garden tab is drawing with, which exists only once the
/// garden is genuinely on screen.
GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
    ))
    .painter! as GardenPainter;

void main() {
  group('the garden is on screen when the app says it is', () {
    testWidgets('a first launch opens on an empty garden with no plants',
        (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await _launchToGarden(tester, database);

      // Twelve plots of bare soil rather than a spinner: §5.3 opens on a
      // garden, and a garden with nothing in it is still a garden.
      expect(_painter(tester).layout.plants, isEmpty);
      expect(_painter(tester).layout.plotCount, 12);
    });

    testWidgets('and a full one opens with all two hundred', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: GardenPlots.maximum);

      await _launchToGarden(tester, database);
      await dismissCelebrations(tester);

      // The point being that the *first* garden frame is the real one. An app
      // that opened on an empty garden and filled it in a frame later would
      // satisfy a stopwatch and not the requirement.
      expect(_painter(tester).layout.plants, hasLength(200));
    });
  });

  group('launch does not get slower as the garden fills', () {
    testWidgets('two hundred plants cost no more launches than none',
        (tester) async {
      // The claim this file exists for. Both numbers are debug-build
      // workstation numbers and neither is a device launch; what is asserted is
      // the *ratio*, which is a property of the design rather than of the box.
      final empty = AppDatabase.forTesting();
      addTearDown(empty.close);
      final emptyLaunch = await _launchToGarden(tester, empty);
      await killApp(tester);

      final full = AppDatabase.forTesting();
      addTearDown(full.close);
      await seedGarden(full, sessions: GardenPlots.maximum);
      final fullLaunch = await _launchToGarden(tester, full);
      await dismissCelebrations(tester);

      debugPrint(
        'launch baseline | empty garden: ${emptyLaunch.took.inMilliseconds} ms, '
        '200 plants: ${fullLaunch.took.inMilliseconds} ms',
      );

      // Generous, because a debug widget-test launch is noisy and this is
      // running beside whatever else CI is doing. A launch that walked the
      // plants would be orders of magnitude out, not eighty per cent.
      expect(
        fullLaunch.took.inMicroseconds,
        lessThan(emptyLaunch.took.inMicroseconds * 3 + 500000),
        reason: 'launch is scaling with the number of plants',
      );
    });

    testWidgets('and the texture is baked once either way', (tester) async {
      // The atlas is the single most expensive thing on the launch path — see
      // `docs/garden-performance-baseline.md`, where it is the only
      // millisecond-scale row. It is baked from the *registry*, so its cost is
      // a function of how many species exist and not of how many plants the
      // user has grown. Two bakes on launch would double the expensive half of
      // the budget; a bake per plant would end the budget.
      final full = AppDatabase.forTesting();
      addTearDown(full.close);
      await seedGarden(full, sessions: GardenPlots.maximum);

      final launch = await _launchToGarden(tester, full);
      await dismissCelebrations(tester);

      expect(launch.bakes, 1);
    });
  });

  group('what the garden is drawn from on the first frame', () {
    testWidgets('is a texture, not a sprite per plant', (tester) async {
      // Restating the structural guarantee at the launch boundary: two hundred
      // plants and the ground under them are four hundred quads in one batch on
      // the very first frame, which is what makes that frame affordable at all.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: GardenPlots.maximum);

      await _launchToGarden(tester, database);
      await dismissCelebrations(tester);

      final batch = _painter(tester).batchFor(_window);
      expect(batch.transforms.length, batch.rects.length);
      expect(batch.transforms, isNotEmpty);
    });
  });
}
