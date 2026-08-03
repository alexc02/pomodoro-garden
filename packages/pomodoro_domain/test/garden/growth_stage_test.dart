import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// Each threshold checked at the value and just either side.
void main() {
  /// Small enough that no real progress falls between, big enough to survive
  /// float division.
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

    test('thresholds are 0, 0.2, 0.5, 0.8 and 1', () {
      expect(GrowthStage.seed.threshold, 0.0);
      expect(GrowthStage.sprout.threshold, 0.2);
      expect(GrowthStage.young.threshold, 0.5);
      expect(GrowthStage.maturing.threshold, 0.8);
      expect(GrowthStage.mature.threshold, 1.0);
    });
  });

  group('outside 0 to 1', () {
    // Progress is normally clamped already, but this should never throw.
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
      // Would come from dividing by a zero-length session.
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

    test('are the five stages, in order', () {
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
