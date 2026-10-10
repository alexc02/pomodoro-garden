import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/audio/app_audio_session.dart';
import 'package:pomodoro_garden/src/feedback/micro_sounds.dart';

/// Ticket 26's files and its one platform rule, checked where a workstation can
/// check them.
///
/// What is asserted about the *moments* — which tap, which instant of the drop,
/// which celebration — is in `test/features/timer/micro_sounds_test.dart`, next
/// to the screens that make them. This file is about the four assets and about
/// the audio session they go out on.
void main() {
  group('every micro-sound is bundled', () {
    test('and §9.2 names exactly four of them', () {
      // A closed set. A fifth is a new requirement rather than a natural
      // extension of this one, so the count is asserted rather than assumed.
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
      // The end sounds ship a PCM copy because iOS installs it into
      // `Library/Sounds` and `UNNotificationSound` reads nothing else. None of
      // these four ever reaches a notification, so §5.4's AAC is simply right —
      // and `docs/ambience.md` is where that difference is written down. The
      // first box of an MP4 is `ftyp`, which is what says this is not a WAV
      // somebody renamed.
      for (final sound in MicroSound.values) {
        final head = File(sound.asset).readAsBytesSync().sublist(4, 8);
        expect(String.fromCharCodes(head), 'ftyp',
            reason: '${sound.asset} is not an MP4');
      }
    });

    test('and all four together are a rounding error against the beds', () {
      // §5.4's 8 MB is counted in full by `bundled_audio_test.dart`. This is the
      // narrower claim these four have to keep on their own: a set of UI blips
      // that grew to megabytes would be a set of UI blips somebody had recorded
      // at album quality.
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
      // ADR 0009: `useFor` *takes* the session and `ensureConfigured` only makes
      // sure somebody has set it up. A micro-sound that called `useFor` would
      // drop the app back to `ambient` in the middle of a session with rain
      // playing — silencing the bed on iOS at the first button tap, on a
      // device, weeks after anyone looked at this.
      //
      // Asserted against the source because the alternative is a platform call
      // this machine cannot make. The same shape as
      // `test/garden/sprites_are_the_only_art_test.dart`: a rule whose
      // violation is one plausible-looking line.
      final source =
          File('lib/src/feedback/bundled_micro_sounds.dart').readAsStringSync();

      expect(source, contains('ensureConfigured'));
      expect(
        source,
        isNot(contains('useFor')),
        reason: 'ADR 0009 gives the bed the session for as long as it plays. '
            'A micro-sound that reconfigured it would stop the rain.',
      );
    });
  });

  group('a phone set to silent stays silent', () {
    test('because the use they play on is the one the ring switch mutes', () {
      // The whole of ticket 26's answer to "what turns these off". There is no
      // switch of their own: `BundledMicroSounds` asks the shared session for
      // `ensureConfigured`, which leaves the app on `chimeOnly` unless a bed has
      // taken it — and `chimeOnly` is `ambient` on iOS, the category the ring
      // switch mutes, and the notification usage on Android, which the ringer
      // mode governs the same way.
      final quiet = AppAudioSession.configurationFor(AudioUse.chimeOnly);

      expect(quiet.avAudioSessionCategory, isNot(AVAudioSessionCategory.playback),
          reason: 'playback deliberately ignores the silent switch, which is '
              'the one thing these four must not do');
      expect(quiet.androidAudioAttributes?.usage,
          isNot(AndroidAudioUsage.media));
    });

    test('with the one exception a running bed brings, which is inherited', () {
      // Worth asserting rather than leaving unsaid, because it is the one place
      // two of the ticket's criteria genuinely pull against each other: a bed
      // holds the session on `playback`, which ignores the ring switch, so a
      // micro-sound fired during one is audible on a silenced phone.
      //
      // The alternative loses by ADR 0009's own argument — taking the session
      // back to `ambient` for a button tap would silence the rain the user
      // asked for — and it is the end sound's existing bargain rather than a
      // new one. This test exists so that the exception is a decision somebody
      // can find, not a surprise on a device.
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
