import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/ambience/ambience.dart';
import 'package:pip_garden/src/feedback/end_sound_player.dart';
import 'package:pip_garden/src/feedback/micro_sounds.dart';

/// Ambient bed files. The loop join has to be inaudible (budget: under 5 ms).
/// No test can listen, but a click is a waveform discontinuity and a pulse is
/// a level step, and both are measurable. Whether the material audibly repeats
/// is for a human.
///
/// All bundled audio has to fit in 8 MB, end sounds counted twice since they
/// ship twice. Only the beds have to be PCM; end sounds and micro-sounds are
/// covered in `test/feedback/`.
void main() {
  group('every bed is bundled', () {
    test('and the app names a file for each of the five', () {
      for (final sound in AmbientSound.values) {
        final asset = ambientLoopAsset(sound);
        if (sound == AmbientSound.silence) {
          expect(asset, isNull, reason: 'silence is not a file');
          continue;
        }

        expect(asset, isNotNull, reason: '${sound.label} has no loop');
        expect(File(asset!).existsSync(), isTrue, reason: '$asset is missing');
      }
    });

    test('as uncompressed PCM, which is what makes the join possible', () {
      // Lossy codecs add encoder delay and block padding, so an AAC loop gets a
      // gap of tens of ms unless both ends honour gapless metadata, which
      // ExoPlayer and AVPlayer don't. Real recordings have to be PCM too.
      for (final bed in _beds) {
        final loop = _Loop.read(bed);
        expect(loop.format, 1, reason: '$bed is not PCM');
        expect(loop.channels, 1);
        expect(loop.bitsPerSample, 16);
      }
    });
  });

  group('the loop point', () {
    test('has no click: the step across it is an ordinary one', () {
      for (final bed in _beds) {
        final loop = _Loop.read(bed);

        // Compared to the file's own 99.9th percentile step rather than a fixed
        // number, since white noise steps further than a wave.
        expect(
          loop.joinStep,
          lessThan(loop.percentileStep(0.999)),
          reason: '$bed clicks: the last sample and the first are further '
              'apart than all but a thousandth of its neighbouring samples.',
        );
      }
    });

    test('has no gap: there is still sound on both sides of it', () {
      for (final bed in _beds) {
        final loop = _Loop.read(bed);
        const window = Duration(milliseconds: 50);

        // A trailing fade is the usual way a "seamless" loop isn't. A tenth of
        // the file's level is generous on purpose: the ocean joins in a trough.
        expect(loop.rmsOfLast(window), greaterThan(loop.rms * 0.1),
            reason: '$bed fades out at its end, which is a gap by another '
                'name.');
        expect(loop.rmsOfFirst(window), greaterThan(loop.rms * 0.1),
            reason: '$bed fades in at its start.');
      }
    });

    test('has no level jump across it', () {
      for (final bed in _beds) {
        final loop = _Loop.read(bed);

        // 50 ms either side: a level, not a sample, but short enough that the
        // bed hasn't moved. About 1 dB is where a step in broadband noise
        // becomes audible.
        const window = Duration(milliseconds: 50);
        final across = 20 *
            (math.log(loop.rmsOfFirst(window) / loop.rmsOfLast(window)) /
                math.ln10);

        expect(
          across.abs(),
          lessThan(1.0),
          reason: '$bed steps ${across.toStringAsFixed(2)} dB at its loop '
              'point, which is heard as a pulse once every loop.',
        );
      }
    });

    test('and the beds are level with each other', () {
      // Swapping beds mid-session shouldn't jump in loudness. RMS, not peak,
      // since transients and white noise at the same peak sound very different.
      final levels = _beds.map((bed) => _Loop.read(bed).rms).toList();
      final spread = levels.reduce(math.max) / levels.reduce(math.min);

      expect(20 * (math.log(spread) / math.ln10), lessThan(1.0));
    });
  });

  group('all the app audio fits in 8 MB', () {
    test('and everything that ships fits, counted twice where it ships twice',
        () {
      final bundled = <File>[
        ..._beds.map(File.new),
        // End sounds, twice each (Flutter asset plus Android raw resource). The
        // Android copy is AAC, which is what makes them fit; see
        // `docs/ambience.md`.
        for (final sound in EndSound.values)
          if (endSoundAsset(sound) case final String asset) ...[
            File(asset),
            File('android/app/src/main/res/raw/'
                '${endSoundAndroidResource(sound)}.m4a'),
          ],
        // Micro-sounds: once each, AAC.
        for (final sound in MicroSound.values) File(sound.asset),
      ];

      for (final file in bundled) {
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
      }

      final total = bundled.fold(0, (sum, file) => sum + file.lengthSync());

      expect(
        total,
        lessThan(8 * 1024 * 1024),
        reason: 'Bundled audio is ${(total / 1024 / 1024).toStringAsFixed(2)} '
            'MB. The cap is 8 MB, and the loops are the easy thing to '
            'grow; see scripts/make_synth_beds.py, which trades '
            'loop length against exactly this number.',
      );
    });
  });
}

final List<String> _beds = [
  for (final sound in AmbientSound.values) ?ambientLoopAsset(sound),
];

/// One bundled loop, read far enough to be measured. Hand-rolled WAV reader so
/// it only accepts the one format the assets should be in.
final class _Loop {
  _Loop._({
    required this.format,
    required this.channels,
    required this.bitsPerSample,
    required this.sampleRate,
    required this.samples,
  });

  factory _Loop.read(String path) {
    final bytes = File(path).readAsBytesSync();
    final view = ByteData.sublistView(bytes);

    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');

    int? format;
    int? channels;
    int? bitsPerSample;
    int? sampleRate;
    Int16List? samples;

    // Walk the chunks; a WAV from another tool may have metadata before the
    // data.
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

    return _Loop._(
      format: format!,
      channels: channels!,
      bitsPerSample: bitsPerSample!,
      sampleRate: sampleRate!,
      samples: samples!,
    );
  }

  /// 1 is uncompressed PCM. Anything else is a codec, which means a seam.
  final int format;
  final int channels;
  final int bitsPerSample;
  final int sampleRate;
  final Int16List samples;

  int get joinStep => (samples.first - samples.last).abs();

  /// The [through] percentile of the absolute sample-to-sample steps.
  int percentileStep(double through) {
    final steps = <int>[
      for (var index = 1; index < samples.length; index++)
        (samples[index] - samples[index - 1]).abs(),
    ]..sort();
    return steps[(steps.length * through).floor()];
  }

  double get rms => _rms(0, samples.length);

  double rmsOfFirst(Duration window) => _rms(0, _samplesIn(window));

  double rmsOfLast(Duration window) =>
      _rms(samples.length - _samplesIn(window), samples.length);

  int _samplesIn(Duration window) =>
      (window.inMicroseconds * sampleRate) ~/ Duration.microsecondsPerSecond;

  double _rms(int from, int to) {
    var sum = 0.0;
    for (var index = from; index < to; index++) {
      sum += samples[index] * samples[index].toDouble();
    }
    return math.sqrt(sum / (to - from));
  }
}
