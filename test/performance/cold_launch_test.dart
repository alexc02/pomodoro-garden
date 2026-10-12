import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/garden_seed.dart';

// Cold launch to a visible garden should be under 1.5 s. A workstation can't
// measure that (half of it is the OS and engine startup). What's measured here is the app's
// own part: open SQLite, read settings and plants, lay out, bake the texture.
//
// The real assertion is that launch cost doesn't scale with the garden size.
// A millisecond budget on a debug CI box isn't worth much.

const Size _window = Size(400, 800);

typedef _Launch = ({Duration took, int bakes});

/// Launches over [database] and stops the clock once the garden painter is
/// up.
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

      // Twelve plots of bare soil, not a spinner.
      expect(_painter(tester).layout.plants, isEmpty);
      expect(_painter(tester).layout.plotCount, 12);
    });

    testWidgets('and a full one opens with all two hundred', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: GardenPlots.maximum);

      await _launchToGarden(tester, database);
      await dismissCelebrations(tester);

      // The first garden frame has to be the full one, not filled in later.
      expect(_painter(tester).layout.plants, hasLength(200));
    });
  });

  group('launch does not get slower as the garden fills', () {
    testWidgets('two hundred plants cost no more launches than none',
        (tester) async {
      // Debug workstation numbers, so assert the ratio, not the absolute time.
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

      // Generous because debug launches are noisy. A launch that walked the
      // plants would be orders of magnitude off.
      expect(
        fullLaunch.took.inMicroseconds,
        lessThan(emptyLaunch.took.inMicroseconds * 3 + 500000),
        reason: 'launch is scaling with the number of plants',
      );
    });

    testWidgets('and the texture is baked once either way', (tester) async {
      // The atlas bake is the most expensive step on launch. It's baked from
      // the registry, so it shouldn't depend on how many plants there are.
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
      // 200 plants plus ground is one batch of quads on the first frame.
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
