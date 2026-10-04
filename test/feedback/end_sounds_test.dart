import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/feedback/end_sound_player.dart';

/// End sound files. Every sound ships twice: a Flutter asset (PCM, because iOS
/// notifications only take PCM from `Library/Sounds`) and an Android raw
/// resource (AAC, since channel sounds can't come from assets). None has no
/// file at all. Size arithmetic is in `docs/ambience.md`. These are
/// synthesised placeholders until real recordings exist.
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

        // iOS installs the asset under this name.
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
      // `UNNotificationSound` reads only Linear PCM, IMA/ADPCM, µLaw and aLaw
      // in WAV/AIFF/CAF. An AAC asset would fall back to the system default.
      for (final sound in _sounds) {
        final clip = _Clip.read(endSoundAsset(sound)!);
        expect(clip.format, 1, reason: '${sound.label} is not PCM');
        expect(clip.channels, 1);
        expect(clip.bitsPerSample, 16);
      }
    });

    test('the Android copy is compressed, because nothing stops it', () {
      // A one-shot has no loop point, so lossy is fine. An MP4 starts with an
      // `ftyp` box, which rules out a renamed WAV.
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
      // If this stops holding, the two copies have become the same format and
      // the 8 MB budget is at risk (`bundled_audio_test.dart`).
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
      // The placeholder script once shipped four seconds of silence as the
      // default chime.
      for (final sound in _sounds) {
        final clip = _Clip.read(endSoundAsset(sound)!);
        expect(clip.peak, greaterThan(1000),
            reason: '${sound.label} is silent, or near enough.');
      }
    });

    test('and no two of them are wildly different in level', () {
      // Peak, not RMS; perceived loudness is for a sound designer to judge.
      final peaks = [
        for (final sound in _sounds) _Clip.read(endSoundAsset(sound)!).peak,
      ];
      final spread = peaks.reduce(math.max) / peaks.reduce(math.min);

      expect(20 * (math.log(spread) / math.ln10), lessThan(1.0));
    });

    test('and none of them starts with a click', () {
      // No click at the start: the first millisecond has to be quiet.
      for (final sound in _sounds) {
        final clip = _Clip.read(endSoundAsset(sound)!);
        expect(clip.peakOfFirst(const Duration(milliseconds: 1)),
            lessThan(clip.peak * 0.5),
            reason: '${sound.label} opens on an edge.');
      }
    });
  });
}

final List<EndSound> _sounds =
    EndSound.values.where((sound) => endSoundAsset(sound) != null).toList();

/// One bundled end sound, read far enough to be measured. Hand-rolled WAV
/// reader so it only accepts the one format the assets should be in.
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
