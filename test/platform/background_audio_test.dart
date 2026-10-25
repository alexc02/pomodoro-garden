import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/audio/app_audio_session.dart';

/// REQ-012 asks for a bed that goes on playing behind a locked screen, and on
/// iOS that is two things that live nowhere near each other: an `Info.plist`
/// key and an audio session category. Either one alone is silence the moment
/// the phone locks, and neither is something a widget test can notice — the
/// failure is on a device, in a pocket, several minutes into a session.
///
/// So they are asserted here, against the files themselves.
///
/// What this cannot say is whether iOS honours them. That is a device
/// observation and it is recorded as one — see the ticket's verification gaps
/// and `docs/ambience.md`.
void main() {
  group('iOS lets the app play in the background', () {
    late String plist;

    setUpAll(() {
      plist = File('ios/Runner/Info.plist').readAsStringSync();
    });

    test('UIBackgroundModes declares audio', () {
      expect(
        plist,
        contains('<key>UIBackgroundModes</key>'),
        reason: 'Without this iOS suspends the app at the lock screen and the '
            'bed stops, whatever category the session is on.',
      );
      // The array immediately after the key, so a mode declared for something
      // else entirely would not satisfy this.
      final modes = RegExp(
        r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist)?.group(1);

      expect(modes, isNotNull);
      expect(modes, contains('<string>audio</string>'));
    });

    test('and asks for nothing else', () {
      final modes = RegExp(
        r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist)!.group(1)!;

      // Every extra background mode is something App Review asks about, and
      // this app plays — it does not record, fetch or navigate.
      expect(
        RegExp(r'<string>').allMatches(modes),
        hasLength(1),
        reason: 'Adding a background mode is a decision for the ticket that '
            'needs it, with its own reason in the plist.',
      );
    });
  });

  group('the two audio uses', () {
    test('a bed plays under a category that survives the lock screen', () {
      // `playback` is the only iOS category that keeps playing while the app is
      // in the background. `ambient` — which is what the chime wants, and what
      // ticket 06 configured — stops.
      expect(
        AppAudioSession.configurationFor(AudioUse.ambientBed)
            .avAudioSessionCategory,
        AVAudioSessionCategory.playback,
      );
    });

    test('and the chime still loses to the silent switch', () {
      // Ticket 06's decision, and this ticket must not have quietly reversed
      // it: with no bed playing, the app is on the category the ring switch
      // mutes. A focus app that chimed in a meeting because the user had
      // silenced their phone would have earned every word of the review.
      final chime = AppAudioSession.configurationFor(AudioUse.chimeOnly);

      expect(chime.avAudioSessionCategory, AVAudioSessionCategory.ambient);
      expect(
        chime.avAudioSessionCategoryOptions,
        AVAudioSessionCategoryOptions.mixWithOthers,
        reason: 'a user who focuses to music should still have music',
      );
    });

    test('a bed takes the audio rather than mixing under it', () {
      // REQ-012's "honour the user's choice when music is already playing":
      // they chose rain over the music, from a picker that showed them what
      // they were choosing. Mixing would give them both at once for two hours.
      final bed = AppAudioSession.configurationFor(AudioUse.ambientBed);

      expect(
        bed.avAudioSessionCategoryOptions,
        AVAudioSessionCategoryOptions.none,
      );
      expect(
        bed.androidAudioFocusGainType,
        AndroidAudioFocusGainType.gain,
        reason: 'full focus is what makes a call able to take it and give it '
            'back',
      );
    });

    test('a duckable interruption arrives as a duck, not as a stop', () {
      // A navigation prompt is three seconds long. A bed that stopped and
      // restarted around it would make more of the interruption than the
      // interruption did — and `AudioInterruptions` only ever sees a duck if
      // this is false.
      expect(
        AppAudioSession.configurationFor(AudioUse.ambientBed)
            .androidWillPauseWhenDucked,
        isFalse,
      );
    });
  });
}
