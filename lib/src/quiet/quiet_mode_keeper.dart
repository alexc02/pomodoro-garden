import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../session/session_providers.dart';
import '../settings/settings_providers.dart';
import '../shell/shell_providers.dart';
import '../shell/tab.dart';
import 'quiet_mode.dart';
import 'quiet_mode_providers.dart';

/// Keeps how quiet the phone is in step with what the timer is doing.
///
/// The fifth of the widgets wrapped around the shell, and divided from the
/// other four the way they are divided from each other — by what it answers to.
/// `SessionLifecycle` is what the app coming and going does to the session;
/// `SessionAnnouncer` is what a session ending *says*; `LiveSurfaceKeeper` is
/// what a session looks like from outside the app; `AmbienceKeeper` is what one
/// sounds like; this is what the *rest of the phone* is allowed to sound like
/// while one runs.
///
/// Four rules, and each of them is a decision REQ-014 left open:
///
/// **Quiet belongs to a focus session, running or held.** The same rule the bed
/// follows, for the same reason: a paused session is a session the user is
/// still in, and a phone that started ringing the moment they stepped away from
/// the desk would be answering a question they did not ask. Everything else is
/// loud — idle, completed, cancelled, and a break, which is time the user is
/// meant to be *available* in.
///
/// **Quiet is only ever asked for where the platform can deliver it.** The
/// setting says what the user wants; [QuietModeAccess] says what their phone
/// will do about it. Both have to say yes, so revoking the permission in system
/// settings takes the silence off the phone at the next resume rather than
/// leaving a switch that does nothing.
///
/// **Quiet never outlives its session, by three separate routes.** The session
/// ending takes it down; a force-quit takes it down on the way out; and a
/// launch that finds nothing in flight takes it down whether or not this app
/// believes it is on — which is the one that catches a process the system
/// killed without warning. The platform holds a deadline of its own as the last
/// line, for the app that is never launched again at all.
///
/// **A session can be asked for from outside the app.** That is iOS's whole
/// answer to REQ-014 — see [QuietMode.sessionRequests] — and it is handled here
/// rather than in the timer screen because the request arrives whatever screen
/// the user is on, and may arrive before there is a screen at all.
class QuietModeKeeper extends ConsumerStatefulWidget {
  const QuietModeKeeper({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<QuietModeKeeper> createState() => _QuietModeKeeperState();
}

class _QuietModeKeeperState extends ConsumerState<QuietModeKeeper> {
  /// The instant quiet mode was last asked to hold until, or null when the
  /// phone has been left loud.
  DateTime? _until;

  /// Whether the platform has been told anything at all yet.
  ///
  /// The first sync says something whichever way it goes, and that is the
  /// point: an app killed mid-session leaves a rule switched on behind it, and
  /// the launch after it is the first moment anything of ours can switch it
  /// off. A keeper that only spoke up when it thought something had changed
  /// would believe the phone was already loud and say nothing.
  bool _told = false;

  AppLifecycleListener? _listener;
  StreamSubscription<void>? _requests;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      // Policy access is granted and revoked in system settings, which the user
      // reaches by leaving the app. Coming back is therefore the moment the
      // answer may have changed — and the sync that follows it is what takes
      // the silence off a phone whose permission has just been taken away.
      onResume: _accessMayHaveChanged,
      // A force-quit takes the session with it — `SessionLifecycle` voids it —
      // and a phone left silent would be silent for a session that no longer
      // exists. Best-effort like every write during teardown; the platform's
      // own deadline is what covers the case where this does not land.
      onDetach: _end,
    );

    _requests = ref.read(quietModeProvider).sessionRequests.listen(_requested);

    // Once, before anything has changed. `ref.listen` fires on a change and a
    // launch is not one — so without this, a session restored at launch would
    // wait for its next tick to go quiet, a session restored *paused* would
    // wait forever, and a phone left silent by a killed process would stay
    // that way.
    _sync();
  }

  @override
  void dispose() {
    unawaited(_requests?.cancel());
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Three, because any of them can change what the phone should be doing: the
    // session by starting or ending, the settings by the user flipping the
    // switch mid-session, and the access by their having just revoked it in
    // system settings.
    ref.listen(sessionControllerProvider, (_, _) => _sync());
    ref.listen(settingsProvider, (_, _) => _sync());
    ref.listen(quietModeAccessProvider, (_, _) => _sync());
    return widget.child;
  }

  /// Puts the phone where the timer, the settings and the platform say it
  /// should be.
  void _sync() {
    final wanted = _quietUntil();

    if (wanted == null) {
      _end();
      return;
    }

    // The ask that is not worth making. A running session's due instant is the
    // same number on every tick, so quiet is asked for once and moves only when
    // the user resumes a held one. A held session's due instant moves every
    // second — it ends however long after they come back — and re-asking on
    // each of them would be sixty channel crossings a minute to re-arm a
    // deadline nothing is counting down to yet.
    if (_told && _until != null && (_held || wanted == _until)) return;

    _until = wanted;
    _told = true;
    unawaited(ref.read(quietModeProvider).begin(until: wanted));
  }

  /// When quiet mode should hold until, or null if the phone should be loud.
  DateTime? _quietUntil() {
    final settings = ref.read(settingsProvider);
    if (!settings.quietModeEnabled) return null;
    // Loading, or a phone that cannot do this. Either way there is nothing to
    // ask for; a `denied` here is a permission the user has revoked, and the
    // sync it arrives on is what takes the silence back off.
    if (ref.read(quietModeAccessProvider).value !=
        QuietModeAccess.granted) {
      return null;
    }

    final snapshot = ref.read(sessionControllerProvider);
    return switch (snapshot.phase) {
      SessionPhase.running || SessionPhase.paused => snapshot.dueAt,
      SessionPhase.idle ||
      SessionPhase.completed ||
      SessionPhase.onBreak ||
      SessionPhase.breakOver =>
        null,
    };
  }

  bool get _held =>
      ref.read(sessionControllerProvider).phase == SessionPhase.paused;

  void _end() {
    if (_told && _until == null) return;

    _until = null;
    _told = true;
    unawaited(ref.read(quietModeProvider).end());
  }

  void _accessMayHaveChanged() {
    unawaited(ref.read(quietModeAccessProvider.notifier).refresh());
  }

  /// A Shortcuts automation asked for a session. See
  /// [QuietMode.sessionRequests].
  ///
  /// Ignored unless the timer has nothing in flight, which is the same rule the
  /// START button follows — the machine refuses to start a session over a live
  /// one, and correctly. An automation that fired twice, or one the user ran
  /// while already focusing, leaves them with the session they are in rather
  /// than with an error about it.
  ///
  /// A break is in flight too, for this purpose. Walking out of a break is a
  /// decision, and it is one the user takes on the screen that is offering it
  /// rather than one a Shortcut takes for them.
  void _requested(void _) {
    const atRest = {
      SessionPhase.idle,
      SessionPhase.completed,
      SessionPhase.breakOver,
    };
    if (!atRest.contains(ref.read(sessionControllerProvider).phase)) return;

    unawaited(ref.read(sessionControllerProvider.notifier).start());
    // And show it, for the same reason a tap on the live surface does: the app
    // has just been brought forward by something the user did about a session,
    // and the screen they asked for is the one their session is on.
    ref.read(selectedTabProvider.notifier).select(AppTab.timer);
  }
}
