import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/feedback/end_sound_player.dart';

/// The part of REQ-031 that is about the *files* rather than about the code.
///
/// Three things are checked, and each of them is something a reviewer could
/// otherwise only find by putting on headphones:
///
/// **Both copies exist for every sound.** An end sound ships twice — a Flutter
/// asset and an Android raw resource — because a notification channel's sound
/// cannot come from an asset. A sound with only one of the two is a sound that
/// plays in the app and falls back to the system default on the notification,
/// which is the failure nobody notices until they are away from their phone.
///
/// **The asset is PCM, and the Android copy is not.** That asymmetry is the one
/// decision in this ticket most likely to be tidied away by somebody making the
/// two match, so it is asserted in both directions. The asset is PCM because
/// iOS installs it into `Library/Sounds` and `UNNotificationSound` takes
/// nothing else; the Android copy is AAC because it has no such rule and §5.4's
/// 8 MB is real. `docs/ambience.md` has the arithmetic.
///
/// **None is not a file.** Not a file of silence, either — see [endSoundAsset].
///
/// What no test here can check is whether a singing bowl sounds like a singing
/// bowl. These are synthesised placeholders behind the seam PRD §9.2's
/// recordings arrive through, exactly as ticket 04's shapes stand in for
/// ticket 23's watercolour.
void main() {
  group('every sound is bundled', () {
    test('the app names both copies of the five that are files, and no file '
        'at all for None', () {
      for (final sound in EndSound.values) {
        final asset = endSoundAsset(sound);
        final resource = endSoundAndroidResource(sound);
        final ios = endSoundIosSound(sound);

        if (sound == EndSound.none) {
          expect(asset, isNull, reason: 'None is not a file');
          expect(resource, isNull);
          expect(ios, isNull);
          continue;
        }

        expect(asset, isNotNull, reason: '${sound.label} has no asset');
        expect(File(asset!).existsSync(), isTrue, reason: '$asset is missing');

        expect(resource, isNotNull);
        final raw = File('android/app/src/main/res/raw/$resource.m4a');
        expect(raw.existsSync(), isTrue, reason: '${raw.path} is missing');

        // iOS installs the asset under this name, so the two have to agree
        // about what the file is called.
        expect(ios, '$resource.wav');
      }
    });

    test('and no two sounds share a file', () {
      final assets = <String>{
        for (final sound in EndSound.values) ?endSoundAsset(sound),
      };
      expect(assets, hasLength(EndSound.values.length - 1));
    });
  });

  group('the format each copy is in', () {
    test('the asset is 16-bit mono PCM, because iOS will not take AAC', () {
      // `UNNotificationSound` reads Linear PCM, IMA/ADPCM, µLaw and aLaw, in
      // WAV, AIFF or CAF — and nothing else. This same file is what
      // `LocalSessionNotifications._installIosSound` copies into
      // `Library/Sounds`, so an AAC asset would play in the app and be silently
      // replaced by the system default on the notification.
      for (final sound in _sounds) {
        final clip = _Clip.read(endSoundAsset(sound)!);
        expect(clip.format, 1, reason: '${sound.label} is not PCM');
        expect(clip.channels, 1);
        expect(clip.bitsPerSample, 16);
      }
    });

    test('the Android copy is compressed, because nothing stops it', () {
      // A one-shot has no loop point, so none of `docs/ambience.md`'s argument
      // against lossy audio applies to it — and §5.4 asks for AAC. What is
      // checked is that the file is an MPEG-4 container rather than a WAV
      // somebody renamed: the first box in an MP4 is `ftyp`.
      for (final sound in _sounds) {
        final raw = File(
          'android/app/src/main/res/raw/${endSoundAndroidResource(sound)}.m4a',
        );
        final head = raw.readAsBytesSync().sublist(4, 8);
        expect(String.fromCharCodes(head), 'ftyp',
            reason: '${raw.path} is not an MP4');
      }
    });

    test('and the compressed copy is a fraction of the uncompressed one', () {
      // The point of the asymmetry, said as the number it buys. If this ever
      // stops holding, the two copies have quietly become the same format
      // again and §5.4's 8 MB is in play — see `bundled_audio_test.dart`.
      for (final sound in _sounds) {
        final asset = File(endSoundAsset(sound)!).lengthSync();
        final raw = File(
          'android/app/src/main/res/raw/${endSoundAndroidResource(sound)}.m4a',
        ).lengthSync();

        expect(raw, lessThan(asset ~/ 2),
            reason: '${sound.label}: the Android copy is $raw bytes against '
                'the asset\'s $asset, which is not a compressed file.');
      }
    });
  });

  group('what the user hears', () {
    test('every sound is audible', () {
      // The test that would have caught ticket 06's placeholder script, which
      // broke out of its synthesis loop on the first sample and shipped four
      // seconds of digital silence as the app's default chime. Nothing noticed,
      // because nothing listened.
      for (final sound in _sounds) {
        final clip = _Clip.read(endSoundAsset(sound)!);
        expect(clip.peak, greaterThan(1000),
            reason: '${sound.label} is silent, or near enough.');
      }
    });

    test('and no two of them are wildly different in level', () {
      // A user comparing two sounds in settings must not be shouted at by one
      // of them. Matched on peak rather than RMS, which is what the placeholder
      // script can honestly do — a five-second bowl and a sixty-millisecond
      // chirp at equal RMS would not be equally loud either, and which of the
      // five *sounds* loudest is a judgement for §9.2's sound designer.
      final peaks = [
        for (final sound in _sounds) _Clip.read(endSoundAsset(sound)!).peak,
      ];
      final spread = peaks.reduce(math.max) / peaks.reduce(math.min);

      expect(20 * (math.log(spread) / math.ln10), lessThan(1.0));
    });

    test('and none of them starts with a click', () {
      // A one-shot that begins at full deflection is a click before it is
      // anything else, which is the opposite of what REQ-008 asks these sounds
      // to be. The first millisecond has to be quiet.
      for (final sound in _sounds) {
        final clip = _Clip.read(endSoundAsset(sound)!);
        expect(clip.peakOfFirst(const Duration(milliseconds: 1)),
            lessThan(clip.peak * 0.5),
            reason: '${sound.label} opens on an edge.');
      }
    });
  });
}

/// The five sounds that are files. [EndSound.none] is not one.
final List<EndSound> _sounds =
    EndSound.values.where((sound) => endSoundAsset(sound) != null).toList();

/// One bundled end sound, read far enough to be measured.
///
/// A hand-rolled WAV reader rather than a package, for the reason
/// `bundled_audio_test.dart`'s is: the assets ship in one format on purpose,
/// this is the thing that makes sure of it, and a reader that accepted more
/// than that would be checking less.
final class _Clip {
  _Clip._({
    required this.format,
    required this.channels,
    required this.bitsPerSample,
    required this.sampleRate,
    required this.samples,
  });

  factory _Clip.read(String path) {
    final bytes = File(path).readAsBytesSync();
    final view = ByteData.sublistView(bytes);

    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');

    int? format;
    int? channels;
    int? bitsPerSample;
    int? sampleRate;
    Int16List? samples;

    var at = 12;
    while (at + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(at, at + 4));
      final size = view.getUint32(at + 4, Endian.little);
      final body = at + 8;

      switch (id) {
        case 'fmt ':
          format = view.getUint16(body, Endian.little);
          channels = view.getUint16(body + 2, Endian.little);
          sampleRate = view.getUint32(body + 4, Endian.little);
          bitsPerSample = view.getUint16(body + 14, Endian.little);
        case 'data':
          samples = Int16List(size ~/ 2);
          for (var index = 0; index < samples.length; index++) {
            samples[index] = view.getInt16(body + index * 2, Endian.little);
          }
      }

      // Chunks are padded to an even length.
      at = body + size + (size.isOdd ? 1 : 0);
    }

    expect(samples, isNotNull, reason: '$path has no audio in it');

    return _Clip._(
      format: format!,
      channels: channels!,
      bitsPerSample: bitsPerSample!,
      sampleRate: sampleRate!,
      samples: samples!,
    );
  }

  /// 1 is uncompressed PCM.
  final int format;
  final int channels;
  final int bitsPerSample;
  final int sampleRate;
  final Int16List samples;

  double get peak => _peak(0, samples.length);

  double peakOfFirst(Duration window) => _peak(
        0,
        math.min(
          (window.inMicroseconds * sampleRate) ~/
              Duration.microsecondsPerSecond,
          samples.length,
        ),
      );

  double _peak(int from, int to) {
    var highest = 0.0;
    for (var index = from; index < to; index++) {
      final magnitude = samples[index].abs().toDouble();
      if (magnitude > highest) highest = magnitude;
    }
    return highest;
  }
}
