import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// REQ-016's five stages, as a pure function of how far along the session is.
///
/// Every threshold is asserted at the value itself and either side of it. A
/// stage that advanced at 0.19999 rather than 0.2 would look identical on
/// screen and be wrong everywhere it was reasoned about.
void main() {
  /// A hair either side of a threshold — close enough that no real progress
  /// value falls between this and the threshold, far enough to survive the
  /// division that produced it.
  const hair = 1e-9;

  group('thresholds', () {
    test('a session that has not started is a seed', () {
      expect(GrowthStage.forProgress(0), GrowthStage.seed);
    });

    test('sprout at 20%', () {
      expect(GrowthStage.forProgress(0.2 - hair), GrowthStage.seed);
      expect(GrowthStage.forProgress(0.2), GrowthStage.sprout);
      expect(GrowthStage.forProgress(0.2 + hair), GrowthStage.sprout);
    });

    test('young at 50%', () {
      expect(GrowthStage.forProgress(0.5 - hair), GrowthStage.sprout);
      expect(GrowthStage.forProgress(0.5), GrowthStage.young);
      expect(GrowthStage.forProgress(0.5 + hair), GrowthStage.young);
    });

    test('maturing at 80%', () {
      expect(GrowthStage.forProgress(0.8 - hair), GrowthStage.young);
      expect(GrowthStage.forProgress(0.8), GrowthStage.maturing);
      expect(GrowthStage.forProgress(0.8 + hair), GrowthStage.maturing);
    });

    test('mature at 100%, and not a moment before', () {
      expect(GrowthStage.forProgress(1 - hair), GrowthStage.maturing);
      expect(GrowthStage.forProgress(1), GrowthStage.mature);
    });

    test('the thresholds are the ones REQ-016 names', () {
      expect(GrowthStage.seed.threshold, 0.0);
      expect(GrowthStage.sprout.threshold, 0.2);
      expect(GrowthStage.young.threshold, 0.5);
      expect(GrowthStage.maturing.threshold, 0.8);
      expect(GrowthStage.mature.threshold, 1.0);
    });
  });

  group('outside 0 to 1', () {
    // `SessionSnapshot.progress` is clamped to 0..1 already. The mapping is
    // total anyway, because a growth stage is the kind of thing that gets
    // asked for from places that have not clamped.
    test('progress past the end is still mature', () {
      expect(GrowthStage.forProgress(1.5), GrowthStage.mature);
      expect(GrowthStage.forProgress(double.infinity), GrowthStage.mature);
    });

    test('progress before the start is still a seed', () {
      expect(GrowthStage.forProgress(-0.5), GrowthStage.seed);
      expect(GrowthStage.forProgress(double.negativeInfinity),
          GrowthStage.seed);
    });

    test('a progress that is not a number is a seed', () {
      // Nothing produces this today; a division by a zero-length planned
      // duration would. A seed is the answer that shows nothing has grown,
      // which beats a stage picked by a comparison that is false either way.
      expect(GrowthStage.forProgress(double.nan), GrowthStage.seed);
    });
  });

  group('the stages themselves', () {
    test('advance monotonically with progress', () {
      var previous = GrowthStage.seed;

      for (var step = 0; step <= 1000; step++) {
        final stage = GrowthStage.forProgress(step / 1000);
        expect(stage.index, greaterThanOrEqualTo(previous.index),
            reason: 'progress ${step / 1000} went backwards');
        previous = stage;
      }

      expect(previous, GrowthStage.mature);
    });

    test('are the five REQ-016 names, in order', () {
      expect(GrowthStage.values, <GrowthStage>[
        GrowthStage.seed,
        GrowthStage.sprout,
        GrowthStage.young,
        GrowthStage.maturing,
        GrowthStage.mature,
      ]);
    });

    test('each has a label to show the user', () {
      expect(GrowthStage.maturing.label, 'Maturing');
      for (final stage in GrowthStage.values) {
        expect(stage.label, isNotEmpty);
      }
    });
  });
}
