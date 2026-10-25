import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/feedback/end_sound_player.dart';
import 'package:pip_garden/src/feedback/haptics.dart';
import 'package:pip_garden/src/feedback/micro_sounds.dart';
import 'package:pip_garden/src/notifications/session_notifications.dart';

/// Stand-ins for the three things a session end reaches out to, none of which
/// leaves a mark on screen.
///
/// A chime, a buzz and a notification are the whole of what ticket 06 delivers
/// and none of them can be found with a `Finder` — so they are ports, and these
/// are what a test asserts against. `pumpApp` installs one of each by default,
/// and a test that wants to look at one passes its own in.

/// A [SessionNotifications] that remembers what the platform was asked for.
///
/// Models the platform rather than merely recording calls: there is one pending
/// notice at a time, scheduling replaces it, and cancelling clears it — which
/// is what makes `pending` a fair answer to "would the user's phone go off".
final class FakeSessionNotifications implements SessionNotifications {
  /// Every notice ever scheduled, in order, cancelled or not.
  final List<SessionCompletionNotice> scheduled = <SessionCompletionNotice>[];

  /// How many times permission has been asked for.
  int permissionRequests = 0;

  /// How many times a notice has been withdrawn.
  int cancellations = 0;

  /// What the user says when asked. Set false for the denied-permission case.
  bool granted = true;

  /// The notice that would fire, or null if nothing would.
  SessionCompletionNotice? pending;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> scheduleCompletion(SessionCompletionNotice notice) async {
    scheduled.add(notice);
    // A notice scheduled without permission is accepted and then never shown,
    // which is what both platforms do — neither throws, and neither tells the
    // app afterwards. Modelled here so that "the user said no" is a state a
    // test can put the app in rather than a call it can count.
    if (!granted) return;
    pending = notice;
  }

  /// The break-end notice that would fire after [pending], if one is
  /// scheduled. ADR 0022.
  SessionCompletionNotice? pendingFollowUp;

  /// Every follow-up ever scheduled, in order.
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

/// An [EndSoundPlayer] that remembers what it was asked for instead of playing.
///
/// Records the *sounds* rather than a count, because REQ-031 makes "did it
/// chime" two questions: whether the app announced the completion at all, and
/// whether it announced it with the sound the user chose. [plays] answers the
/// first and [played] the second.
final class FakeEndSoundPlayer implements EndSoundPlayer {
  /// Every sound asked for, in order — [EndSound.none] included, because the
  /// announcer asks for it like any other and it is the player that knows it
  /// costs nothing.
  final List<EndSound> played = <EndSound>[];

  int get plays => played.length;

  /// The last sound asked for, or null if nothing has been.
  EndSound? get last => played.isEmpty ? null : played.last;

  @override
  Future<void> play(EndSound sound) async => played.add(sound);
}

/// A [MicroSounds] that remembers the sequence instead of playing it.
///
/// The sequence rather than a count per sound, because ticket 26's four fire at
/// moments that are *ordered* — a tap on START, then the seed landing 800 ms
/// later — and the order is the part a test can get wrong. [countOf] is there
/// for the cases that only care how often.
final class FakeMicroSounds implements MicroSounds {
  /// Every sound asked for, in order.
  final List<MicroSound> played = <MicroSound>[];

  /// How many times [sound] has been asked for.
  int countOf(MicroSound sound) =>
      played.where((played) => played == sound).length;

  /// The last sound asked for, or null if nothing has been.
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
