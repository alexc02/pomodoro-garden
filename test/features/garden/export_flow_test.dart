import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/export/garden_exporter.dart';
import 'package:pip_garden/src/export/garden_share.dart';
import 'package:pip_garden/src/features/garden/export_garden.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/garden/decor_providers.dart';
import 'package:pip_garden/src/garden/garden_atlas_recipe.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/garden/plant_providers.dart';
import 'package:pip_garden/src/garden/theme_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';
import '../../support/celebrations.dart';
import '../../support/event_log.dart';
import '../../support/garden_seed.dart';
import '../../support/garden_share_fake.dart';

// Export flow through the real app, from both entry points. The image itself
// is checked in test/garden/garden_export_test.dart.

GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GardenPainter,
      skipOffstage: false,
    ))
    .painter! as GardenPainter;

void main() {
  late AppDatabase database;
  late FakeGardenShare share;

  setUp(() {
    database = AppDatabase.forTesting();
    share = FakeGardenShare();
    addTearDown(database.close);
  });

  /// Opens the garden tab with [sessions] plants.
  ///
  /// Dismisses the milestone celebration first; its sheet would cover the app
  /// bar.
  Future<void> openGarden(
    WidgetTester tester, {
    int sessions = 12,
    GardenShare? share_,
  }) async {
    await seedGarden(database, sessions: sessions);

    await pumpApp(
      tester,
      database: database,
      gardenShare: share_ ?? share,
      surface: const Size(500, 900),
    );
    await dismissCelebrations(tester);
    await tapTab(tester, AppTab.garden);
  }

  /// Same, then goes to settings.
  Future<void> openSettings(
    WidgetTester tester, {
    int sessions = 12,
  }) async {
    await openGarden(tester, sessions: sessions);
    await tapTab(tester, AppTab.settings);
  }

  group('garden entry point', () {
    testWidgets('is always available', (tester) async {
      // Not gated: every export is a full export.
      await openGarden(tester);

      expect(find.byKey(ExportKeys.action), findsOneWidget);
    });

    testWidgets('shares a PNG', (tester) async {
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      expect(share.shared, hasLength(1));
      expect(share.last.png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(share.last.width, greaterThan(0));
      expect(share.last.filename, 'pip-garden.png');
    });

    testWidgets('image covers the whole garden', (tester) async {
      // The app is 500x900 and the image is much bigger in both directions, so
      // it was fitted to the garden, not captured from the viewport.
      await openGarden(tester, sessions: 200);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      expect(share.last.width, greaterThan(500));
      expect(share.last.height, greaterThan(900));
    });
  });

  group('settings entry point', () {
    testWidgets('exports the garden', (tester) async {
      await openSettings(tester);

      await tester.tap(await scrollToSetting(tester, ExportKeys.setting));
      await settleExport(tester);

      expect(share.shared, hasLength(1));
      expect(share.last.png, isNotEmpty);
    });

    testWidgets('matches the garden tab export', (tester) async {
      // Settings has no garden skin above it, so this checks the export derives
      // its own colours. Byte-for-byte equal from both entry points.
      await openGarden(tester, sessions: 30);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(tester, ExportKeys.setting));
      await settleExport(tester);

      expect(share.shared, hasLength(2));
      expect(share.shared[0].png, share.shared[1].png);
    });

    testWidgets('uses the same texture as the screen', (tester) async {
      // Both callers use one recipe, so a season/theme/decor change that
      // reached only one would show up as two signatures.
      await openGarden(tester);
      final onScreen = _painter(tester).atlas.signature;

      // Same as exportGarden does, from a context outside the garden skin.
      await tapTab(tester, AppTab.settings);
      final context = tester.element(find.byType(SettingsScreen));
      final container = ProviderScope.containerOf(context);
      final forExport = gardenAtlasRecipe(
        colours: container
            .read(gardenSkinProvider)
            .applyTo(GardenColors.of(context)),
        registry: container.read(plantSpriteRegistryProvider),
        decorRegistry: container.read(decorSpriteRegistryProvider),
      );

      expect(forExport, onScreen);
    });
  });

  group('settings copy', () {
    testWidgets('describes the export with no caveat', (tester) async {
      // No watermark caveat any more. See ADR 0005
      await openSettings(tester);
      await scrollToSetting(tester, ExportKeys.setting);

      expect(find.textContaining('at full size'), findsOneWidget);
      expect(find.textContaining('mark in the corner'), findsNothing);
    });
  });

  group('in progress', () {
    testWidgets('shows progress and ignores a second tap', (tester) async {
      // Hold the share sheet open to catch the in-progress state.
      final held = _HeldGardenShare();
      await openGarden(tester, sessions: 200, share_: held);

      await tester.tap(find.byKey(ExportKeys.action));
      await tester.pump();

      // State is set before the first await, so it shows on the next frame.
      expect(find.byKey(ExportKeys.progress), findsOneWidget);
      expect(find.byKey(ExportKeys.action), findsNothing);

      await settleExport(tester);
      expect(held.shared, hasLength(1), reason: 'one tap, one export');
      expect(
        find.byKey(ExportKeys.progress),
        findsOneWidget,
        reason: 'share still pending',
      );

      held.release();
      await settleExport(tester);

      expect(find.byKey(ExportKeys.progress), findsNothing);
      expect(find.byKey(ExportKeys.action), findsOneWidget);
      expect(held.shared, hasLength(1), reason: 'still one export');
    });

    testWidgets('does not block the UI', (tester) async {
      // Raster and PNG encode run off the Dart thread, so frames keep coming.
      final held = _HeldGardenShare();
      await openGarden(tester, sessions: 200, share_: held);

      await tester.tap(find.byKey(ExportKeys.action));
      await tester.pump();

      await tapTab(tester, AppTab.timer);
      expect(find.text('Plant it'), findsOneWidget);

      // The export belongs to the app, so leaving the tab doesn't cancel it.
      await settleExport(tester);
      held.release();
      await settleExport(tester);
      expect(held.shared, hasLength(1));
    });
  });

  group('on failure', () {
    testWidgets('shows an error', (tester) async {
      share.outcome = ShareOutcome.unavailable;
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      expect(find.byKey(ExportKeys.failure), findsOneWidget);
      expect(find.byKey(ExportKeys.progress), findsNothing);
      expect(find.byKey(ExportKeys.action), findsOneWidget);
    });

    testWidgets('can retry', (tester) async {
      share.outcome = ShareOutcome.unavailable;
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      share.outcome = ShareOutcome.shared;
      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      expect(share.shared, hasLength(2));
    });
  });

  group('garden_exported', () {
    // Read from the real log, not a fake port, so the DB wiring is covered.

    testWidgets('recorded once the sheet is up, no params', (tester) async {
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      final event = await theEventNamed(
        database,
        AnalyticsEventName.gardenExported,
      );
      expect(event.parameters, isEmpty);
    });

    testWidgets('not recorded when sharing fails', (tester) async {
      // Only count exports that actually happened.
      share.outcome = ShareOutcome.unavailable;
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      expect(
        await eventsNamed(database, AnalyticsEventName.gardenExported),
        isEmpty,
      );
    });

    testWidgets('once per export from either entry point', (tester) async {
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);
      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(tester, ExportKeys.setting));
      await settleExport(tester);

      expect(
        await eventsNamed(database, AnalyticsEventName.gardenExported),
        hasLength(2),
      );
    });
  });
}

/// Waits for an in-flight export to finish.
///
/// Not [settle]: Picture.toImage and Image.toByteData are completed by the
/// engine, not by fake-async timers, so pumping alone never finishes them.
Future<void> settleExport(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await settle(tester, over: const Duration(milliseconds: 100));
  }
}

/// A share sheet that stays open until the test closes it, so the progress
/// state can be observed.
final class _HeldGardenShare implements GardenShare {
  final List<GardenExport> shared = [];
  final List<Completer<ShareOutcome>> _open = [];

  void release() {
    for (final pending in _open) {
      if (!pending.isCompleted) pending.complete(ShareOutcome.shared);
    }
    _open.clear();
  }

  @override
  Future<ShareOutcome> share(GardenExport export) {
    shared.add(export);
    final pending = Completer<ShareOutcome>();
    _open.add(pending);
    return pending.future;
  }
}
