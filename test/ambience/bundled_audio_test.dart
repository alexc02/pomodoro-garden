import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/ambience/ambience.dart';
import 'package:pip_garden/src/feedback/end_sound_player.dart';
import 'package:pip_garden/src/feedback/micro_sounds.dart';

/// The two of ticket 10's criteria that are about the *files* rather than about
/// the code, asserted against the files.
///
/// **The seam.** REQ-012 asks for loops with no audible join and §4.4 budgets
/// it at under five milliseconds. No test can listen, but a seam is not a
/// mystery: it is either a discontinuity in the waveform where the end meets
/// the beginning — heard as a click — or a step in level across the same point
/// — heard as a pulse. Both are arithmetic, and both are measured here. What is
/// left for a human ear is whether the *material* repeats noticeably, which is
/// a judgement about the recording and not about the join.
///
/// **The budget.** §5.4 caps all the app's audio at 8 MB, and the cap is easy
/// to walk past by accident: the placeholder loops are uncompressed, and every
/// end sound is bundled twice because Android will not take a notification
/// sound from a Flutter asset. So everything that ships is weighed, not just the
/// directory somebody remembered.
///
/// **The PCM assertion below is about the beds and only about the beds.** An
/// end sound is a one-shot — it has no seam, nothing joins it to itself — so
/// none of the argument for uncompressed loops applies to it, and widening this
/// to `EndSound.values` would spend the headroom the beds need. The same goes
/// twice over for §9.2's micro-sounds, which are compressed and tiny. What is
/// asserted about those two sets is in `test/feedback/end_sounds_test.dart` and
/// `test/feedback/micro_sounds_test.dart`; what is asserted *here* is the one
/// number they all share.
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
      // Not a taste. A lossy codec pads the front of a stream with encoder
      // delay and the back with a partial block, so a player looping an AAC
      // file splices in tens of milliseconds — ten times §4.4's budget —
      // unless encoder and player agree on gapless metadata, which ExoPlayer
      // and AVPlayer do not. The real recordings have to arrive the same way.
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

        // The join is a click when the jump from the last sample to the first
        // is bigger than the jumps the waveform makes anywhere else. Compared
        // against the 99.9th percentile of the file's own steps rather than
        // against a fixed number, because a wall of white noise steps further
        // between neighbouring samples than a wave does and neither is wrong.
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

        // A trailing fade to silence is the commonest way a "seamless" loop is
        // not one: no sample is missing and it still sounds like a gap. A
        // tenth of the file's own level is the line, and it is deliberately
        // generous — the ocean joins itself in the trough between two waves,
        // which is both the quietest point in the file and the right place to
        // put a join.
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

        // Fifty milliseconds either side: long enough to be a level rather
        // than a sample, short enough that a bed's own slow movement has not
        // gone anywhere. One decibel is about where a step in broadband noise
        // stops being noticeable.
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
      // Not the loop point, but the same complaint from the user's side: a bed
      // swapped mid-session must not be a step change in loudness. Matched on
      // RMS rather than peak, because a café of transients and a wall of white
      // noise at the same peak are nowhere near the same loudness.
      final levels = _beds.map((bed) => _Loop.read(bed).rms).toList();
      final spread = levels.reduce(math.max) / levels.reduce(math.min);

      expect(20 * (math.log(spread) / math.ln10), lessThan(1.0));
    });
  });

  group('§5.4 budgets all the app audio at 8 MB', () {
    test('and everything that ships fits, counted twice where it ships twice',
        () {
      final bundled = <File>[
        ..._beds.map(File.new),
        // REQ-031's five, each of them twice: a notification channel's sound
        // cannot come from a Flutter asset. Both copies are in the APK, so both
        // are in the budget — and the Android one is AAC rather than PCM, which
        // is the whole reason five one-shots fit next to the beds at all. See
        // `docs/ambience.md`.
        for (final sound in EndSound.values)
          if (endSoundAsset(sound) case final String asset) ...[
            File(asset),
            File('android/app/src/main/res/raw/'
                '${endSoundAndroidResource(sound)}.m4a'),
          ],
        // §9.2's four micro-sounds. Once each, and AAC: none of them ever
        // reaches a notification, so nothing forces a second PCM copy the way
        // it does for the end sounds above.
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
            'MB. §5.4 caps it at 8 MB, and the loops are the easy thing to '
            'grow — see scripts/make_synth_beds.py, which trades '
            'loop length against exactly this number.',
      );
    });
  });
}

/// Every bundled loop, by the path the app asks for it under.
final List<String> _beds = [
  for (final sound in AmbientSound.values) ?ambientLoopAsset(sound),
];

/// One bundled loop, read far enough to be measured.
///
/// A hand-rolled WAV reader rather than a package: the app ships one audio
/// format on purpose, this test is the thing that makes sure of it, and a
/// reader that accepted more than that would be checking less.
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

    // Walked chunk by chunk rather than assumed at a fixed offset: a WAV
    // written by anything other than the placeholder script may well carry
    // metadata before its data.
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

  /// 1 is uncompressed PCM. Anything else is a codec, and a codec is a seam.
  final int format;
  final int channels;
  final int bitsPerSample;
  final int sampleRate;
  final Int16List samples;

  /// How far the waveform jumps where the end meets the beginning again.
  int get joinStep => (samples.first - samples.last).abs();

  /// The step [through] of the way up the file's own sorted neighbour steps.
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
