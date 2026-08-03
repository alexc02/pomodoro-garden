import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the six', () {
    test('six sounds, and silence is one of them', () {
      expect(AmbientSound.values, hasLength(6));
      expect(AmbientSound.values, contains(AmbientSound.silence));
    });

    test('every bed has a label of its own', () {
      final labels = AmbientSound.values.map((sound) => sound.label).toSet();
      expect(labels, hasLength(AmbientSound.values.length));
      expect(labels, isNot(contains('')));
    });
  });

  group('all six', () {
    test('are the user\'s, with nothing held back', () {
      // All free now (ADR 0005): the picker offers `values` and nothing else.
      expect(AmbientSound.values, hasLength(6));
    });
  });

  group('reading a stored name', () {
    test('round-trips every bed', () {
      for (final sound in AmbientSound.values) {
        expect(AmbientSound.named(sound.name), sound);
      }
    });

    test('a name this build has never heard of reads as silence', () {
      // e.g. a row from a build that had a seventh sound.
      expect(AmbientSound.named('thunderstorm'), AmbientSound.silence);
      expect(AmbientSound.named(''), AmbientSound.silence);
    });
  });

  group('as a setting', () {
    test('a first run is silent', () {
      expect(GardenSettings.defaults.ambientSound, AmbientSound.silence);
    });

    test('choosing a bed changes nothing else', () {
      final chosen =
          GardenSettings.defaults.withAmbientSound(AmbientSound.rain);

      expect(chosen.ambientSound, AmbientSound.rain);
      expect(chosen.sessionLength, GardenSettings.defaults.sessionLength);
      expect(chosen.hapticsEnabled, GardenSettings.defaults.hapticsEnabled);
    });

    test('settings that differ only by their bed are not the same settings',
        () {
      // The ambience keeper watches `settingsProvider` for this change.
      expect(
        GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
        isNot(GardenSettings.defaults.withAmbientSound(AmbientSound.forest)),
      );
      expect(
        GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
        GardenSettings.defaults.withAmbientSound(AmbientSound.rain),
      );
    });
  });
}
