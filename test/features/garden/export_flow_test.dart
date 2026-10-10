import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/design/garden_colors.dart';
import 'package:pomodoro_garden/src/export/garden_exporter.dart';
import 'package:pomodoro_garden/src/export/garden_share.dart';
import 'package:pomodoro_garden/src/features/garden/export_garden.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/garden/decor_providers.dart';
import 'package:pomodoro_garden/src/garden/garden_atlas_recipe.dart';
import 'package:pomodoro_garden/src/garden/garden_painter.dart';
import 'package:pomodoro_garden/src/garden/plant_providers.dart';
import 'package:pomodoro_garden/src/garden/theme_providers.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';
import '../../support/celebrations.dart';
import '../../support/event_log.dart';
import '../../support/garden_seed.dart';
import '../../support/garden_share_fake.dart';

/// REQ-035 through the real app: the two doors, and what comes out of each.
///
/// The picture itself is asserted in `test/garden/garden_export_test.dart` —
/// its size and its projection, pixel by pixel. What is under test here is the
/// *flow*: that both doors reach the same export, that the user is told while
/// it is happening and when it fails, and that §7.1's event is recorded once
/// the sheet is up.

/// The painter currently on the garden tab.
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

  /// Opens the app on the garden tab, with [sessions] plants in the ground.
  ///
  /// The celebration is put away first: ten completed sessions is a milestone,
  /// and a garden worth exporting is always past one. The sheet it raises would
  /// otherwise be over the app bar this whole file taps.
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

  /// The same, then straight to settings — REQ-035's other door.
  Future<void> openSettings(
    WidgetTester tester, {
    int sessions = 12,
  }) async {
    await openGarden(tester, sessions: sessions);
    await tapTab(tester, AppTab.settings);
  }

  group('the door on the garden', () {
    testWidgets('is there for everybody, bought or not', (tester) async {
      // Deliberately not gated. REQ-035 sells the *corner of the image*, not
      // the button — a free export is a real export — and REQ-041 puts the
      // paywall in settings and the theme picker and nowhere else, so a locked
      // control here would have had nowhere to send anybody. The same
      // reconciliation ticket 20 made about arranging, reaching the opposite
      // answer because the requirement is the opposite shape.
      await openGarden(tester);

      expect(find.byKey(ExportKeys.action), findsOneWidget);
    });

    testWidgets('hands the platform a PNG of the garden', (tester) async {
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      expect(share.shared, hasLength(1));
      expect(share.last.png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(share.last.width, greaterThan(0));
      expect(share.last.filename, 'pomodoro-garden.png');
    });

    testWidgets('and the picture is of the whole garden, not the screen',
        (tester) async {
      // The criterion said as the thing a test can actually see from out here:
      // the app is on a 500x900 surface and the image is far larger than it in
      // both directions, because it was fitted to the garden rather than
      // captured from the viewport. What guarantees it structurally is that
      // `GardenExporter` takes no camera at all — see its own test.
      await openGarden(tester, sessions: 200);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      expect(share.last.width, greaterThan(500));
      expect(share.last.height, greaterThan(900));
    });
  });

  group('the door in settings', () {
    testWidgets('exports the same garden from the other end of the app',
        (tester) async {
      await openSettings(tester);

      await tester.tap(await scrollToSetting(tester, ExportKeys.setting));
      await settleExport(tester);

      expect(share.shared, hasLength(1));
      expect(share.last.png, isNotEmpty);
    });

    testWidgets('and it is the same image the garden tab would have made',
        (tester) async {
      // Settings has no garden on screen and no skin over its subtree, so this
      // is the assertion that the export derives its own colours rather than
      // borrowing whatever theme it was started under. Two exports of one
      // garden, from opposite ends of the app, byte for byte.
      await openGarden(tester, sessions: 30);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      await tapTab(tester, AppTab.settings);
      await tester.tap(await scrollToSetting(tester, ExportKeys.setting));
      await settleExport(tester);

      expect(share.shared, hasLength(2));
      expect(share.shared[0].png, share.shared[1].png);
    });

    testWidgets('because it bakes the texture the screen is drawn from',
        (tester) async {
      // The reason the two are the same picture rather than two renderings
      // that happen to agree today: one recipe, and both callers ask for it.
      // A season, a theme or a decor colour that reached one and not the other
      // would show up here as two signatures.
      await openGarden(tester);
      final onScreen = _painter(tester).atlas.signature;

      // Computed the way `exportGarden` does, from a context that is *not*
      // under the garden's skin — which is the case that could have differed.
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

  group('what the user is promised at the door', () {
    testWidgets('settings says what the picture will be, with no caveat',
        (tester) async {
      // An earlier draft said "with a small mark in the corner" here, because
      // the export a free user got carried one. There is one kind of export
      // now, and the row says so. See `docs/adr/0021-…`.
      await openSettings(tester);
      await scrollToSetting(tester, ExportKeys.setting);

      expect(find.textContaining('at full size'), findsOneWidget);
      expect(find.textContaining('mark in the corner'), findsNothing);
    });
  });

  group('while it is happening', () {
    testWidgets('the control says so, and cannot be tapped twice',
        (tester) async {
      // The ticket's "progress indication". Caught between the tap and the
      // export finishing by holding the share sheet open — which is the state
      // a real platform leaves the app in while its sheet is up.
      final held = _HeldGardenShare();
      await openGarden(tester, sessions: 200, share_: held);

      await tester.tap(find.byKey(ExportKeys.action));
      await tester.pump();

      // Drawing, on the very next frame: the state is set before the first
      // await, so there is no frame in which the user has tapped and nothing
      // has happened.
      expect(find.byKey(ExportKeys.progress), findsOneWidget);
      expect(find.byKey(ExportKeys.action), findsNothing);

      // The image is made, and the sheet is asked for and does not return.
      await settleExport(tester);
      expect(held.shared, hasLength(1), reason: 'one tap, one export');
      expect(
        find.byKey(ExportKeys.progress),
        findsOneWidget,
        reason: 'still handing it over',
      );

      held.release();
      await settleExport(tester);

      expect(find.byKey(ExportKeys.progress), findsNothing);
      expect(find.byKey(ExportKeys.action), findsOneWidget);
      expect(held.shared, hasLength(1), reason: 'and only one');
    });

    testWidgets('the app is still usable — the export does not block it',
        (tester) async {
      // A frame pumped mid-export still lays out and still paints, which is
      // what "does not block the UI" means from a test's side of the fence:
      // the raster and the PNG encode both happen off the Dart thread.
      final held = _HeldGardenShare();
      await openGarden(tester, sessions: 200, share_: held);

      await tester.tap(find.byKey(ExportKeys.action));
      await tester.pump();

      // The bottom bar still works while the image is being made, and the tab
      // it opens is live rather than a frozen picture of one.
      await tapTab(tester, AppTab.timer);
      expect(find.text('Start'), findsOneWidget);

      // And the export carried on regardless of the user walking away from the
      // screen they started it on: it belongs to the app, not to the garden.
      await settleExport(tester);
      held.release();
      await settleExport(tester);
      expect(held.shared, hasLength(1));
    });
  });

  group('when it cannot be done', () {
    testWidgets('the user is told rather than left looking at a spinner',
        (tester) async {
      share.outcome = ShareOutcome.unavailable;
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      expect(find.byKey(ExportKeys.failure), findsOneWidget);
      expect(find.byKey(ExportKeys.progress), findsNothing);
      expect(find.byKey(ExportKeys.action), findsOneWidget);
    });

    testWidgets('and can try again afterwards', (tester) async {
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
    // Read back out of the real log rather than off a fake port, the way every
    // other §7.1 assertion in this suite is: what is under test is that the
    // event reached storage with the right parameter, and a fake collecting
    // events in a list would pass with the database wiring broken.

    testWidgets('is recorded once the sheet is up, and carries nothing',
        (tester) async {
      // §7.1's `is_premium` went with the two kinds of export it separated:
      // there is one kind, so the event that records it needs no parameter to
      // tell them apart.
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      final event = await theEventNamed(
        database,
        AnalyticsEventName.gardenExported,
      );
      expect(event.parameters, isEmpty);
    });

    testWidgets('and nothing is recorded for an export that never left',
        (tester) async {
      // §7.1 counts exports that happened. A sheet that would not open is not
      // one, and counting it would put a broken device in the same column as a
      // user sharing their garden.
      share.outcome = ShareOutcome.unavailable;
      await openGarden(tester);

      await tester.tap(find.byKey(ExportKeys.action));
      await settleExport(tester);

      expect(
        await eventsNamed(database, AnalyticsEventName.gardenExported),
        isEmpty,
      );
    });

    testWidgets('once per export, from either door', (tester) async {
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

/// Waits for an export in flight to finish.
///
/// **Why this is not [settle].** Rendering an image is the one thing this app
/// does that leaves the fake-async zone a widget test runs in: `Picture.toImage`
/// and `Image.toByteData` are completed by the engine rather than by a timer, so
/// no amount of pumping frames advances them. [WidgetTester.runAsync] lets real
/// asynchrony run, and the pumps between deliver the state changes it produced
/// back to the tree.
///
/// That the export needs this is the test-side shadow of the thing the ticket
/// asked for: the raster happens off the Dart thread, which is what keeps the UI
/// alive while it does.
Future<void> settleExport(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await settle(tester, over: const Duration(milliseconds: 100));
  }
}

/// A share sheet that stays open until the test closes it.
///
/// What a real platform does: `share` returns when the sheet is *up*, and on a
/// phone that is a moment later. Holding it is how the export's own progress
/// state can be looked at from outside.
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
