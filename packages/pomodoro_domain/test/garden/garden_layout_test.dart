import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

final DateTime _anchor = DateTime.utc(2026, 8, 11, 9, 41);

Plant _plant(int n, {GardenPlot? plot}) => Plant(
      id: 'plant-$n',
      sessionId: 'session-$n',
      type: PlantType.flower,
      species: PlantSpecies.tulip,
      stage: GrowthStage.mature,
      plantedAt: _anchor.add(Duration(days: n)),
      sessionDuration: const Duration(minutes: 25),
      plot: plot,
    );

/// [count] plants in the first [count] plots.
List<Plant> _garden(int count) => [
      for (var n = 0; n < count; n++)
        _plant(n, plot: GardenPlots.inPlacementOrder[n]),
    ];

void main() {
  group('an empty garden', () {
    final layout = GardenLayout.of(plants: const [], completedSessions: 0);

    test('is twelve plots of bare soil', () {
      expect(layout.plotCount, 12);
      expect(layout.emptyPlots, 12);
      expect(layout.plants, isEmpty);
    });

    test('has something to show for every plot', () {
      for (final plot in layout.plots) {
        expect(layout.plantIn(plot), isNull);
      }
    });
  });

  group('plots', () {
    test('are drawn back to front, so a plant in front overlaps the one behind',
        () {
      final layout = GardenLayout.of(
        plants: _garden(60),
        completedSessions: 60,
      );

      var previous = -1000;
      for (final plot in layout.plots) {
        expect(plot.depth, greaterThanOrEqualTo(previous));
        previous = plot.depth;
      }
    });

    test('newly unlocked ones show as empty soil', () {
      final before = GardenLayout.of(plants: _garden(9), completedSessions: 9);
      final after = GardenLayout.of(plants: _garden(10), completedSessions: 10);

      expect(before.plotCount, 12);
      expect(before.emptyPlots, 3);
      expect(after.plotCount, 16);
      expect(after.emptyPlots, 6);
    });

    test('are the ones the placement order picked, and no others', () {
      final layout = GardenLayout.of(plants: _garden(5), completedSessions: 5);

      expect(
        layout.plots.toSet(),
        GardenPlots.inPlacementOrder.take(12).toSet(),
      );
    });
  });

  group('a garden with more plants than its sessions have unlocked', () {
    // After session 20 there are more plants (1 per session) than unlocked
    // plots (4 per 10). The garden grows to fit.
    test('grows to hold all of them', () {
      final layout = GardenLayout.of(
        plants: _garden(31),
        completedSessions: 31,
      );

      expect(GardenPlots.unlockedAfter(31), 24, reason: 'unlock schedule is unchanged');
      expect(layout.plotCount, 31);
      expect(layout.emptyPlots, 0);
      expect(layout.plants, hasLength(31));
    });

    test('never loses a plant off the edge of its plots', () {
      final layout = GardenLayout.of(
        plants: [_plant(1, plot: GardenPlots.inPlacementOrder[80])],
        completedSessions: 0,
      );

      expect(layout.plotCount, 81);
      expect(layout.plantIn(GardenPlots.inPlacementOrder[80]), isNotNull);
    });
  });

  group('a full garden', () {
    test('stops at two hundred plots however many sessions are behind it', () {
      final layout = GardenLayout.of(
        plants: _garden(200),
        completedSessions: 5000,
      );

      expect(layout.plotCount, 200);
      expect(layout.emptyPlots, 0);
    });

    test('keeps the plants it has no plot for, and says how many', () {
      // The 201st plant: kept, not dropped.
      final layout = GardenLayout.of(
        plants: [..._garden(200), _plant(200), _plant(201)],
        completedSessions: 5000,
      );

      expect(layout.plotCount, 200);
      expect(layout.plants, hasLength(200));
      expect(layout.shelved, hasLength(2));
      expect(layout.isFull, isTrue);
    });

    test('is not full until it is', () {
      expect(
        GardenLayout.of(plants: _garden(199), completedSessions: 199).isFull,
        isFalse,
      );
    });
  });

  group('a garden with plants on the shelf', () {
    test('keeps a plot for each of them, so shelving leaves soil behind', () {
      // 31 plants fill 31 plots. Lift the outermost one out.
      final planted = _garden(31);
      final layout = GardenLayout.of(
        plants: [...planted.take(30), planted.last.inPlot(null)],
        completedSessions: 31,
      );

      expect(GardenPlots.unlockedAfter(31), 24);
      expect(layout.plotCount, 31, reason: 'the garden did not shrink');
      expect(layout.emptyPlots, 1);
      expect(layout.isEmpty(GardenPlots.inPlacementOrder[30]), isTrue);
      expect(layout.shelved.single.id, planted.last.id);
    });

    test('has room for everything even with the whole garden shelved', () {
      final layout = GardenLayout.of(
        plants: [for (var n = 0; n < 40; n++) _plant(n)],
        completedSessions: 40,
      );

      expect(layout.plotCount, 40);
      expect(layout.emptyPlots, 40);
      expect(layout.plants, isEmpty);
      expect(layout.shelved, hasLength(40));
    });

    test('is no bigger for them while the unlocked plots already cover it',
        () {
      final layout = GardenLayout.of(
        plants: [..._garden(5), _plant(5), _plant(6)],
        completedSessions: 7,
      );

      expect(layout.plotCount, 12);
      expect(layout.emptyPlots, 7);
    });

    test('still stops at two hundred plots', () {
      final layout = GardenLayout.of(
        plants: [for (var n = 0; n < 260; n++) _plant(n)],
        completedSessions: 260,
      );

      expect(layout.plotCount, 200);
      expect(layout.isFull, isTrue);
    });

    test('shelves a plant whose plot is outside the two hundred', () {
      final layout = GardenLayout.of(
        plants: [_plant(1, plot: const GardenPlot(50, 50))],
        completedSessions: 1,
      );

      expect(layout.plants, isEmpty);
      expect(layout.shelved, hasLength(1));
    });
  });

  group('a garden with a bonus plant in it', () {
    // Awards take a plot but don't count as sessions for unlocks.
    Plant bonus(Milestone milestone, {GardenPlot? plot}) => Plant.forMilestone(
          milestone,
          id: 'bonus-${milestone.sessions}',
          plantedAt: _anchor,
          plot: plot,
        );

    test('names the awards apart from the plants sessions grew', () {
      final layout = GardenLayout.of(
        plants: [
          ..._garden(10),
          bonus(Milestone.ten, plot: GardenPlots.inPlacementOrder[10]),
        ],
        completedSessions: 10,
      );

      expect(layout.plants, hasLength(11));
      expect(layout.bonusPlants, hasLength(1));
      expect(layout.bonusPlants.single.milestone, Milestone.ten);
    });

    test('unlocks no plots for an award', () {
      // Capacity comes from sessions, not plants, so awards don't unlock plots.
      final withoutAward =
          GardenLayout.of(plants: _garden(10), completedSessions: 10);
      final withAward = GardenLayout.of(
        plants: [
          ..._garden(10),
          bonus(Milestone.ten, plot: GardenPlots.inPlacementOrder[10]),
        ],
        completedSessions: 10,
      );

      expect(withoutAward.plotCount, 16);
      expect(withAward.plotCount, 16, reason: 'unlocks unchanged');
      expect(withAward.emptyPlots, withoutAward.emptyPlots - 1);
    });

    test('grows past the unlock schedule rather than losing the award', () {
      // 16 plots, 16 plants. The award goes in plot 17 and the garden grows.
      final layout = GardenLayout.of(
        plants: [
          ..._garden(16),
          bonus(Milestone.ten, plot: GardenPlots.inPlacementOrder[16]),
        ],
        completedSessions: 10,
      );

      expect(GardenPlots.unlockedAfter(10), 16);
      expect(layout.plotCount, 17);
      expect(layout.plants, hasLength(17));
      expect(layout.shelved, isEmpty);
    });

    test('keeps an award it has no plot for, rather than dropping it', () {
      final layout = GardenLayout.of(
        plants: [..._garden(200), bonus(Milestone.ten)],
        completedSessions: 5000,
      );

      expect(layout.shelved.single.milestone, Milestone.ten);
      // In `shelved`, not `bonusPlants`.
      expect(layout.bonusPlants, isEmpty);
    });

    test('has no bonus plants until one is awarded', () {
      expect(
        GardenLayout.of(plants: _garden(9), completedSessions: 9).bonusPlants,
        isEmpty,
      );
    });
  });

  test('a plot holds the plant that was planted in it', () {
    final plants = _garden(3);
    final layout = GardenLayout.of(plants: plants, completedSessions: 3);

    for (final plant in plants) {
      expect(layout.plantIn(plant.plot!), plant);
    }
  });

  group('a garden with decor in it', () {
    Decor item(int n, {DecorKind kind = DecorKind.lantern}) => Decor(
          id: 'decor-$n',
          kind: kind,
          plot: GardenPlots.inPlacementOrder[n],
          placedAt: _anchor,
        );

    test('stands the item in the plot it was placed in', () {
      final layout = GardenLayout.of(
        plants: _garden(2),
        decor: [item(5, kind: DecorKind.bench)],
        completedSessions: 2,
      );

      expect(layout.decor, hasLength(1));
      expect(layout.decorIn(GardenPlots.inPlacementOrder[5])!.kind,
          DecorKind.bench);
      expect(layout.plantIn(GardenPlots.inPlacementOrder[5]), isNull);
    });

    test('an occupied plot is not an empty one', () {
      final bare = GardenLayout.of(plants: _garden(2), completedSessions: 2);
      final arranged = GardenLayout.of(
        plants: _garden(2),
        decor: [item(5), item(6)],
        completedSessions: 2,
      );

      expect(bare.emptyPlots, 10);
      expect(arranged.emptyPlots, 8);
      expect(arranged.isEmpty(GardenPlots.inPlacementOrder[5]), isFalse);
      expect(arranged.isEmpty(GardenPlots.inPlacementOrder[7]), isTrue);
    });

    test('unlocks no plots for decor', () {
      final layout = GardenLayout.of(
        plants: _garden(2),
        decor: [item(3), item(4), item(5), item(6)],
        completedSessions: 2,
      );

      expect(layout.plotCount, 12);
    });

    test('holds open a plot the item is standing in', () {
      // 16 plots, item in the 16th, no new sessions. The plot stays.
      final layout = GardenLayout.of(
        plants: const [],
        decor: [item(40)],
        completedSessions: 0,
      );

      expect(GardenPlots.unlockedAfter(0), 12);
      expect(layout.plotCount, 41);
      expect(layout.decorIn(GardenPlots.inPlacementOrder[40]), isNotNull);
    });

    test('never draws an item where a plant is standing', () {
      // Can't happen via the app, but if it does the plant wins.
      final layout = GardenLayout.of(
        plants: _garden(3),
        decor: [item(1)],
        completedSessions: 3,
      );

      expect(layout.decor, isEmpty);
      expect(layout.plantIn(GardenPlots.inPlacementOrder[1]), isNotNull);
      expect(layout.decorIn(GardenPlots.inPlacementOrder[1]), isNull);
    });

    test('knows which plots it has and which it does not', () {
      final layout = GardenLayout.of(plants: const [], completedSessions: 0);

      expect(layout.hasPlot(GardenPlots.inPlacementOrder[11]), isTrue);
      expect(layout.hasPlot(GardenPlots.inPlacementOrder[12]), isFalse);
      expect(layout.isEmpty(GardenPlots.inPlacementOrder[12]), isFalse,
          reason: 'locked plots are not empty plots');
    });

    test('an item outside the two hundred is not drawn', () {
      final layout = GardenLayout.of(
        plants: const [],
        decor: [
          Decor(
            id: 'far',
            kind: DecorKind.pond,
            plot: const GardenPlot(50, 50),
            placedAt: _anchor,
          ),
        ],
        completedSessions: 0,
      );

      expect(layout.decor, isEmpty);
      expect(layout.plotCount, 12);
    });
  });
}
