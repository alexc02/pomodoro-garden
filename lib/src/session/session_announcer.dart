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

/// Sound, haptics and notifications for a session or break ending, and for a
/// plant growing a stage.
///
/// Each ending is announced exactly once. In the foreground: the end sound and
/// a haptic. In the background: a notification scheduled on pause and
/// cancelled on resume, so both never fire. A session that ended while the
/// app was away doesn't chime when it's reopened; the notification already
/// covered it.
///
/// Breaks follow the same rule. A skipped break is silent
/// (`SessionMachine.endBreak` sends it to `idle`, not `breakOver`).
class SessionAnnouncer extends ConsumerStatefulWidget {
  const SessionAnnouncer({required this.child, super.key});

  final Widget child;

  /// In the foreground the ticker catches an ending within a frame. Anything
  /// later than this was found after the fact (the notification covered it).
  static const Duration _freshly = Duration(seconds: 2);

  /// Whether an ending was seen live rather than found afterwards. Public
  /// because the timer screen's bloom animation uses it too.
  static bool watched({required DateTime dueAt, required DateTime now}) {
    final late = now.difference(dueAt);
    return !late.isNegative && late <= _freshly;
  }

  @override
  ConsumerState<SessionAnnouncer> createState() => _SessionAnnouncerState();
}

class _SessionAnnouncerState extends ConsumerState<SessionAnnouncer> {
  AppLifecycleListener? _listener;

  bool _inForeground = true;

  bool _permissionAsked = false;

  /// Due time of the current session or break, to tell a live ending from one
  /// found later. Null if none was seen running (including one restored at
  /// launch already finished).
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: _returnedToTheForeground,
      // Not `inactive`/`hidden`: those also fire for the notification shade
      // or an incoming call. `paused` means fully off screen.
      onPause: _leftTheForeground,
      // Force-quit; [SessionLifecycle] voids the session.
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

  void _sessionChanged(SessionSnapshot? previous, SessionSnapshot next) {
    if (next.phase == SessionPhase.running ||
        next.phase == SessionPhase.onBreak) {
      // From the snapshot, so it matches what the live surface shows.
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
      // Completion also bumps the stage; don't fire the growth feedback too.
      return;
    }

    // Skipped breaks go to idle, not here, so they stay silent.
    if (previous.phase != SessionPhase.breakOver &&
        next.phase == SessionPhase.breakOver) {
      _ended();
      return;
    }

    if (_grewAStage(previous, next)) _grew();
  }

  /// End sound and haptic for a session or break that just ended in the
  /// foreground.
  void _ended() {
    final due = _dueAt;
    _dueAt = null;

    // The notification handles it.
    if (!_inForeground) return;
    // Restored at launch already finished.
    if (due == null) return;

    final now = ref.read(clockProvider).now();
    if (!SessionAnnouncer.watched(dueAt: due, now: now)) return;

    final settings = ref.read(settingsProvider);
    // EndSound.none is passed through; the player handles it.
    unawaited(ref.read(endSoundPlayerProvider).play(settings.endSound));
    if (settings.hapticsEnabled) {
      unawaited(ref.read(hapticsProvider).sessionComplete());
    }
  }

  /// Growth shimmer and the light haptic for a new stage.
  void _grew() {
    if (!_inForeground) return;

    // The haptics switch only covers haptics, not this sound.
    unawaited(ref.read(microSoundsProvider).play(MicroSound.growthShimmer));

    if (!ref.read(settingsProvider).hapticsEnabled) return;
    unawaited(ref.read(hapticsProvider).plantGrew());
  }

  /// Same session only; a new session's seed isn't growth.
  bool _grewAStage(SessionSnapshot previous, SessionSnapshot next) {
    final before = previous.growing;
    final after = next.growing;
    return before != null &&
        after != null &&
        before.sessionId == after.sessionId &&
        before.stage != after.stage;
  }

  /// Asks for notification permission at the first START, not at launch, so
  /// the prompt has context. Once per run is enough; the OS remembers the
  /// answer.
  void _askAboutNotifications() {
    if (_permissionAsked) return;
    _permissionAsked = true;

    unawaited(ref.read(sessionNotificationsProvider).requestPermission());
  }

  /// Schedules the notification for a running session or break. A paused
  /// session has no end time to schedule.
  void _leftTheForeground() {
    _inForeground = false;

    final snapshot = ref.read(sessionControllerProvider);
    final due = snapshot.dueAt;
    if (due == null) return;

    // Read now; nothing of ours runs when the notice fires.
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

    // With auto-start on, the break is replayed from the session's end (ADR
    // 0022), so its end time is known now. +1 because the cycle advances on
    // completion.
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

  /// Always cancels; harmless if nothing was scheduled, and clears delivered
  /// notices too.
  void _returnedToTheForeground() {
    _inForeground = true;
    _cancelNotice();
  }

  void _cancelNotice() {
    unawaited(ref.read(sessionNotificationsProvider).cancelCompletion());
  }
}
