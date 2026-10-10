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

/// [count] plants, in the plots they would have been planted into one after
/// another.
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
      // The reward for the tenth session is four plots the user can see they
      // have yet to fill.
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
    // From the twenty-first completed session on, a user has earned more plants
    // than REQ-018 has unlocked plots — the plants arrive one per session and
    // the plots four per ten. The unlock count is a floor: the garden always
    // has room for everything in it. See ADR 0006.
    test('grows to hold all of them', () {
      final layout = GardenLayout.of(
        plants: _garden(31),
        completedSessions: 31,
      );

      expect(GardenPlots.unlockedAfter(31), 24, reason: 'REQ-018 is unchanged');
      expect(layout.plotCount, 31);
      expect(layout.emptyPlots, 0);
      expect(layout.plants, hasLength(31));
    });

    test('never loses a plant off the edge of its plots', () {
      // A plant standing in a plot the garden had not counted would simply not
      // be drawn, which is the failure this rule exists to make impossible.
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
      // The 201st plant. Recorded, not dropped and not crashed on: capacity
      // bounds what the garden shows, never what the app remembers. ADR 0006.
      final layout = GardenLayout.of(
        plants: [..._garden(200), _plant(200), _plant(201)],
        completedSessions: 5000,
      );

      expect(layout.plotCount, 200);
      expect(layout.plants, hasLength(200));
      expect(layout.unplaced, hasLength(2));
      expect(layout.isFull, isTrue);
    });

    test('is not full until it is', () {
      expect(
        GardenLayout.of(plants: _garden(199), completedSessions: 199).isFull,
        isFalse,
      );
    });
  });

  group('a garden with a bonus plant in it', () {
    // REQ-021's plants stand in the garden like any other, and count towards
    // nothing a session counts towards. The two facts are one test: the garden
    // grows to hold the award, and the plot unlocks do not move because an
    // award is not a session.
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

    test('unlocks no plots for it — an award is not a session', () {
      // Requirement 7, at the layer that would get it wrong: capacity is
      // derived from completed sessions, and a garden that counted its own
      // plants would hand out four plots for every ten awards.
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
      expect(withAward.plotCount, 16, reason: 'REQ-018 has not moved');
      expect(withAward.emptyPlots, withoutAward.emptyPlots - 1);
    });

    test('grows past the unlock schedule rather than losing the award', () {
      // A garden whose unlocked plots are all full: sixteen plots, sixteen
      // plants. The award goes into the seventeenth, and the garden grows to
      // include it — the same floor-not-ceiling rule ADR 0006 already sets.
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
      expect(layout.unplaced, isEmpty);
    });

    test('keeps an award it has no plot for, rather than dropping it', () {
      final layout = GardenLayout.of(
        plants: [..._garden(200), bonus(Milestone.ten)],
        completedSessions: 5000,
      );

      expect(layout.unplaced.single.milestone, Milestone.ten);
      // Not in `bonusPlants`, which is what is standing in the garden. It is in
      // `unplaced`, which is what the garden says it is holding.
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

    test('unlocks no plots for it — an item is not a session', () {
      // The same rule a bonus plant is held to, for the sharper reason: decor
      // is bought rather than earned, and a garden that grew because somebody
      // put four lanterns in it would be selling plots.
      final layout = GardenLayout.of(
        plants: _garden(2),
        decor: [item(3), item(4), item(5), item(6)],
        completedSessions: 2,
      );

      expect(layout.plotCount, 12);
    });

    test('holds open a plot the item is standing in', () {
      // REQ-040's "expanding capacity", and the case that makes it matter: a
      // garden of sixteen plots with an item in the sixteenth, and a user who
      // has done no more sessions. The plot stays, because the alternative is
      // an arrangement that vanishes.
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
      // A row this app could not have written — placement checks both tables —
      // and the rule if one ever arrives: the plant wins, because a plant is a
      // session somebody sat through.
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
          reason: 'a plot the garden has not unlocked is not somewhere to put '
              'anything');
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
