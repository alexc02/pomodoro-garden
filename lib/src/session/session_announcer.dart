import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../feedback/feedback_providers.dart';
import '../feedback/micro_sounds.dart';
import '../notifications/notification_providers.dart';
import '../notifications/session_notifications.dart';
import '../settings/settings_providers.dart';
import '../time/clock_provider.dart';
import 'session_providers.dart';

/// How a session says it has ended, and how a plant says it has grown.
///
/// [SessionLifecycle] is about what the *session* does when the app comes and
/// goes; this is about what the *user is told*, and the two are separated
/// because they answer to different requirements — REQ-013 there, REQ-008 and
/// REQ-037 here.
///
/// One rule holds the whole class together:
///
/// **A completion is announced once, by whichever of the two can be heard.**
/// While the app is in front that is REQ-031's chosen sound and a haptic,
/// played by this class at the instant the session ends. While it is not, it is
/// a notification the operating system was handed when the app left the
/// foreground — because nothing of this app is running to play anything, and
/// REQ-005 forbids depending on anything that would be. The notification exists
/// only while the app is away: it is scheduled on the way out and cancelled on
/// the way back in, so there is never a moment when both could sound.
///
/// The corollary is the case that looks like a bug and is not: a session that
/// finished while the app was away is *not* chimed at when the user opens the
/// app. They were told when it happened. Telling them again, ten minutes late,
/// would be an app that chimes at the wrong moment.
///
/// **A break that runs out is announced by the same rule.** It is the end of
/// something the user has been waiting through, and it is the one countdown
/// they are meant to be away from — an app that told them their break was over
/// only if they happened to be watching would have failed the requirement it
/// exists for. A break they *skipped* makes no sound at all: that is a decision
/// they took, not news they need. `SessionMachine.endBreak` puts a skipped
/// break in `idle` rather than `breakOver`, which is where that difference
/// lives.
class SessionAnnouncer extends ConsumerStatefulWidget {
  const SessionAnnouncer({required this.child, super.key});

  final Widget child;

  /// How late a completion can be noticed and still be news.
  ///
  /// The ticker aims at the exact instant a session ends, so in the foreground
  /// a completion is noticed within a frame of it. Anything older than this was
  /// found rather than watched — the app was asleep, or has just been opened —
  /// and the scheduled notification has already said so.
  static const Duration _freshly = Duration(seconds: 2);

  /// Whether an ending due at [dueAt], noticed at [now], was watched as it
  /// happened rather than found afterwards.
  ///
  /// Public because the chime is not the only thing that answers to it. §5.3's
  /// bloom on the timer screen is the same kind of news told a different way,
  /// and a session that ran out with the app away must not blossom at the user
  /// when they come back any more than it should chime at them.
  static bool watched({required DateTime dueAt, required DateTime now}) {
    final late = now.difference(dueAt);
    return !late.isNegative && late <= _freshly;
  }

  @override
  ConsumerState<SessionAnnouncer> createState() => _SessionAnnouncerState();
}

class _SessionAnnouncerState extends ConsumerState<SessionAnnouncer> {
  AppLifecycleListener? _listener;

  /// Whether the app is the thing on screen. Starts true: a widget tree is
  /// being built, which is something only a foreground app does.
  bool _inForeground = true;

  /// Whether this run of the app has already asked about notifications.
  bool _permissionAsked = false;

  /// When the session now running is due to end, as of the last time anything
  /// was heard from it.
  ///
  /// Kept so that a completion can be told apart from the *discovery* of one.
  /// Null when no session is running, which is also the answer for a session
  /// restored at launch that was already over — nothing here watched it end.
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: _returnedToTheForeground,
      // `paused` rather than `inactive` or `hidden`: those two also happen for
      // a notification shade being pulled down or a call arriving over the top
      // of the app, and the session is not away yet. `paused` is the platform
      // saying the app is no longer visible at all — the last moment it is
      // reliably able to run code, and so the moment to hand the announcement
      // over to the system.
      onPause: _leftTheForeground,
      // Nothing to announce about a session that is being thrown away. The
      // session itself is voided by [SessionLifecycle].
      onDetach: _cancelNotice,
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionControllerProvider, _sessionChanged);
    return widget.child;
  }

  /// Every published state of the timer passes through here.
  void _sessionChanged(SessionSnapshot? previous, SessionSnapshot next) {
    // A break is counting down to an instant exactly as a session is, so it is
    // remembered the same way and for the same reason.
    if (next.phase == SessionPhase.running ||
        next.phase == SessionPhase.onBreak) {
      // Absolute, not a countdown: this survives the app being asleep between
      // one reading and the next, which is exactly the case it exists for.
      // Taken from the snapshot rather than worked out from the clock here,
      // so this and the live surface promise the user the same instant.
      _dueAt = next.dueAt;
    }

    if (previous == null) return;

    if (previous.phase == SessionPhase.idle &&
        next.phase == SessionPhase.running) {
      _askAboutNotifications();
    }

    if (previous.phase != SessionPhase.completed &&
        next.phase == SessionPhase.completed) {
      _ended();
      // A completing session also reaches its last growth stage, and the two
      // are one event to the hand. The completion is the louder of them.
      return;
    }

    // A break that ran its course is announced exactly as a session is: it is
    // the end of something the user was waiting out, and they may well not be
    // looking at it. A break they *skipped* goes to idle rather than through
    // here, which is why walking out of one makes no sound.
    if (previous.phase != SessionPhase.breakOver &&
        next.phase == SessionPhase.breakOver) {
      _ended();
      return;
    }

    if (_grewAStage(previous, next)) _grew();
  }

  /// REQ-031's chosen sound and REQ-037's success haptic, for a session or a
  /// break that has just this moment ended with the user watching.
  ///
  /// One method for both, because the rule is about *being told*, and the two
  /// endings are told about identically: the same sound, the same tap, the same
  /// once-only guarantee against the notification that would otherwise say it
  /// twice.
  void _ended() {
    final due = _dueAt;
    _dueAt = null;

    // Away: the notification handed over at [_leftTheForeground] is what says
    // this, and it may already have said it.
    if (!_inForeground) return;
    // Never seen running by this widget — a session restored at launch that had
    // already run out. Its notification fired while the app was gone.
    if (due == null) return;

    final now = ref.read(clockProvider).now();
    if (!SessionAnnouncer.watched(dueAt: due, now: now)) return;

    final settings = ref.read(settingsProvider);
    // REQ-031's choice, handed to the player rather than looked up by it —
    // the same shape as the haptics check below, and the reason is the same:
    // what the user chose is a setting, and a player is a thing that plays.
    // `EndSound.none` is one of the six and is passed like the others; it is
    // the player that knows silence costs nothing.
    unawaited(ref.read(endSoundPlayerProvider).play(settings.endSound));
    if (settings.hapticsEnabled) {
      unawaited(ref.read(hapticsProvider).sessionComplete());
    }
  }

  /// §5.4's growth shimmer and REQ-037's subtler tap, for a plant that has just
  /// reached its next stage.
  void _grew() {
    // A buzz in a pocket for something the user cannot see is noise, and so is
    // a sound. The stage will be right on screen whenever they look.
    if (!_inForeground) return;

    // Not behind the haptics switch, though it fires in the same breath.
    // REQ-037's switch is about whether the app talks to the user's *hand*;
    // turning off the buzzing is not a request for silence, and reading it as
    // one would make it a control over two things with one name on it.
    unawaited(ref.read(microSoundsProvider).play(MicroSound.growthShimmer));

    if (!ref.read(settingsProvider).hapticsEnabled) return;
    unawaited(ref.read(hapticsProvider).plantGrew());
  }

  /// Whether the plant grew between these two readings.
  ///
  /// Both must be the same plant: the first reading of a new session is a seed
  /// where the last reading of the one before it was a mature plant, and that
  /// is a session starting rather than anything growing.
  bool _grewAStage(SessionSnapshot previous, SessionSnapshot next) {
    final before = previous.growing;
    final after = next.growing;
    return before != null &&
        after != null &&
        before.sessionId == after.sessionId &&
        before.stage != after.stage;
  }

  /// Asks for permission to notify, at the first START of this run of the app.
  ///
  /// Not at launch, which is the ticket's requirement and the right one twice
  /// over: a permission dialog in front of a screen the user has not used yet
  /// is a question about nothing, and the answer to it is usually no. Asked
  /// when the user has just started the first session of the day, the question
  /// is about something they are visibly doing.
  ///
  /// Once per run rather than once ever, because neither platform asks the user
  /// twice — after a decision, both answer from it — so there is no counter to
  /// keep and nothing to store.
  void _askAboutNotifications() {
    if (_permissionAsked) return;
    _permissionAsked = true;

    unawaited(ref.read(sessionNotificationsProvider).requestPermission());
  }

  /// Hands the announcement to the system, because the app is going away.
  ///
  /// Only for something actually counting down — a running session, or a break.
  /// A held session has no end to promise: it ends however long after the user
  /// resumes it, and they can only resume it from in here.
  ///
  /// A break gets a notice for the same reason a session does, and the reason is
  /// sharper here: a break is time the user is *meant* to spend away from the
  /// phone, so it is the one countdown they are least likely to be watching.
  void _leftTheForeground() {
    _inForeground = false;

    final snapshot = ref.read(sessionControllerProvider);
    final due = snapshot.dueAt;
    if (due == null) return;

    // Read here rather than at the moment the notification fires, because there
    // is no such moment for this app: nothing of it is running then. The sound
    // the user has chosen *now* is the sound the notice is handed, and changing
    // the setting while a session is backgrounded changes the next notice
    // rather than the one already promised.
    final sound = ref.read(settingsProvider).endSound;

    final notice = switch (snapshot.phase) {
      SessionPhase.running => SessionCompletionNotice.forGrowth(
          snapshot.growing,
          at: due,
          sound: sound,
        ),
      SessionPhase.onBreak when snapshot.breakKind != null =>
        SessionCompletionNotice.forBreak(
          kind: snapshot.breakKind!,
          at: due,
          sound: sound,
        ),
      _ => null,
    };
    if (notice == null) return;

    final notifications = ref.read(sessionNotificationsProvider);
    unawaited(notifications.scheduleCompletion(notice));

    // REQ-032 with the phone face-down: the break this session earns will be
    // replayed from the instant it ends (ADR 0022), so its end is known now and
    // is announced on time. Only for a running session — a held one has no
    // end anyone can name — and only when the user asked for the break to
    // start itself. The cycle moves on when the session completes, so the
    // break on offer then is the one at the next position.
    final settings = ref.read(settingsProvider);
    if (snapshot.phase == SessionPhase.running && settings.autoStartBreak) {
      final offer = BreakOffer.at(
        snapshot.cyclePosition + 1,
        settings: settings,
      );
      final breakEnds = SessionCompletionNotice.forBreak(
        kind: offer.kind,
        at: due.add(offer.length),
        sound: sound,
      );
      unawaited(notifications.scheduleFollowUp(breakEnds));
    }
  }

  /// Takes it back, because the app can speak for itself again.
  ///
  /// Unconditional: cancelling something that was never scheduled costs
  /// nothing, and a notification that has already been delivered is cleared
  /// from the shade by the same call — which is what should happen to news the
  /// user is now looking at the app about.
  void _returnedToTheForeground() {
    _inForeground = true;
    _cancelNotice();
  }

  void _cancelNotice() {
    unawaited(ref.read(sessionNotificationsProvider).cancelCompletion());
  }
}
