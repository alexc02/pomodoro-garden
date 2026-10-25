import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/ambience/audio_interruptions.dart';

/// Two of ticket 10's criteria are about things that cannot be made to happen
/// in a test: a phone call arriving mid-session, and a Bluetooth speaker
/// walking out of range. The decisions those events lead to are pulled out into
/// `AudioInterruptions` precisely so that they can be asserted here, leaving
/// only "does the platform send the event" on the device side of the line.
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
      // `unknown` at the end is the platform saying something else is playing
      // now. Rain fading back in over the podcast the user just started would
      // be this app deciding it mattered more than what they chose.
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
      // What every media app on both platforms does, and what a focus app's
      // user wants twice over: the rain they were listening to privately must
      // not come out of the phone into the room they are sitting in.
      expect(AudioInterruptions().routeLost(), BedResponse.hold);
    });

    test('put back start it again', () {
      final route = AudioInterruptions();

      expect(route.routeLost(), BedResponse.hold);
      expect(route.routeRegained(), BedResponse.resume);
    });

    test('a route arriving that took nothing away changes nothing', () {
      // A speaker appearing while the bed is playing happily. Resuming here
      // would be a volume ramp for no reason.
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

      // The whole reason this is a state machine and not a function: the call
      // ending must not put rain through a speaker the user walked away from.
      expect(route.interrupted(ended(AudioInterruptionType.pause)), isNull);
      expect(route.routeRegained(), BedResponse.resume);
    });

    test('do not survive the bed they were about', () {
      final route = AudioInterruptions();

      // The session ended while the headphones were out. Carried into the next
      // session, the first phone call would find the bed already "held", do
      // nothing about it, and leave rain playing over the caller.
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

      // Not a lift over a bed that is playing at full level already.
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
