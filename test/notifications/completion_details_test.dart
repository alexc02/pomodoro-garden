import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/feedback/end_sound_player.dart';
import 'package:pomodoro_garden/src/notifications/local_session_notifications.dart';

/// How REQ-031's choice reaches the notification, on both platforms.
///
/// This is the half of ticket 25 that a workstation can actually check.
/// `LocalSessionNotifications` is a call into a plugin that wants a phone; what
/// it *hands* that plugin is decided by the functions below, and those are
/// ordinary values. What is still unwitnessed is whether either operating
/// system then plays the file — see `docs/ambience.md`.
void main() {
  group('Android posts on a channel per sound', () {
    test('because a channel\'s sound cannot be changed after it is created',
        () {
      // The whole reason there are six channels rather than one. If this ever
      // collapses to a single id, changing the setting will silently keep
      // playing whatever the channel was created with.
      final ids = EndSound.values.map(completionChannelId).toSet();

      expect(ids, hasLength(EndSound.values.length));
    });

    test('and the wind chime keeps the id it has had since ticket 06', () {
      // The default sound, so it is the channel almost every user already has.
      // A new id would throw away everything they have decided about this
      // app's notifications.
      expect(completionChannelId(EndSound.windChime), 'session_completion');
    });

    test('each channel is named for its own sound', () {
      // A user who tries three sounds ends up with three rows in their system
      // settings. Three rows called the same thing would be worse than none.
      final names = EndSound.values.map(completionChannelName).toSet();

      expect(names, hasLength(EndSound.values.length));
      for (final sound in EndSound.values) {
        expect(completionChannelName(sound), contains('Finished sessions'));
      }
      expect(completionChannelName(EndSound.singingBowl),
          contains('Singing bowl'));
      // "Finished sessions — None" reads as a missing value rather than as a
      // choice, which is the one place the enum's own label is the wrong word.
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
        // `Library/Sounds` is where `_installIosSound` puts it, and
        // `UNNotificationSound` will not take an AAC file from there.
        expect(ios.sound, endsWith('.wav'));
      }
    });
  });

  group('None is silent and still says something', () {
    test('Android is asked for no sound, explicitly', () {
      final android = completionDetails(EndSound.none).android!;

      // Both halves: `sound: null` on its own means *the channel default*,
      // which is a sound.
      expect(android.sound, isNull);
      expect(android.playSound, isFalse);
    });

    test('iOS is asked for no sound, explicitly', () {
      final ios = completionDetails(EndSound.none).iOS!;

      expect(ios.sound, isNull);
      expect(ios.presentSound, isFalse);
    });

    test('and the notification still arrives, as loudly as any other', () {
      // The announcement is the news, not the noise. Turning the sound off must
      // not turn the notice into something the user has to go looking for.
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
