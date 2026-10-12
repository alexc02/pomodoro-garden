import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/audio/app_audio_session.dart';

// Background audio on iOS needs both an Info.plist key and the right audio
// session category; either alone goes silent at the lock screen. Whether iOS
// honours them is a device check (`docs/ambience.md`).
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
      // The array right after the key, not some other array.
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

      // Every extra background mode is something App Review asks about.
      expect(
        RegExp(r'<string>').allMatches(modes),
        hasLength(1),
        reason: 'Only add a background mode with a reason for it.',
      );
    });
  });

  group('the two audio uses', () {
    test('a bed plays under a category that survives the lock screen', () {
      // `playback` is the only iOS category that keeps going in the
      // background. `ambient` (what the chime uses) stops.
      expect(
        AppAudioSession.configurationFor(AudioUse.ambientBed)
            .avAudioSessionCategory,
        AVAudioSessionCategory.playback,
      );
    });

    test('and the chime still loses to the silent switch', () {
      // With no bed playing, the app stays on the category the ring switch
      // mutes. Chiming in a meeting on a silenced phone would be bad.
      final chime = AppAudioSession.configurationFor(AudioUse.chimeOnly);

      expect(chime.avAudioSessionCategory, AVAudioSessionCategory.ambient);
      expect(
        chime.avAudioSessionCategoryOptions,
        AVAudioSessionCategoryOptions.mixWithOthers,
        reason: 'a user who focuses to music should still have music',
      );
    });

    test('a bed takes the audio rather than mixing under it', () {
      // Picking a bed means picking it over whatever music was playing, so
      // don't mix.
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
      // Short prompts (navigation) should duck the bed, not stop it.
      // `AudioInterruptions` only sees a duck if this is false.
      expect(
        AppAudioSession.configurationFor(AudioUse.ambientBed)
            .androidWillPauseWhenDucked,
        isFalse,
      );
    });
  });
}
