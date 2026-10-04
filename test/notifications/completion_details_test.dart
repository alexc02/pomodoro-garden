import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/feedback/end_sound_player.dart';
import 'package:pip_garden/src/notifications/local_session_notifications.dart';

// What the app hands the notification plugin for each end sound. Whether the
// OS actually plays the file is a device check; see `docs/ambience.md`.
void main() {
  group('Android posts on a channel per sound', () {
    test('since a channel\'s sound is fixed once it is created',
        () {
      // One shared id would keep playing whatever sound it was created with.
      final ids = EndSound.values.map(completionChannelId).toSet();

      expect(ids, hasLength(EndSound.values.length));
    });

    test('and the wind chime keeps its original channel id', () {
      // The default, so most users already have this channel. A new id would
      // reset their notification settings.
      expect(completionChannelId(EndSound.windChime), 'session_completion');
    });

    test('each channel is named for its own sound', () {
      // Each one shows up as its own row in system settings.
      final names = EndSound.values.map(completionChannelName).toSet();

      expect(names, hasLength(EndSound.values.length));
      for (final sound in EndSound.values) {
        expect(completionChannelName(sound), contains('Finished sessions'));
      }
      expect(completionChannelName(EndSound.singingBowl),
          contains('Singing bowl'));
      // "None" would read as a missing value.
      expect(completionChannelName(EndSound.none), contains('silent'));
      expect(completionChannelName(EndSound.none), isNot(contains('None')));
    });

    test('and every channel carries the raw resource for its sound', () {
      for (final sound in EndSound.values) {
        final android = completionDetails(sound).android!;
        if (sound == EndSound.none) continue;

        expect(android.playSound, isTrue);
        expect(
          android.sound,
          isA<RawResourceAndroidNotificationSound>().having(
            (raw) => raw.sound,
            'resource',
            endSoundAndroidResource(sound),
          ),
          reason: '${sound.label} is not on its own file',
        );
      }
    });
  });

  group('iOS names the file on the notification', () {
    test('so every sound is asked for by name', () {
      for (final sound in EndSound.values) {
        final ios = completionDetails(sound).iOS!;
        if (sound == EndSound.none) continue;

        expect(ios.presentSound, isTrue);
        expect(ios.sound, endSoundIosSound(sound));
        // `UNNotificationSound` won't take AAC from `Library/Sounds`.
        expect(ios.sound, endsWith('.wav'));
      }
    });
  });

  group('None is silent and still says something', () {
    test('Android is asked for no sound, explicitly', () {
      final android = completionDetails(EndSound.none).android!;

      // `sound: null` alone means the channel default, which is a sound.
      expect(android.sound, isNull);
      expect(android.playSound, isFalse);
    });

    test('iOS is asked for no sound, explicitly', () {
      final ios = completionDetails(EndSound.none).iOS!;

      expect(ios.sound, isNull);
      expect(ios.presentSound, isFalse);
    });

    test('and the notification still arrives, as loudly as any other', () {
      // Turning the sound off shouldn't make the notice less prominent.
      final silent = completionDetails(EndSound.none).android!;
      final chimed = completionDetails(EndSound.windChime).android!;

      expect(silent.importance, chimed.importance);
      expect(silent.priority, chimed.priority);
      expect(silent.category, chimed.category);
      expect(completionDetails(EndSound.none).iOS!.interruptionLevel,
          completionDetails(EndSound.windChime).iOS!.interruptionLevel);
    });
  });
}
