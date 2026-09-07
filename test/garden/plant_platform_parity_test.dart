import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/theme.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';

/// The boundary the plant is captured from (there are several).
const Key _plantBoundary = Key('plant');

// The plant is drawn with Canvas only, so it should render the same on iOS
// and Android. Compare the pixels to make sure.
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

    // Fresh tree each time, otherwise the sway phase carries over between
    // platforms.
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
    // Past the seed drop and stage spring.
    await tester.pump(const Duration(seconds: 2));

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(_plantBoundary));
    // runAsync: rasterising is real async work that fake time never finishes.
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

  testWidgets('identical in dark mode', (tester) async {
    // Garden colours don't follow UI brightness (see GardenColors.dark).
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
