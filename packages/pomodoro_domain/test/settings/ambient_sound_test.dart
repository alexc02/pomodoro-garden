import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the six', () {
    test('REQ-012 offers six beds and silence is one of them', () {
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
      // An earlier draft sold three of them. The app is free, so there is no
      // second list of beds anywhere and what the picker offers is `values` —
      // this is the test that would fail if a locked one came back without the
      // decision being made again. See `docs/adr/0021-…`.
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
      // A row written by a build that offered a seventh bed. Silence is the
      // answer that cannot be wrong: it plays nothing over anybody, and it is
      // what a user who has chosen nothing already has.
      expect(AmbientSound.named('thunderstorm'), AmbientSound.silence);
      expect(AmbientSound.named(''), AmbientSound.silence);
    });
  });

  group('as a setting', () {
    test('a first run is silent', () {
      // An app that started making rain at the first tap of START would have
      // decided something about the user's room.
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
      // The keeper watches `settingsProvider` for exactly this change, so a
      // value object that swallowed it would leave the bed on the last one.
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
