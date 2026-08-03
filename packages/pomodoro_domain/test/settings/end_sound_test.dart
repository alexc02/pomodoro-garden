import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the six', () {
    test('six sounds, and None is one of them', () {
      expect(EndSound.values, hasLength(6));
      expect(EndSound.values, contains(EndSound.none));
    });

    test('in picker order, default first', () {
      // The picker shows `values` in this order.
      expect(EndSound.values.map((sound) => sound.label), [
        'Wind chime',
        'Soft bell',
        'Birdsong',
        'Singing bowl',
        'Ocean wave',
        'None',
      ]);
    });

    test('and exactly one of them is silence', () {
      expect(EndSound.values.where((sound) => sound.isSilent), [EndSound.none]);
    });

    test('every sound has a label of its own', () {
      final labels = EndSound.values.map((sound) => sound.label).toSet();
      expect(labels, hasLength(EndSound.values.length));
      expect(labels, isNot(contains('')));
    });
  });

  group('reading a stored name', () {
    test('round-trips every sound', () {
      for (final sound in EndSound.values) {
        expect(EndSound.named(sound.name), sound);
      }
    });

    test('a name this build has never heard of reads as the wind chime', () {
      // Opposite of the ambient fallback: reading an unknown row as `none`
      // would silently turn someone's sound off.
      expect(EndSound.named('thunderclap'), EndSound.windChime);
      expect(EndSound.named(''), EndSound.windChime);
    });
  });

  group('as a setting', () {
    test('a first run chimes', () {
      expect(GardenSettings.defaults.endSound, EndSound.windChime);
    });

    test('choosing a sound changes nothing else', () {
      final chosen = GardenSettings.defaults.withEndSound(EndSound.birdsong);

      expect(chosen.endSound, EndSound.birdsong);
      expect(chosen.ambientSound, GardenSettings.defaults.ambientSound);
      expect(chosen.hapticsEnabled, GardenSettings.defaults.hapticsEnabled);
      expect(chosen.sessionLength, GardenSettings.defaults.sessionLength);
    });

    test('settings that differ only by their end sound are not the same', () {
      expect(
        GardenSettings.defaults.withEndSound(EndSound.softBell),
        isNot(GardenSettings.defaults.withEndSound(EndSound.oceanWave)),
      );
      expect(
        GardenSettings.defaults.withEndSound(EndSound.softBell),
        GardenSettings.defaults.withEndSound(EndSound.softBell),
      );
    });

    test('None is a choice rather than a switch being off', () {
      // No separate enabled flag: off is just `none`.
      final off = GardenSettings.defaults.withEndSound(EndSound.none);

      expect(off.endSound, EndSound.none);
      expect(EndSound.named(off.endSound.name), EndSound.none);
    });
  });

  group('analytics records the change', () {
    test('as a settings_changed with a key of its own', () {
      final events = AnalyticsEvent.forSettingsChange(
        before: GardenSettings.defaults,
        after: GardenSettings.defaults.withEndSound(EndSound.singingBowl),
      );

      expect(events, hasLength(1));
      final change = events.single as SettingsChanged;
      expect(change.setting, SettingKey.endSound);
      expect(change.setting.recorded, 'end_sound');
      expect(change.oldValue, 'windChime');
      expect(change.newValue, 'singingBowl');
    });

    test('and says nothing when the sound has not moved', () {
      expect(
        AnalyticsEvent.forSettingsChange(
          before: GardenSettings.defaults.withEndSound(EndSound.birdsong),
          after: GardenSettings.defaults.withEndSound(EndSound.birdsong),
        ),
        isEmpty,
      );
    });

    test('unlike the bed, it gets no second event of its own', () {
      // Ambient sound gets a dedicated event for popularity; end sound doesn't.
      final events = AnalyticsEvent.forSettingsChange(
        before: GardenSettings.defaults,
        after: GardenSettings.defaults.withEndSound(EndSound.none),
      );

      expect(events.whereType<SettingsChanged>(), hasLength(1));
      expect(events, hasLength(1));
    });
  });
}
