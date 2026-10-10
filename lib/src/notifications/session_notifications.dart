import 'package:pomodoro_domain/pomodoro_domain.dart';

/// What the timer says when it runs out while the app is not on screen, when,
/// and what it sounds like.
///
/// A value rather than a pile of arguments, so the copy can be written and
/// tested without a platform anywhere near it — the wording is the part of a
/// notification the product actually cares about.
///
/// One value for both a session and a break, because there is one timer and one
/// scheduled notice at a time: whichever of the two is counting down is the one
/// the user is away from. The factories are where they differ, and they differ
/// only in what there is to say.
final class SessionCompletionNotice {
  const SessionCompletionNotice({
    required this.at,
    required this.title,
    required this.body,
    required this.sound,
  });

  /// What to say about a session that ends at [at] having grown [growing].
  ///
  /// The tone is the requirement. PRD §2 sells an app with "no notifications
  /// screaming for attention", and this is the one notification it sends: it
  /// reports something finished, names the plant so the news is about the
  /// garden rather than about the timer, and asks for nothing. No exclamation
  /// mark, no "Time's up", no verb in the imperative.
  factory SessionCompletionNotice.forGrowth(
    PlantGrowth? growing, {
    required DateTime at,
    required EndSound sound,
  }) {
    if (growing == null) {
      // No session, no plant, and so nothing specific to say. Reachable only if
      // a caller schedules for a session it cannot describe; it should not
      // read like a bug to whoever gets it.
      return SessionCompletionNotice(
        at: at,
        title: 'Your session is complete',
        body: 'Something new is growing in your garden.',
        sound: sound,
      );
    }

    return SessionCompletionNotice(
      at: at,
      title: 'Your ${growing.species.label.toLowerCase()} has bloomed',
      body: 'Your focus session is complete. It is in your garden whenever '
          'you would like to see it.',
      sound: sound,
    );
  }

  /// What to say about a break of [kind] that runs out at [at].
  ///
  /// The same tone, and the same shape of news: something has finished, and the
  /// user is told rather than summoned. It names no plant, because a break grows
  /// none — that absence is the whole difference between the two notices, and
  /// saying "your garden" here would be claiming a reward for resting.
  ///
  /// The imperative is avoided in the same breath it is invited: "whenever you
  /// are ready" rather than "get back to work", because a break the app nags at
  /// the end of is not a break.
  factory SessionCompletionNotice.forBreak({
    required BreakKind kind,
    required DateTime at,
    required EndSound sound,
  }) {
    return SessionCompletionNotice(
      at: at,
      title: switch (kind) {
        BreakKind.short => 'Your break is over',
        BreakKind.long => 'Your long break is over',
      },
      body: 'Another session is waiting whenever you are ready.',
      sound: sound,
    );
  }

  /// The instant the session reaches its planned duration — an absolute
  /// instant, which is what makes it schedulable in UTC and immune to the phone
  /// changing timezone under it.
  final DateTime at;

  final String title;
  final String body;

  /// REQ-031's chosen sound, carried here rather than looked up by whatever
  /// posts the notice.
  ///
  /// It belongs on the notice for the reason the copy does: this value is the
  /// whole announcement, decided while the app is still awake, and the thing
  /// that delivers it should have nothing left to work out. It is also the only
  /// honest place for it — the sound is read from the settings at the moment
  /// the app leaves the foreground, and by the time the notification fires
  /// there is nothing of this app running to read them.
  ///
  /// [EndSound.none] is a value like the other five: the notice still appears,
  /// and it makes no sound. The announcement is the news, not the noise.
  final EndSound sound;

  @override
  bool operator ==(Object other) =>
      other is SessionCompletionNotice &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.sound == sound;

  @override
  int get hashCode => Object.hash(at, title, body, sound);

  @override
  String toString() =>
      'SessionCompletionNotice($title, at $at, ${sound.name})';
}

/// The platform's promise to say something at a chosen instant, whether or not
/// this app is running when it arrives.
///
/// This is the whole of how a backgrounded session is announced. Nothing in the
/// app runs in the background to notice a completion — REQ-005 is explicit that
/// nothing may depend on background execution — so what the user hears at
/// twenty-five minutes is a notification the system was handed at the moment
/// the app left the foreground.
///
/// Every method is best-effort by contract. A denied permission, a platform
/// that refuses exact alarms, a missing plugin: none of them may throw at a
/// caller, because none of them changes whether the session completed. The
/// session is recorded from the wall clock either way.
abstract interface class SessionNotifications {
  /// Asks the user for permission to notify them, and reports whether it was
  /// given.
  ///
  /// Safe to call more than once: after the user has decided, both platforms
  /// answer from the decision rather than asking again.
  Future<bool> requestPermission();

  /// Asks the platform to deliver [notice] at its instant.
  ///
  /// Replaces whatever was scheduled before it — there is one session, so there
  /// is one notice.
  Future<void> scheduleCompletion(SessionCompletionNotice notice);

  /// Asks the platform to deliver [notice] at its instant as well as the
  /// completion notice: the end of the break that REQ-032's auto-start will
  /// replay from the session's end while the app is away (ADR 0022).
  ///
  /// Replaces whatever follow-up was scheduled before it, and leaves the
  /// completion notice alone.
  Future<void> scheduleFollowUp(SessionCompletionNotice notice);

  /// Withdraws the scheduled notices — the completion and any follow-up — and
  /// clears them from the shade if they have already been delivered.
  ///
  /// The second half matters as much as the first: this runs when the user
  /// opens the app, and a notification saying a session has finished is stale
  /// the moment they are looking at the finished session.
  Future<void> cancelCompletion();
}
