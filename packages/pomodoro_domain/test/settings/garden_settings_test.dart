import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('defaults', () {
    test('first run is a 25-minute session, a 5-minute break, long break '
        'after 4', () {
      // REQ-002 and REQ-030. Written out rather than compared to a constant so
      // that changing the defaults has to change this line too.
      expect(GardenSettings.defaults.sessionLength, const Duration(minutes: 25));
      expect(GardenSettings.defaults.breakLength, const Duration(minutes: 5));
      expect(GardenSettings.defaults.longBreakAfter, 4);
    });

    test('haptics are on until the user turns them off', () {
      // REQ-037. On by default because the growth haptic is part of how the
      // plant is noticed at all when the phone is face down.
      expect(GardenSettings.defaults.hapticsEnabled, isTrue);
    });

    test('the live session surface is on until the user turns it off', () {
      // REQ-033. On by default because it is the thing the app is for once the
      // phone is face down, and a user who has never opened settings should
      // still see their session on the lock screen.
      expect(GardenSettings.defaults.liveSurfaceEnabled, isTrue);
    });

    test('quiet mode is off until the user asks for it', () {
      // REQ-014, and the one default in here that is a rule rather than a
      // preference: quiet mode decides which of the user's calls they miss,
      // and nothing decides that on their behalf. The hint about it has not
      // been dismissed by somebody who has never seen it.
      expect(GardenSettings.defaults.quietModeEnabled, isFalse);
      expect(GardenSettings.defaults.quietModeHintDismissed, isFalse);
    });

    test('onboarding has not been seen on a first run', () {
      // REQ-003. The default is what a device with no settings row means, and
      // a device with no settings row is a device the app has never opened —
      // so this is the one field whose default *is* the trigger for a screen.
      expect(GardenSettings.defaults.onboardingCompleted, isFalse);
    });

    test('the defaults are themselves in range', () {
      expect(
        SettingsRanges.sessionLength.contains(
          GardenSettings.defaults.sessionLength,
        ),
        isTrue,
      );
      expect(
        SettingsRanges.breakLength.contains(
          GardenSettings.defaults.breakLength,
        ),
        isTrue,
      );
      expect(
        SettingsRanges.longBreakAfter.contains(
          GardenSettings.defaults.longBreakAfter,
        ),
        isTrue,
      );
    });
  });

  group('ranges', () {
    test('cover REQ-030 exactly', () {
      expect(SettingsRanges.sessionLength.min, const Duration(minutes: 5));
      expect(SettingsRanges.sessionLength.max, const Duration(minutes: 120));
      expect(SettingsRanges.breakLength.min, const Duration(minutes: 1));
      expect(SettingsRanges.breakLength.max, const Duration(minutes: 30));
      expect(SettingsRanges.longBreakAfter.min, 2);
      expect(SettingsRanges.longBreakAfter.max, 6);
    });

    test('the bounds are inside the range they bound', () {
      const range = SettingRange(min: 2, max: 6);

      expect(range.contains(2), isTrue);
      expect(range.contains(6), isTrue);
      expect(range.contains(1), isFalse);
      expect(range.contains(7), isFalse);
    });

    test('clamping pulls a value to the nearest bound', () {
      const range = SettingRange(min: 2, max: 6);

      expect(range.clamp(1), 2);
      expect(range.clamp(4), 4);
      expect(range.clamp(9), 6);
    });
  });

  group('changing a setting', () {
    test('changes only that setting', () {
      final changed = GardenSettings.defaults.withSessionLength(
        const Duration(minutes: 50),
      );

      expect(changed.sessionLength, const Duration(minutes: 50));
      expect(changed.breakLength, GardenSettings.defaults.breakLength);
      expect(changed.longBreakAfter, GardenSettings.defaults.longBreakAfter);
    });

    test('turning haptics off changes only that', () {
      final quiet = GardenSettings.defaults.withHaptics(enabled: false);

      expect(quiet.hapticsEnabled, isFalse);
      expect(quiet.sessionLength, GardenSettings.defaults.sessionLength);
      expect(quiet.breakLength, GardenSettings.defaults.breakLength);
      expect(quiet.longBreakAfter, GardenSettings.defaults.longBreakAfter);
    });

    test('turning the live surface off changes only that', () {
      // In particular it does not touch haptics. REQ-033 makes this a switch
      // about what the *lock screen* shows, and a user who turns it off has
      // said nothing about whether their phone may buzz.
      final dark = GardenSettings.defaults.withLiveSurface(enabled: false);

      expect(dark.liveSurfaceEnabled, isFalse);
      expect(dark.hapticsEnabled, GardenSettings.defaults.hapticsEnabled);
      expect(dark.sessionLength, GardenSettings.defaults.sessionLength);
    });

    test('finishing onboarding changes only that', () {
      final seen = GardenSettings.defaults.withOnboardingCompleted();

      expect(seen.onboardingCompleted, isTrue);
      expect(seen.sessionLength, GardenSettings.defaults.sessionLength);
      expect(seen.hapticsEnabled, GardenSettings.defaults.hapticsEnabled);
    });

    test('onboarding can be put back, which is what a reset is', () {
      // The only setter in here that undoes something the user did, and it
      // exists for the debug affordance rather than for them: onboarding is
      // shown once, and a build nobody can re-run it on is a build nobody can
      // check it in. See the settings screen's Onboarding (debug) section.
      final again = GardenSettings.defaults
          .withOnboardingCompleted()
          .withOnboardingReset();

      expect(again.onboardingCompleted, isFalse);
      expect(again, GardenSettings.defaults);
    });

    test('leaves the settings it was called on alone', () {
      const original = GardenSettings.defaults;

      original.withSessionLength(const Duration(minutes: 50));

      expect(original.sessionLength, const Duration(minutes: 25));
    });

    test('clamps rather than throwing', () {
      // A value out of range reaches here from two directions: a stored row
      // written by a build whose bounds differed, and a slider a later ticket
      // wires up wrong. Neither is worth crashing the app over, and neither
      // should be allowed to hand SessionMachine a zero-length session.
      expect(
        GardenSettings.defaults.withSessionLength(Duration.zero).sessionLength,
        const Duration(minutes: 5),
      );
      expect(
        GardenSettings.defaults
            .withSessionLength(const Duration(hours: 9))
            .sessionLength,
        const Duration(minutes: 120),
      );
      expect(
        GardenSettings.defaults.withBreakLength(Duration.zero).breakLength,
        const Duration(minutes: 1),
      );
      expect(GardenSettings.defaults.withLongBreakAfter(0).longBreakAfter, 2);
      expect(GardenSettings.defaults.withLongBreakAfter(99).longBreakAfter, 6);
    });

    test('keeps a length that is not a whole number of minutes', () {
      // The sliders move in minutes, but nothing here rounds: ADR 0003 keeps
      // seconds all the way to the column so a sub-minute QA session works.
      expect(
        GardenSettings.defaults
            .withSessionLength(const Duration(minutes: 5, seconds: 30))
            .sessionLength,
        const Duration(minutes: 5, seconds: 30),
      );
    });
  });

  group('break presets', () {
    test('are REQ-007 short, standard and long', () {
      expect(
        BreakPreset.values.map((p) => (p.label, p.length)),
        [
          ('Short', const Duration(minutes: 5)),
          ('Standard', const Duration(minutes: 10)),
          ('Long', const Duration(minutes: 15)),
        ],
      );
    });

    test('every preset is a length the break slider could also reach', () {
      for (final preset in BreakPreset.values) {
        expect(
          SettingsRanges.breakLength.contains(preset.length),
          isTrue,
          reason: '${preset.label} is outside the break range',
        );
      }
    });

    test('applying one sets the break length and nothing else', () {
      final long = GardenSettings.defaults.withBreakPreset(BreakPreset.long);

      expect(long.breakLength, const Duration(minutes: 15));
      expect(long.sessionLength, GardenSettings.defaults.sessionLength);
    });

    test('the long break still follows the break: Long gives thirty', () {
      // REQ-007 names the ordinary break's presets. The long break is derived
      // from whichever one is picked, three times over and capped at 30.
      expect(
        GardenSettings.defaults.withBreakPreset(BreakPreset.long)
            .longBreakLength,
        const Duration(minutes: 30),
      );
    });

    test('settings know which break preset they are on, if any', () {
      expect(GardenSettings.defaults.breakPreset, BreakPreset.short);
      expect(
        GardenSettings.defaults
            .withBreakLength(const Duration(minutes: 7))
            .breakPreset,
        isNull,
      );
    });
  });

  group('presets', () {
    test('are REQ-006 short, classic and deep', () {
      expect(
        SessionPreset.values.map((p) => (p.label, p.length)),
        [
          ('Short', const Duration(minutes: 15)),
          ('Classic', const Duration(minutes: 25)),
          ('Deep', const Duration(minutes: 50)),
        ],
      );
    });

    test('every preset is a length the custom control could also reach', () {
      for (final preset in SessionPreset.values) {
        expect(
          SettingsRanges.sessionLength.contains(preset.length),
          isTrue,
          reason: '${preset.label} is outside the custom range',
        );
      }
    });

    test('applying one sets the session length and nothing else', () {
      final deep = GardenSettings.defaults.withPreset(SessionPreset.deep);

      expect(deep.sessionLength, const Duration(minutes: 50));
      expect(deep.breakLength, GardenSettings.defaults.breakLength);
    });

    test('settings know which preset they are on, if any', () {
      // What the screen needs to show a preset as selected — and to show none
      // of them as selected once the user has moved the slider off one.
      expect(GardenSettings.defaults.preset, SessionPreset.classic);
      expect(
        GardenSettings.defaults
            .withSessionLength(const Duration(minutes: 37))
            .preset,
        isNull,
      );
    });
  });

  group('equality', () {
    test('two settings with the same values are the same settings', () {
      // Riverpod hands the same value out to every watcher; if these compared
      // by identity, saving a setting would repaint every screen that reads
      // one whether or not anything about it changed.
      expect(
        GardenSettings.defaults.withLongBreakAfter(4),
        GardenSettings.defaults,
      );
      expect(
        GardenSettings.defaults.withLongBreakAfter(4).hashCode,
        GardenSettings.defaults.hashCode,
      );
    });

    test('a difference in any one field is a difference', () {
      expect(
        GardenSettings.defaults.withLongBreakAfter(3),
        isNot(GardenSettings.defaults),
      );
      expect(
        GardenSettings.defaults.withBreakLength(const Duration(minutes: 9)),
        isNot(GardenSettings.defaults),
      );
      expect(
        GardenSettings.defaults.withSessionLength(const Duration(minutes: 9)),
        isNot(GardenSettings.defaults),
      );
      expect(
        GardenSettings.defaults.withHaptics(enabled: false),
        isNot(GardenSettings.defaults),
      );
      expect(
        GardenSettings.defaults.withLiveSurface(enabled: false),
        isNot(GardenSettings.defaults),
      );
      expect(
        GardenSettings.defaults.withQuietMode(enabled: true),
        isNot(GardenSettings.defaults),
      );
      expect(
        GardenSettings.defaults.withQuietModeHintDismissed(),
        isNot(GardenSettings.defaults),
      );
      expect(
        GardenSettings.defaults.withOnboardingCompleted(),
        isNot(GardenSettings.defaults),
      );
    });
  });
}
