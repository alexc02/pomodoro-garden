import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

final DateTime _anchor = DateTime.utc(2026, 8, 11, 9, 41);

FocusSession _session({
  String id = 'session-1',
  Duration planned = const Duration(minutes: 25),
}) =>
    FocusSession(id: id, startedAt: _anchor, plannedDuration: planned);

void main() {
  group('growing', () {
    test('a session starts as a seed of the type its length earns', () {
      final growth = PlantGrowth.forSession(
        _session(planned: const Duration(minutes: 90)),
        progress: 0,
      );

      expect(growth.type, PlantType.largeTree);
      expect(growth.stage, GrowthStage.seed);
    });

    test('the stage follows progress', () {
      final session = _session();

      expect(PlantGrowth.forSession(session, progress: 0.19).stage,
          GrowthStage.seed);
      expect(PlantGrowth.forSession(session, progress: 0.2).stage,
          GrowthStage.sprout);
      expect(PlantGrowth.forSession(session, progress: 0.65).stage,
          GrowthStage.young);
      expect(PlantGrowth.forSession(session, progress: 1).stage,
          GrowthStage.mature);
    });

    test('the species is chosen once and never wavers', () {
      // The whole point: a user watches a plant grow for ninety minutes. It
      // must not become a different species at 50% because something asked
      // again.
      final session = _session(planned: const Duration(minutes: 90));
      final species = PlantGrowth.forSession(session, progress: 0).species;

      for (var step = 0; step <= 100; step++) {
        final growth = PlantGrowth.forSession(session, progress: step / 100);
        expect(growth.species, species, reason: 'at $step% progress');
        expect(growth.type, PlantType.largeTree);
      }
    });

    test('two sessions of the same length can grow different species', () {
      final species = {
        for (var id = 0; id < 40; id++)
          PlantGrowth.forSession(_session(id: 'session-$id'), progress: 1)
              .species,
      };

      expect(species.length, greaterThan(1));
    });

    test('growth compares by value, so an unchanged plant does not repaint',
        () {
      final session = _session();

      expect(
        PlantGrowth.forSession(session, progress: 0.3),
        PlantGrowth.forSession(session, progress: 0.4),
      );
      expect(
        PlantGrowth.forSession(session, progress: 0.3),
        isNot(PlantGrowth.forSession(session, progress: 0.6)),
      );
    });
  });

  group('planting', () {
    test('a completed session leaves a mature plant of what it grew', () {
      final session = _session(planned: const Duration(minutes: 45))
          .completedAt(_anchor.add(const Duration(minutes: 45)));

      final plant = Plant.fromSession(session, id: 'plant-1');

      expect(plant.id, 'plant-1');
      expect(plant.sessionId, 'session-1');
      expect(plant.type, PlantType.bush);
      expect(plant.stage, GrowthStage.mature);
      expect(plant.sessionDuration, const Duration(minutes: 45));
    });

    test('the plant is dated to when its seed went in, not when it finished',
        () {
      final session = _session().completedAt(
        _anchor.add(const Duration(minutes: 25)),
      );

      // The seed drops at the anchor. A session started at 23:50 and finished
      // at 00:15 was planted on the earlier day, which is the day the user
      // remembers doing the work.
      expect(Plant.fromSession(session, id: 'plant-1').plantedAt, _anchor);
    });

    test('the plant is the species the user watched grow', () {
      // The seam this ticket turns on: the growth on screen and the record in
      // the garden are the same plant, because both derive from the session.
      final session = _session(id: 'a-particular-session');
      final watched = PlantGrowth.forSession(session, progress: 0.5);

      final plant = Plant.fromSession(
        session.completedAt(_anchor.add(const Duration(minutes: 25))),
        id: 'plant-1',
      );

      expect(plant.species, watched.species);
      expect(plant.type, watched.type);
    });

    test('a session that did not complete grows nothing', () {
      // REQ and glossary both: completed is the only outcome that earns a
      // plant. A caller that got this wrong would quietly plant cancelled
      // sessions.
      expect(
        () => Plant.fromSession(_session(), id: 'plant-1'),
        throwsArgumentError,
      );
    });

    test('plants compare by value', () {
      final session = _session().completedAt(
        _anchor.add(const Duration(minutes: 25)),
      );

      expect(
        Plant.fromSession(session, id: 'plant-1'),
        Plant.fromSession(session, id: 'plant-1'),
      );
      expect(
        Plant.fromSession(session, id: 'plant-1'),
        isNot(Plant.fromSession(session, id: 'plant-2')),
      );
    });

    test('a plant a session grew is not a bonus plant', () {
      final session = _session().completedAt(
        _anchor.add(const Duration(minutes: 25)),
      );

      final plant = Plant.fromSession(session, id: 'plant-1');
      expect(plant.isBonus, isFalse);
      expect(plant.milestone, isNull);
      expect(plant.type, isNot(PlantType.bonus));
    });
  });

  group('awarding', () {
    test('a milestone leaves the plant REQ-021 names for it, fully grown', () {
      final plant = Plant.forMilestone(
        Milestone.oneHundred,
        id: 'plant-1',
        plantedAt: _anchor,
      );

      expect(plant.id, 'plant-1');
      expect(plant.milestone, Milestone.oneHundred);
      expect(plant.species, PlantSpecies.ancientOak);
      expect(plant.type, PlantType.bonus);
      // Nothing watched it grow, so the only stage it could honestly be in is
      // the one it arrives in.
      expect(plant.stage, GrowthStage.mature);
      expect(plant.plantedAt, _anchor);
    });

    test('a bonus plant belongs to no session', () {
      final plant = Plant.forMilestone(
        Milestone.ten,
        id: 'plant-1',
        plantedAt: _anchor,
      );

      // Both halves matter. The null session id is what keeps it out of
      // `plantForSession`, and the null duration is what keeps a card from
      // saying "0 minutes" about an award for ten sessions.
      expect(plant.sessionId, isNull);
      expect(plant.sessionDuration, isNull);
      expect(plant.isBonus, isTrue);
    });

    test('every milestone awards a plant that can be told apart from the rest',
        () {
      final awarded = [
        for (final milestone in Milestone.values)
          Plant.forMilestone(
            milestone,
            id: 'plant-${milestone.sessions}',
            plantedAt: _anchor,
          ),
      ];

      expect(awarded.map((plant) => plant.species).toSet(), hasLength(7));
      for (final plant in awarded) {
        expect(plant.type, PlantType.bonus);
      }
    });

    test('a bonus plant takes the plot it is given, and keeps its milestone '
        'when moved', () {
      const plot = GardenPlot(2, -1);
      final plant = Plant.forMilestone(
        Milestone.fifty,
        id: 'plant-1',
        plantedAt: _anchor,
        plot: plot,
      );

      expect(plant.plot, plot);
      // ADR 0006: a full garden leaves the award with nowhere to stand rather
      // than losing it. Moving it must not lose which milestone earned it.
      expect(plant.inPlot(null).plot, isNull);
      expect(plant.inPlot(null).milestone, Milestone.fifty);
      expect(plant.inPlot(null).isBonus, isTrue);
    });

    test('two awards are the same plant only if they are the same row', () {
      final one = Plant.forMilestone(
        Milestone.ten,
        id: 'plant-1',
        plantedAt: _anchor,
      );

      expect(
        one,
        Plant.forMilestone(Milestone.ten, id: 'plant-1', plantedAt: _anchor),
      );
      expect(
        one,
        isNot(
          Plant.forMilestone(
            Milestone.twentyFive,
            id: 'plant-1',
            plantedAt: _anchor,
          ),
        ),
      );
    });
  });
}
