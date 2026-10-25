import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/features/garden/decor_picker.dart';
import 'package:pip_garden/src/garden/garden_painter.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

/// REQ-040 driven through the real app: the user arranging their garden.
///
/// Everything here goes through taps on the garden itself, because the garden
/// is one painted surface and the arranging is a *mode over the picture* —
/// there is no widget per plot for a test to find, and a test that reached past
/// the painter would not be testing the thing the user does.

/// The painter currently on the garden tab: the whole of what is being drawn,
/// and the camera it is being drawn from.
GardenPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(_paint)
    .painter! as GardenPainter;

final Finder _paint = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is GardenPainter,
  skipOffstage: false,
);

/// Taps the middle of [plot]'s tile, wherever the camera has put it.
Future<void> _tapPlot(WidgetTester tester, GardenPlot plot) async {
  final origin = tester.getTopLeft(_paint);
  await tester.tapAt(origin + _painter(tester).projection.centreOf(plot));
  await settle(tester);
}

/// The plot a garden of [sessions] plants has not filled.
GardenPlot _emptyPlot(int index) => GardenPlots.inPlacementOrder[index];

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  /// Opens the garden tab on a garden with something already in it.
  Future<void> openGarden(
    WidgetTester tester, {
    int sessions = 3,
    List<Override> overrides = const [],
  }) async {
    await seedGarden(database, sessions: sessions);

    await pumpApp(
      tester,
      database: database,
      surface: const Size(500, 900),
      overrides: overrides,
    );
    await tapTab(tester, AppTab.garden);
  }

  /// Enters arranging, the way a user does.
  Future<void> startArranging(WidgetTester tester) async {
    await tester.tap(find.byKey(DecorKeys.arrange));
    await settle(tester);
  }

  /// Stands a [kind] in [plot] through the picker.
  Future<void> place(
    WidgetTester tester,
    DecorKind kind,
    GardenPlot plot,
  ) async {
    await _tapPlot(tester, plot);
    await tester.tap(find.byKey(DecorKeys.kind(kind)));
    await settle(tester);
  }

  group('placing', () {
    testWidgets('the user stands an object in an empty plot', (tester) async {
      await openGarden(tester);
      await startArranging(tester);

      await place(tester, DecorKind.lantern, _emptyPlot(5));

      final layout = _painter(tester).layout;
      expect(layout.decor, hasLength(1));
      expect(layout.decorIn(_emptyPlot(5))!.kind, DecorKind.lantern);
    });

    testWidgets('the picker offers all four, by name', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await _tapPlot(tester, _emptyPlot(5));

      for (final kind in DecorKind.values) {
        expect(find.byKey(DecorKeys.kind(kind)), findsOneWidget);
        expect(find.text(kind.label), findsOneWidget);
      }
    });

    testWidgets('dismissing the picker places nothing', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await _tapPlot(tester, _emptyPlot(5));

      // The backdrop, which is how a sheet is dismissed.
      await tester.tapAt(const Offset(250, 40));
      await settle(tester);

      expect(_painter(tester).layout.decor, isEmpty);
      expect(await DriftDecorRepository(database).decor(), isEmpty);
    });

    testWidgets('a plot with a plant in it is not offered one', (tester) async {
      // A plant is not furniture: nothing in this mode can move one, take one
      // out, or stand a bench on top of one.
      await openGarden(tester);
      await startArranging(tester);

      await _tapPlot(tester, GardenPlots.inPlacementOrder[0]);

      expect(find.byKey(DecorKeys.kind(DecorKind.bench)), findsNothing);
      expect(_painter(tester).layout.decor, isEmpty);
    });

    testWidgets('and nothing is placed while the garden is only being looked '
        'at', (tester) async {
      await openGarden(tester);

      await _tapPlot(tester, _emptyPlot(5));

      expect(find.byKey(DecorKeys.kind(DecorKind.bench)), findsNothing);
      expect(_painter(tester).layout.decor, isEmpty);
    });
  });

  group('moving and removing', () {
    testWidgets('an object picked up and put down somewhere else is the same '
        'object', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.bench, _emptyPlot(5));

      final placed = _painter(tester).layout.decor.single;

      await _tapPlot(tester, _emptyPlot(5));
      expect(
        find.byKey(DecorKeys.remove),
        findsOneWidget,
        reason: 'picking something up is what the bar says it is',
      );

      await _tapPlot(tester, _emptyPlot(7));

      final moved = _painter(tester).layout.decor.single;
      expect(moved.id, placed.id);
      expect(moved.plot, _emptyPlot(7));
      expect(_painter(tester).layout.decorIn(_emptyPlot(5)), isNull);
    });

    testWidgets('an object can be taken out of the garden', (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.pond, _emptyPlot(5));

      await _tapPlot(tester, _emptyPlot(5));
      await tester.tap(find.byKey(DecorKeys.remove));
      await settle(tester);

      expect(_painter(tester).layout.decor, isEmpty);
      expect(await DriftDecorRepository(database).decor(), isEmpty);
    });

    testWidgets('putting one down where it already is changes nothing',
        (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.birdbath, _emptyPlot(5));

      await _tapPlot(tester, _emptyPlot(5));
      // Tapping it again is how a user lets go of something without moving it.
      await _tapPlot(tester, _emptyPlot(5));

      expect(_painter(tester).layout.decorIn(_emptyPlot(5)), isNotNull);
      expect(find.byKey(DecorKeys.remove), findsNothing);
    });

    testWidgets('leaving arranging puts the garden back to being looked at',
        (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.lantern, _emptyPlot(5));

      await tester.tap(find.byKey(DecorKeys.done));
      await settle(tester);

      expect(find.byKey(DecorKeys.guidance), findsNothing);
      // And a tap on soil is a tap on soil again.
      await _tapPlot(tester, _emptyPlot(6));
      expect(find.byKey(DecorKeys.kind(DecorKind.bench)), findsNothing);
    });
  });

  group('the garden says what it holds', () {
    testWidgets('an arrangement is in the sentence a reader hears',
        (tester) async {
      // The garden is one painted surface, so this sentence is the only thing a
      // screen reader has. A feature about composing something would be
      // invisible without it.
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.lantern, _emptyPlot(5));

      expect(
        find.bySemanticsLabel('Your garden: 3 plants in 12 plots. One thing '
            'you placed stands among them.'),
        findsOneWidget,
      );

      await place(tester, DecorKind.bench, _emptyPlot(6));

      expect(
        find.bySemanticsLabel('Your garden: 3 plants in 12 plots. 2 things '
            'you placed stand among them.'),
        findsOneWidget,
      );
    });

    testWidgets('and says nothing about decor when there is none',
        (tester) async {
      await openGarden(tester);

      expect(
        find.bySemanticsLabel('Your garden: 3 plants in 12 plots.'),
        findsOneWidget,
      );
    });
  });

  group('what interrupts it', () {
    testWidgets('starting a session puts the garden back to being looked at',
        (tester) async {
      // The same judgement REQ-041 makes about the paywall: a countdown the
      // user started is not something to be rearranging furniture behind. Auto
      // start can begin one without anybody tapping anything, which is why this
      // is a listener rather than a check at the tap.
      await openGarden(tester);
      await startArranging(tester);
      expect(find.byKey(DecorKeys.guidance), findsOneWidget);

      await startSession(tester);
      await tapTab(tester, AppTab.garden);

      expect(find.byKey(DecorKeys.guidance), findsNothing);
      // And the arrangement is untouched by any of it.
      expect(await DriftDecorRepository(database).decor(), isEmpty);
    });
  });

  group('what survives', () {
    testWidgets('an arrangement is still there after a relaunch',
        (tester) async {
      await openGarden(tester);
      await startArranging(tester);
      await place(tester, DecorKind.lantern, _emptyPlot(5));
      await place(tester, DecorKind.pond, _emptyPlot(6));

      await killApp(tester);
      await pumpApp(
        tester,
        database: database,
        surface: const Size(500, 900),
      );
      await tapTab(tester, AppTab.garden);

      final layout = _painter(tester).layout;
      expect(layout.decor, hasLength(2));
      expect(layout.decorIn(_emptyPlot(5))!.kind, DecorKind.lantern);
      expect(layout.decorIn(_emptyPlot(6))!.kind, DecorKind.pond);
    });

    testWidgets('and the way in is offered to everybody', (tester) async {
      // An earlier draft sold arranging, so the control was absent on a device
      // that owned nothing and this group carried three tests about what a
      // lapsed entitlement left standing. The app is free: the door is on the
      // garden for every user, on the first frame, with nothing to buy and
      // nothing to lose. See `docs/adr/0021-…`.
      await openGarden(tester);

      expect(find.byKey(DecorKeys.arrange), findsOneWidget);
    });
  });
}
