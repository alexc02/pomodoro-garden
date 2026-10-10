import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/design/theme.dart';
import 'package:pomodoro_garden/src/garden/growing_plant.dart';

/// The one boundary the plant is captured from — the tree has several.
const Key _plantBoundary = Key('plant');

/// One codebase, two platforms, and a garden that has to look the same in both.
///
/// The plant is drawn with `Canvas` operations rather than with anything
/// Material or Cupertino, so parity is a property of the code rather than
/// something that has to be maintained — but "is a property of the code" is
/// exactly the kind of claim that quietly stops being true. This renders the
/// real widget under each platform and compares the pixels.
void main() {
  final anchor = DateTime.utc(2026, 8, 11, 9, 41);

  /// Renders one plant under [platform] and returns its pixels.
  Future<Uint8List> render(
    WidgetTester tester, {
    required TargetPlatform platform,
    required Duration sessionLength,
    required double progress,
    Brightness brightness = Brightness.light,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final growth = PlantGrowth.forSession(
      FocusSession(
        id: 'session-1',
        startedAt: anchor,
        plannedDuration: sessionLength,
      ),
      progress: progress,
    );

    // A fresh tree each time. Pumping over the last one would keep its
    // animation state, and a mature plant's sway would be at a different point
    // in its loop for the second platform than it was for the first — a
    // difference in the test, not in the code.
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light
              : AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: _plantBoundary,
                child: GrowingPlant(growth: growth, size: 160),
              ),
            ),
          ),
        ),
      ),
    );
    // Past the seed drop and any stage spring, so what is compared is the plant
    // at rest rather than two animations sampled a frame apart.
    await tester.pump(const Duration(seconds: 2));

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(_plantBoundary));
    // Through `runAsync`: rasterising is real asynchronous work on the engine,
    // and the fake clock a widget test runs under never lets it finish.
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });

    debugDefaultTargetPlatformOverride = null;
    return pixels!;
  }

  for (final (name, length) in const <(String, Duration)>[
    ('a wildflower', Duration(minutes: 10)),
    ('a herb', Duration(minutes: 20)),
    ('a flower', Duration(minutes: 30)),
    ('a bush', Duration(minutes: 40)),
    ('a small tree', Duration(minutes: 60)),
    ('a large tree', Duration(minutes: 100)),
  ]) {
    testWidgets('$name renders identically on iOS and Android',
        (tester) async {
      for (final progress in const [0.0, 0.2, 0.5, 0.8, 1.0]) {
        final onIOS = await render(
          tester,
          platform: TargetPlatform.iOS,
          sessionLength: length,
          progress: progress,
        );
        final onAndroid = await render(
          tester,
          platform: TargetPlatform.android,
          sessionLength: length,
          progress: progress,
        );

        expect(onAndroid, onIOS,
            reason: '$name differs between platforms at $progress progress');
      }
    });
  }

  testWidgets('and identically in dark mode too', (tester) async {
    // The garden's own colours do not change with the UI brightness — see
    // GardenColors.dark — so a plant is the same plant at night, on either
    // platform.
    final onIOS = await render(
      tester,
      platform: TargetPlatform.iOS,
      sessionLength: const Duration(minutes: 30),
      progress: 1,
      brightness: Brightness.dark,
    );
    final onAndroid = await render(
      tester,
      platform: TargetPlatform.android,
      sessionLength: const Duration(minutes: 30),
      progress: 1,
      brightness: Brightness.dark,
    );

    expect(onAndroid, onIOS);
  });

}
