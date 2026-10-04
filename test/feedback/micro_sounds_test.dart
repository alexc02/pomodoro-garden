import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/audio/app_audio_session.dart';
import 'package:pip_garden/src/feedback/micro_sounds.dart';

// The micro-sound assets and their audio session. When each one plays is
// covered in `test/features/timer/micro_sounds_test.dart`.
void main() {
  group('every micro-sound is bundled', () {
    test('and there are exactly four of them', () {
      expect(MicroSound.values, hasLength(4));
      expect(MicroSound.values.map((sound) => sound.stem), [
        'soil_settle',
        'growth_shimmer',
        'button_tap',
        'unlock',
      ]);
    });

    test('each names a file of its own, and the file is there', () {
      final assets = <String>{};

      for (final sound in MicroSound.values) {
        final file = File(sound.asset);
        expect(file.existsSync(), isTrue,
            reason: '${sound.asset} is missing');
        assets.add(sound.asset);
      }

      expect(assets, hasLength(MicroSound.values.length),
          reason: 'two micro-sounds share a file');
    });

    test('as AAC, because nothing here forces them to be PCM', () {
      // Only end sounds need a PCM copy (for iOS notifications). An MP4 starts
      // with an `ftyp` box, which rules out a renamed WAV.
      for (final sound in MicroSound.values) {
        final head = File(sound.asset).readAsBytesSync().sublist(4, 8);
        expect(String.fromCharCodes(head), 'ftyp',
            reason: '${sound.asset} is not an MP4');
      }
    });

    test('and all four together are a rounding error against the beds', () {
      // The full 8 MB budget is checked in `bundled_audio_test.dart`; UI blips
      // should be tiny on their own.
      final total = MicroSound.values.fold(
        0,
        (sum, sound) => sum + File(sound.asset).lengthSync(),
      );

      expect(total, lessThan(256 * 1024),
          reason: 'the four micro-sounds are ${(total / 1024).round()} KB',);
    });
  });

  group('none of them takes the audio session from a bed', () {
    test('because they ask it to be configured, never to be re-configured', () {
      // `useFor` takes the session, `ensureConfigured` doesn't. A
      // micro-sound calling `useFor` would drop to `ambient` and silence a
      // playing bed on iOS. Checked against the source since the platform call
      // can't run here.
      final source =
          File('lib/src/feedback/bundled_micro_sounds.dart').readAsStringSync();

      expect(source, contains('ensureConfigured'));
      expect(
        source,
        isNot(contains('useFor')),
        reason: 'The bed owns the audio session for as long as it plays. '
            'A micro-sound that reconfigured it would stop the rain.',
      );
    });
  });

  group('a phone set to silent stays silent', () {
    test('because the use they play on is the one the ring switch mutes', () {
      // No switch of their own: they play on `chimeOnly` unless a bed holds the
      // session, and `chimeOnly` is what the ring switch / ringer mode mutes.
      final quiet = AppAudioSession.configurationFor(AudioUse.chimeOnly);

      expect(quiet.avAudioSessionCategory, isNot(AVAudioSessionCategory.playback),
          reason: 'playback deliberately ignores the silent switch, which is '
              'the one thing these four must not do');
      expect(quiet.androidAudioAttributes?.usage,
          isNot(AndroidAudioUsage.media));
    });

    test('with the one exception a running bed brings, which is inherited', () {
      // A bed holds the session on `playback`, which ignores the ring switch,
      // so a micro-sound during a bed is audible on a silenced phone. Taking
      // the session back would stop the bed, so this is accepted.
      final held = AppAudioSession.configurationFor(AudioUse.ambientBed);

      expect(held.avAudioSessionCategory, AVAudioSessionCategory.playback);
      expect(
        File('lib/src/feedback/bundled_micro_sounds.dart').readAsStringSync(),
        contains('ignores the iOS ring switch'),
        reason: 'the exception is documented where the decision lives',
      );
    });
  });
}
