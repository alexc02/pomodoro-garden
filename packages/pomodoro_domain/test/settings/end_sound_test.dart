import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the six', () {
    test('REQ-031 offers six sounds and None is one of them', () {
      expect(EndSound.values, hasLength(6));
      expect(EndSound.values, contains(EndSound.none));
    });

    test('in the order REQ-031 names them, with the default first', () {
      // The picker offers `values`, so this list *is* the order on screen.
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
      // The question the player, the picker and both platforms' notification
      // dressing all ask. One place answers it, so they cannot disagree.
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
      // The opposite fallback to the bed's, and deliberately: reading an
      // unknown row as `none` would quietly turn somebody's completion sound
      // off, where the chime is what the app has made since ticket 06.
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
      // There is no `withEndSoundEnabled`, and this is the test that would fail
      // if one arrived: turning the sound off is picking `none`, which stores
      // and reads back exactly like the other five.
      final off = GardenSettings.defaults.withEndSound(EndSound.none);

      expect(off.endSound, EndSound.none);
      expect(EndSound.named(off.endSound.name), EndSound.none);
    });
  });

  group('§7.1 records the change', () {
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
      // `AmbientSoundToggled` exists because §7.1 asks "which beds are popular"
      // separately from "what do people customise". §7.1 asks no such question
      // about the end sound, so one event is the whole of it.
      final events = AnalyticsEvent.forSettingsChange(
        before: GardenSettings.defaults,
        after: GardenSettings.defaults.withEndSound(EndSound.none),
      );

      expect(events.whereType<SettingsChanged>(), hasLength(1));
      expect(events, hasLength(1));
    });
  });
}
