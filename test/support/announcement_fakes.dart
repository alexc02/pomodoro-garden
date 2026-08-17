import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/feedback/end_sound_player.dart';
import 'package:pip_garden/src/feedback/haptics.dart';
import 'package:pip_garden/src/feedback/micro_sounds.dart';
import 'package:pip_garden/src/notifications/session_notifications.dart';

// Fakes for the session-end ports: notification, chime, haptics, micro sounds.

/// A [SessionNotifications] that models one pending notice: scheduling
/// replaces it, cancelling clears it.
final class FakeSessionNotifications implements SessionNotifications {
  /// Every notice ever scheduled, cancelled or not.
  final List<SessionCompletionNotice> scheduled = <SessionCompletionNotice>[];

  int permissionRequests = 0;

  int cancellations = 0;

  /// Set false for the denied-permission case.
  bool granted = true;

  SessionCompletionNotice? pending;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> scheduleCompletion(SessionCompletionNotice notice) async {
    scheduled.add(notice);
    // Without permission both platforms accept the notice and never show it.
    if (!granted) return;
    pending = notice;
  }

  /// The break-end notice after [pending].
  SessionCompletionNotice? pendingFollowUp;

  final List<SessionCompletionNotice> followUps = <SessionCompletionNotice>[];

  @override
  Future<void> scheduleFollowUp(SessionCompletionNotice notice) async {
    followUps.add(notice);
    if (!granted) return;
    pendingFollowUp = notice;
  }

  @override
  Future<void> cancelCompletion() async {
    cancellations++;
    pending = null;
    pendingFollowUp = null;
  }
}

/// An [EndSoundPlayer] that records which sounds were asked for.
final class FakeEndSoundPlayer implements EndSoundPlayer {
  /// Includes [EndSound.none]; the announcer asks for it like any other.
  final List<EndSound> played = <EndSound>[];

  int get plays => played.length;

  EndSound? get last => played.isEmpty ? null : played.last;

  @override
  Future<void> play(EndSound sound) async => played.add(sound);
}

/// A [MicroSounds] that records the sequence, since order matters (tap on
/// start, then the seed landing 800 ms later).
final class FakeMicroSounds implements MicroSounds {
  final List<MicroSound> played = <MicroSound>[];

  int countOf(MicroSound sound) =>
      played.where((played) => played == sound).length;

  MicroSound? get last => played.isEmpty ? null : played.last;

  @override
  Future<void> play(MicroSound sound) async => played.add(sound);
}

/// A [Haptics] that counts each kind of tap.
final class FakeHaptics implements Haptics {
  int completions = 0;
  int growths = 0;

  @override
  Future<void> sessionComplete() async => completions++;

  @override
  Future<void> plantGrew() async => growths++;
}
