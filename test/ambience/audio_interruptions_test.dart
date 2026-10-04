import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/ambience/audio_interruptions.dart';

// Calls and lost Bluetooth routes can't be staged in a test, so the decisions
// live in `AudioInterruptions` and are tested here. Whether the platform sends
// the events is a device check.
void main() {
  AudioInterruptionEvent began(AudioInterruptionType type) =>
      AudioInterruptionEvent(true, type);
  AudioInterruptionEvent ended(AudioInterruptionType type) =>
      AudioInterruptionEvent(false, type);

  group('a phone call', () {
    test('holds the bed, and hands it back afterwards', () {
      final route = AudioInterruptions();

      // Android sends `pause` for a transient loss; iOS sends `unknown` when an
      // interruption begins and `pause` at the end when the system said the app
      // may resume.
      expect(route.interrupted(began(AudioInterruptionType.pause)),
          BedResponse.hold);
      expect(route.interrupted(ended(AudioInterruptionType.pause)),
          BedResponse.resume);
    });

    test('taken permanently leaves the bed down', () {
      final route = AudioInterruptions();

      expect(route.interrupted(began(AudioInterruptionType.unknown)),
          BedResponse.hold);
      // `unknown` at the end means something else is playing now; don't fade
      // the bed back in over it.
      expect(route.interrupted(ended(AudioInterruptionType.unknown)), isNull);
    });

    test('is not a second hold when the bed is already down', () {
      final route = AudioInterruptions();

      expect(route.interrupted(began(AudioInterruptionType.pause)),
          BedResponse.hold);
      expect(route.interrupted(began(AudioInterruptionType.pause)), isNull,
          reason: 'nothing to do to a bed that is already held');
    });
  });

  group('a navigation prompt', () {
    test('ducks the bed rather than stopping it', () {
      final route = AudioInterruptions();

      expect(route.interrupted(began(AudioInterruptionType.duck)),
          BedResponse.duck);
      expect(route.interrupted(ended(AudioInterruptionType.duck)),
          BedResponse.lift);
    });

    test('does not duck twice, or lift what was never ducked', () {
      final route = AudioInterruptions();

      expect(route.interrupted(began(AudioInterruptionType.duck)),
          BedResponse.duck);
      expect(route.interrupted(began(AudioInterruptionType.duck)), isNull);
      expect(route.interrupted(ended(AudioInterruptionType.duck)),
          BedResponse.lift);
      expect(route.interrupted(ended(AudioInterruptionType.duck)), isNull);
    });
  });

  group('headphones', () {
    test('pulled out hold the bed', () {
      // Standard media behaviour: don't move private audio onto the speaker.
      expect(AudioInterruptions().routeLost(), BedResponse.hold);
    });

    test('put back start it again', () {
      final route = AudioInterruptions();

      expect(route.routeLost(), BedResponse.hold);
      expect(route.routeRegained(), BedResponse.resume);
    });

    test('a route arriving that took nothing away changes nothing', () {
      // Nothing was held, so nothing to resume.
      expect(AudioInterruptions().routeRegained(), isNull);
    });
  });

  group('two things at once', () {
    test('a call that ends while the headphones are still out leaves the bed '
        'down', () {
      final route = AudioInterruptions();

      expect(route.routeLost(), BedResponse.hold);
      expect(route.interrupted(began(AudioInterruptionType.pause)), isNull,
          reason: 'already held');

      // Why this is a state machine: the call ending mustn't resume the bed
      // through the speaker.
      expect(route.interrupted(ended(AudioInterruptionType.pause)), isNull);
      expect(route.routeRegained(), BedResponse.resume);
    });

    test('do not survive the bed they were about', () {
      final route = AudioInterruptions();

      // Carried over, the next call would find the bed already held and do
      // nothing.
      expect(route.routeLost(), BedResponse.hold);
      route.forget();

      expect(route.interrupted(began(AudioInterruptionType.pause)),
          BedResponse.hold);
      expect(route.interrupted(ended(AudioInterruptionType.pause)),
          BedResponse.resume);
    });

    test('and a duck does not survive it either', () {
      final route = AudioInterruptions();

      expect(route.interrupted(began(AudioInterruptionType.duck)),
          BedResponse.duck);
      route.forget();

      // The bed is already at full level.
      expect(route.interrupted(ended(AudioInterruptionType.duck)), isNull);
      expect(route.interrupted(began(AudioInterruptionType.duck)),
          BedResponse.duck);
    });

    test('and the other order comes out the same', () {
      final route = AudioInterruptions();

      expect(route.interrupted(began(AudioInterruptionType.pause)),
          BedResponse.hold);
      expect(route.routeLost(), isNull);
      expect(route.routeRegained(), isNull);
      expect(route.interrupted(ended(AudioInterruptionType.pause)),
          BedResponse.resume);
    });
  });
}
