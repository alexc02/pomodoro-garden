import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/ambience/ambience.dart';

/// An [Ambience] that remembers what it was asked to play instead of playing.
///
/// Models the player rather than merely counting calls, because every one of
/// ticket 10's criteria is about *what is playing* rather than about how many
/// times something was called: whether the bed survived a pause, whether
/// changing it mid-session stopped anything, whether the session ending took it
/// down. [playing] is what answers all three, and [everPlayed] is what catches
/// the failure the others cannot — a bed that was correct at the end because it
/// was restarted, having stopped somewhere in the middle.
final class FakeAmbience implements Ambience {
  /// What is playing right now. Silence when nothing is.
  AmbientSound playing = AmbientSound.silence;

  /// Every bed ever asked for, in order, [AmbientSound.silence] included —
  /// which is what taking the bed down is to the user and to the port.
  ///
  /// A repeat of what is already playing is not recorded, because the real one
  /// does nothing with it: the whole of "changeable mid-session without a gap"
  /// is that a bed already correct is left alone.
  final List<AmbientSound> everPlayed = <AmbientSound>[];

  /// How many times the bed has been taken down.
  int stops = 0;

  /// How many times a bed was started or swapped — the count REQ-012's "without
  /// a gap or restart" is about.
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
