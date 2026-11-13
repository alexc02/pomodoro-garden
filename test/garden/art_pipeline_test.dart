import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/garden/art_bundle.dart';
import 'package:pip_garden/src/garden/art_gate.dart';
import 'package:pip_garden/src/garden/art_providers.dart';
import 'package:pip_garden/src/garden/decor_providers.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/image_sprites.dart';
import 'package:pip_garden/src/garden/placeholder_decor_sprites.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_providers.dart';
import 'package:pip_garden/src/shell/app_shell.dart';
import 'package:pip_garden/src/shell/opening_frame.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/celebrations.dart';
import '../support/garden_seed.dart';

// Runs the real app with the art set loaded (everything else uses the
// placeholder shapes). Checks that atlas, batching, hit-testing, timer screen
// and gates behave the same with decoded PNGs.

const Size _window = Size(400, 800);

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
    ))
    .painter! as GardenPainter;

T _read<T>(WidgetTester tester, Provider<T> provider) =>
    ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    ).read(provider);

void main() {
  group('with the art set loaded', () {
    testWidgets('uses image registries', (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 3);

      await pumpApp(
        tester,
        database: database,
        surface: _window,
        withArt: true,
      );

      expect(
        _read(tester, plantSpriteRegistryProvider),
        isA<ImagePlantSpriteRegistry>(),
      );
      expect(
        _read(tester, decorSpriteRegistryProvider),
        isA<ImageDecorSpriteRegistry>(),
      );
    });

    testWidgets('garden is one batch', (tester) async {
      // 200 plants plus ground is still 400 quads from one texture.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: GardenPlots.maximum);

      await pumpApp(
        tester,
        database: database,
        surface: _window,
        withArt: true,
      );
      await dismissCelebrations(tester);
      await tapTab(tester, AppTab.garden);

      final batch = _painter(tester).batchFor(const Size(4000, 4000));
      expect(batch.transforms, hasLength(400));
      expect(batch.rects, hasLength(400));
    });

    testWidgets('every plant has a footprint', (tester) async {
      // For drawings the hit-test uses the manifest footprint.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await seedGarden(database, sessions: 3);

      await pumpApp(
        tester,
        database: database,
        surface: _window,
        withArt: true,
      );

      final registry = _read(tester, plantSpriteRegistryProvider);
      const box = Rect.fromLTWH(0, 0, 100, 100);

      for (final form in PlantForm.values) {
        for (final stage in GrowthStage.values) {
          final footprint =
              registry.spriteFor(form: form, stage: stage).footprintIn(box);

          expect(footprint.isEmpty, isFalse,
              reason: '${form.name}/${stage.name} claims to fill nothing');
          expect(footprint.width, lessThanOrEqualTo(box.width + 0.01),
              reason: '${form.name}/${stage.name} claims to overflow its box');
        }
      }
    });

    testWidgets('a session grows a plant on the timer screen', (tester) async {
      // The timer paints one plant via PlantPainter, not the atlas.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final clock = FixedClock(DateTime.utc(2026, 8, 28, 9));

      await pumpApp(
        tester,
        database: database,
        clock: clock,
        surface: _window,
        withArt: true,
      );

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 12));

      expect(find.text('Pause'), findsOne);
      expect(
        _read(tester, plantSpriteRegistryProvider),
        isA<ImagePlantSpriteRegistry>(),
      );
    });
  });

  group('the gate', () {
    testWidgets('waits for the art to decode', (tester) async {
      // Behind the gate every sprite lookup is synchronous, so the atlas can
      // bake with toImageSync and there's never a frame without a texture.
      final ready = Completer<ArtBundle?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            artBundleProvider.overrideWith((ref) => ready.future),
          ],
          child: const MaterialApp(home: ArtGate(child: Text('the app'))),
        ),
      );

      expect(find.byType(OpeningFrame), findsOne);
      expect(find.text('the app'), findsNothing);

      ready.complete(null);
      await tester.pump();

      expect(find.text('the app'), findsOne);
    });

    testWidgets('falls back to placeholders with no art', (tester) async {
      // Valid state: a build can be made before the art lands.
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await pumpApp(tester, database: database, surface: _window);

      expect(
        _read(tester, plantSpriteRegistryProvider),
        isA<PlaceholderPlantSpriteRegistry>(),
      );
      expect(
        _read(tester, decorSpriteRegistryProvider),
        isA<PlaceholderDecorSpriteRegistry>(),
      );
      expect(find.byType(NavigationBar), findsOne,
          reason: 'the app opened anyway');
    });

    // Not tested: ArtGate's error report and artBundleProvider refusing a bad
    // manifest. Both need a provider failing asynchronously in testWidgets, and
    // Riverpod lets that error reach the zone, which fails the test before any
    // expect runs (tried completers, throwing bodies, FlutterError.onError,
    // takeException). The throwing itself is covered in art_bundle_test.dart.
  });
}
