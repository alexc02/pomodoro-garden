import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/ambience/ambience.dart';

/// An [Ambience] that tracks what's playing instead of playing it.
final class FakeAmbience implements Ambience {
  AmbientSound playing = AmbientSound.silence;

  /// Every bed asked for, in order, including silence. Repeats of the
  /// current bed are skipped, like the real player does.
  final List<AmbientSound> everPlayed = <AmbientSound>[];

  int stops = 0;

  /// Starts and swaps.
  int starts = 0;

  @override
  Future<void> play(AmbientSound sound) async {
    if (sound == playing) return;

    if (sound == AmbientSound.silence) {
      stops++;
    } else {
      starts++;
    }
    playing = sound;
    everPlayed.add(sound);
  }
}
