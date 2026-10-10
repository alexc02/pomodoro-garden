import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('a plot', () {
    test('compares by value, so two reads of a row are the same plot', () {
      expect(const GardenPlot(2, -3), const GardenPlot(2, -3));
      expect(const GardenPlot(2, -3), isNot(const GardenPlot(-3, 2)));
      // Two plots read off two different rows, holding the same coordinates.
      final read = [const GardenPlot(1, 1), GardenPlot(1, 0 + 1)];
      expect(read.toSet(), hasLength(1));
    });

    test('knows how near the viewer it is', () {
      // Depth is the whole of the isometric sort: both axes run away from the
      // viewer, so a plot with a larger x + y is in front and is drawn later.
      expect(const GardenPlot(0, 0).depth, lessThan(const GardenPlot(1, 0).depth));
      expect(const GardenPlot(1, 0).depth, const GardenPlot(0, 1).depth);
      expect(const GardenPlot(-1, -1).depth, lessThan(const GardenPlot(0, 0).depth));
    });
  });

  group('capacity', () {
    test('REQ-018 exactly: 12 plots, +4 every 10 sessions, stopping at 200',
        () {
      expect(GardenPlots.unlockedAfter(0), 12);
      expect(GardenPlots.unlockedAfter(9), 12);
      expect(GardenPlots.unlockedAfter(10), 16);
      expect(GardenPlots.unlockedAfter(19), 16);
      expect(GardenPlots.unlockedAfter(20), 20);
      expect(GardenPlots.unlockedAfter(100), 52);
    });

    test('is derived from the count, so an existing user gets their unlocks',
        () {
      // The point of deriving rather than incrementing: a user who arrives at
      // this build with 137 sessions behind them has 64 plots on their first
      // launch, not 12 with a long climb back.
      expect(GardenPlots.unlockedAfter(137), 12 + 4 * 13);
    });

    test('stops at 200 and stays there', () {
      // 470 completed sessions is the first count that reaches the cap.
      expect(GardenPlots.unlockedAfter(469), 196);
      expect(GardenPlots.unlockedAfter(470), 200);
      expect(GardenPlots.unlockedAfter(10000), 200);
    });

    test('never goes below the twelve the garden starts with', () {
      // Nothing should be able to hand this a negative count, and a garden with
      // eight plots would be a worse answer than refusing the input.
      expect(GardenPlots.unlockedAfter(-1), 12);
    });
  });

  group('the garden level', () {
    test('starts at one and rises with every unlock', () {
      expect(GardenPlots.levelAfter(0), 1);
      expect(GardenPlots.levelAfter(9), 1);
      expect(GardenPlots.levelAfter(10), 2);
      expect(GardenPlots.levelAfter(19), 2);
      expect(GardenPlots.levelAfter(100), 11);
    });

    test('is the same fact as the plot count, said as a number a user keeps',
        () {
      // REQ-028's level and REQ-018's capacity are one rule read twice, so the
      // two can never disagree: the plots a level has are the twelve it starts
      // with plus four for every level above the first.
      for (final sessions in [0, 1, 9, 10, 55, 137, 469, 470, 10000]) {
        expect(
          GardenPlots.unlockedAfter(sessions),
          GardenPlots.initial +
              GardenPlots.perUnlock * (GardenPlots.levelAfter(sessions) - 1),
          reason: 'level and capacity disagree at $sessions sessions',
        );
      }
    });

    test('stops where the garden does', () {
      expect(GardenPlots.levelAfter(470), GardenPlots.maximumLevel);
      expect(GardenPlots.levelAfter(10000), GardenPlots.maximumLevel);
      expect(GardenPlots.maximumLevel, 48);
    });

    test('never goes below one', () {
      expect(GardenPlots.levelAfter(-1), 1);
    });
  });

  group('the placement order', () {
    test('is exactly the 200 plots REQ-018 caps the garden at', () {
      expect(GardenPlots.inPlacementOrder, hasLength(GardenPlots.maximum));
      expect(GardenPlots.inPlacementOrder.toSet(), hasLength(200));
    });

    test('starts in the middle and works outwards', () {
      expect(GardenPlots.inPlacementOrder.first, const GardenPlot(0, 0));

      var previous = -1;
      for (final plot in GardenPlots.inPlacementOrder) {
        expect(
          plot.distanceFromCentreSquared,
          greaterThanOrEqualTo(previous),
          reason: '$plot is nearer the middle than the plot before it',
        );
        previous = plot.distanceFromCentreSquared;
      }
    });

    test('is the same order on every launch and on both platforms', () {
      // Integer comparisons all the way down, deliberately: the order decides
      // where every plant in the garden stands, and a tie broken by a float
      // would be a garden that could rearrange itself between builds.
      expect(
        GardenPlots.inPlacementOrder.take(9),
        const [
          GardenPlot(0, 0),
          GardenPlot(0, -1),
          GardenPlot(-1, 0),
          GardenPlot(1, 0),
          GardenPlot(0, 1),
          GardenPlot(-1, -1),
          GardenPlot(1, -1),
          GardenPlot(-1, 1),
          GardenPlot(1, 1),
        ],
      );
    });

    test('knows where in the order a plot comes', () {
      expect(GardenPlots.orderOf(const GardenPlot(0, 0)), 0);
      expect(
        GardenPlots.orderOf(GardenPlots.inPlacementOrder[137]),
        137,
      );
      expect(GardenPlots.orderOf(const GardenPlot(50, 50)), isNull);
    });
  });

  group('finding a plot for a new plant', () {
    test('an empty garden puts the first plant in the middle', () {
      expect(GardenPlots.nextFree(const {}), const GardenPlot(0, 0));
    });

    test('the nearest free plot to the middle, not the next one along', () {
      // A garden that lost the plant in its middle grows back into the hole
      // rather than continuing outwards. "Nearest available" is REQ-017's
      // wording and this is the case that distinguishes it from "next".
      final occupied = GardenPlots.inPlacementOrder.take(20).toSet()
        ..remove(const GardenPlot(0, 0));

      expect(GardenPlots.nextFree(occupied), const GardenPlot(0, 0));
    });

    test('fills the order one plot at a time', () {
      final occupied = <GardenPlot>{};
      for (var planted = 0; planted < 50; planted++) {
        final plot = GardenPlots.nextFree(occupied);
        expect(plot, GardenPlots.inPlacementOrder[planted]);
        occupied.add(plot!);
      }
    });

    test('a full garden has nowhere left to put one', () {
      // The 201st plant. Answered with null rather than an exception or a
      // silently reused plot: see
      // docs/adr/0006-the-garden-has-a-plot-for-every-plant-it-can-hold.md.
      expect(GardenPlots.nextFree(GardenPlots.inPlacementOrder.toSet()), isNull);
    });
  });

  group('sowing into a garden with decor in it', () {
    /// The [count] plots nearest the middle, as a set.
    Set<GardenPlot> nearest(int count) =>
        GardenPlots.inPlacementOrder.take(count).toSet();

    test('takes the nearest plot holding neither a plant nor an item', () {
      // The ordinary case, and the one every real garden lives in. The lantern
      // in plot 1 is stepped over rather than pushed aside — an arrangement the
      // user composed is exactly as they left it.
      final sowing = GardenPlots.sow(
        plants: {GardenPlots.inPlacementOrder[0]},
        decor: {GardenPlots.inPlacementOrder[1]},
      );

      expect(sowing.plot, GardenPlots.inPlacementOrder[2]);
      expect(sowing.displacing, isNull);
    });

    test('grows back into a hole in the middle, decor or no decor', () {
      final planted = nearest(20)..remove(const GardenPlot(0, 0));

      expect(
        GardenPlots.sow(plants: planted, decor: {const GardenPlot(3, 3)}).plot,
        const GardenPlot(0, 0),
      );
    });

    test('agrees with the plain rule when there is no decor', () {
      final planted = nearest(37);

      expect(
        GardenPlots.sow(plants: planted, decor: const {}).plot,
        GardenPlots.nextFree(planted),
      );
    });

    test('displaces the outermost item when every plot is spoken for', () {
      // Two hundred plots, all of them holding something: 198 plants and two
      // items. The plant lands where the *outer* item was standing, because a
      // garden fills from the middle and what the user composed is nearest it.
      final inner = GardenPlots.inPlacementOrder[4];
      final outer = GardenPlots.inPlacementOrder[199];
      final planted = GardenPlots.inPlacementOrder.toSet()
        ..remove(inner)
        ..remove(outer);

      final sowing = GardenPlots.sow(plants: planted, decor: {inner, outer});

      expect(sowing.plot, outer);
      expect(sowing.displacing, outer);
    });

    test('a plant standing where an item stood is standing in its plot', () {
      // The two fields are equal whenever the second one is set: the planting
      // evicts an item and takes the plot it vacated, rather than clearing one
      // plot and filling another.
      final planted = GardenPlots.inPlacementOrder.take(199).toSet();
      final sowing = GardenPlots.sow(
        plants: planted,
        decor: {GardenPlots.inPlacementOrder[199]},
      );

      expect(sowing.displacing, sowing.plot);
    });

    test('a garden of two hundred plants has nowhere left, as it always did',
        () {
      // ADR 0006's case, untouched by any of this. What ADR 0017 promises is
      // narrower and exact: decor is never the *reason* a plant goes unplaced.
      final sowing = GardenPlots.sow(
        plants: GardenPlots.inPlacementOrder.toSet(),
        decor: const {},
      );

      expect(sowing.plot, isNull);
      expect(sowing.displacing, isNull);
    });

    test('every plant finds a plot until two hundred plants are in the ground',
        () {
      // The guarantee, run out to its edge: an arrangement of fifty items and a
      // user who keeps finishing sessions. Not one of the two hundred plants is
      // turned away, and each displacement takes exactly one item.
      final planted = <GardenPlot>{};
      final decorated = GardenPlots.inPlacementOrder.skip(150).toSet();

      for (var session = 0; session < GardenPlots.maximum; session++) {
        final sowing = GardenPlots.sow(plants: planted, decor: decorated);
        expect(sowing.plot, isNotNull, reason: 'session $session');

        if (sowing.displacing != null) decorated.remove(sowing.displacing);
        planted.add(sowing.plot!);
      }

      expect(planted, hasLength(GardenPlots.maximum));
      // Fifty items, and fifty of them gave way — the arrangement is only
      // reached once the garden has genuinely run out of soil.
      expect(decorated, isEmpty);
    });
  });
}
