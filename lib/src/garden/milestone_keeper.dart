import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../feedback/feedback_providers.dart';
import '../feedback/micro_sounds.dart';
import '../features/garden/milestone_card.dart';
import '../session/session_providers.dart';
import 'growing_plant.dart';
import 'milestone_providers.dart';

/// When a bonus plant is celebrated: REQ-021's "quiet celebration".
///
/// The last of the widgets wrapped around the shell, and divided from the
/// others the same way they are divided from each other — by what it answers
/// to. `SessionAnnouncer` is what a session ending *says*; this is what a
/// milestone being reached says, and it is deliberately the quieter of the two.
///
/// Watching [milestoneAwardsProvider] is also what keeps the awarding alive: a
/// provider nobody reads is a provider that never builds, and the awards have
/// to be made whether or not anything is on screen to show them.
///
/// Two rules decide the timing, and both are about staying out of the way:
///
/// **Nothing interrupts a countdown.** A session running, a session held, a
/// break — none of them is a moment to put a sheet in front of somebody. The
/// award is already in the garden by then; only the celebration waits, and it
/// waits as long as it has to.
///
/// **A milestone reached at the end of a session follows that session's own
/// ending rather than competing with it.** The completing session has a chime,
/// a haptic and a plant blooming at its last stage, and a sheet sliding up
/// through the middle of that would make two events out of one moment. So the
/// celebration waits out [afterTheSession] first — long enough for §5.3's
/// session end bloom to finish — and only then rises.
///
/// A backlog is shown one card at a time, oldest milestone first, each waiting
/// on the last being dismissed. That is the launch after an upgrade, where a
/// user with thirty sessions behind them is owed two.
class MilestoneKeeper extends ConsumerStatefulWidget {
  const MilestoneKeeper({required this.child, super.key});

  final Widget child;

  /// How long a celebration hangs back after the timer comes to rest.
  ///
  /// §5.3's session end bloom runs for [GrowingPlant.bloomDuration] — two
  /// seconds — and is the last thing to move when a session completes: the
  /// growth spring it starts is over in 1.2, and the sway it settles into never
  /// ends, so it is not something to wait for. This is a little past the bloom,
  /// so the last petal has faded before anything slides over the plant —
  /// and written as the bloom plus the margin, so a bloom made longer moves
  /// this with it rather than leaving the card to rise through the new end.
  ///
  /// Public so the tests that wait for a card wait for this rather than for a
  /// number of their own that the next change to it would leave behind.
  static final Duration afterTheSession =
      GrowingPlant.bloomDuration + const Duration(milliseconds: 300);

  @override
  ConsumerState<MilestoneKeeper> createState() => _MilestoneKeeperState();
}

class _MilestoneKeeperState extends ConsumerState<MilestoneKeeper> {
  /// The wait between the timer coming to rest and the card rising.
  Timer? _waiting;

  /// Whether a card is on screen. Kept because the queue and the session both
  /// change while one is open, and each change asks again whether to show one.
  bool _showing = false;

  AppLifecycleListener? _listener;

  /// Whether the app is the thing on screen. Starts true, as `SessionAnnouncer`
  /// does and for the same reason: a widget tree is being built, which is
  /// something only a foreground app does.
  ///
  /// Here for §9.2's unlock and for nothing else. The *card* deliberately rises
  /// whether or not anybody is looking — a celebration the user never saw costs
  /// them the animation and not the plant — but a sound in an empty room is
  /// only a sound in an empty room, and [_waiting] is a real timer that goes on
  /// running when the app is put away mid-wait.
  bool _inForeground = true;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => _inForeground = true,
      onPause: () => _inForeground = false,
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    _waiting?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watched rather than listened to, so that the awarding runs for as long as
    // this widget is in the tree — which is the whole life of the app.
    ref.watch(milestoneAwardsProvider);
    // And listened to, because a session starting is what puts a pending
    // celebration back on hold.
    ref.listen(sessionControllerProvider, (_, _) => _reconsider());

    // Off the end of this frame rather than during it: showing a route from
    // inside a build is a mutation of the navigator mid-layout, and reading the
    // queue is not what decides to show anything — the timing is.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconsider());

    return widget.child;
  }

  /// Decides whether the next award may be celebrated now, later, or not yet.
  void _reconsider() {
    if (!mounted || _showing) return;

    if (ref.read(milestoneAwardsProvider).isEmpty) {
      _stopWaiting();
      return;
    }

    if (_countingDown) {
      // Back on hold. A session started while a celebration was waiting takes
      // the screen back, and the award waits for the next lull.
      _stopWaiting();
      return;
    }

    _waiting ??= Timer(MilestoneKeeper.afterTheSession, _celebrate);
  }

  /// Whether anything is counting down, and so whether the screen is the
  /// user's rather than the app's.
  bool get _countingDown => switch (ref.read(sessionControllerProvider).phase) {
        SessionPhase.running ||
        SessionPhase.paused ||
        SessionPhase.onBreak =>
          true,
        SessionPhase.idle ||
        SessionPhase.completed ||
        SessionPhase.breakOver =>
          false,
      };

  Future<void> _celebrate() async {
    _waiting = null;
    if (!mounted || _showing) return;

    // Re-read rather than captured: the wait is over two seconds, and both
    // the queue and the timer can have moved inside it.
    final queue = ref.read(milestoneAwardsProvider);
    if (queue.isEmpty || _countingDown) {
      _reconsider();
      return;
    }

    final plant = queue.first;
    _showing = true;
    // §9.2's unlock, as the card rises rather than after it — the sound is part
    // of the celebration arriving, not a comment on it. Skipped outright with
    // the app away: the card can wait to be seen, and a sound cannot.
    if (_inForeground) {
      unawaited(ref.read(microSoundsProvider).play(MicroSound.unlock));
    }
    try {
      await showMilestoneCard(context, plant);
    } finally {
      _showing = false;
      // Dropped once it has been shown, however it was dismissed — swiped,
      // tapped away, or the back gesture. The plant itself is in the garden
      // either way; this only forgets that it is owed a card.
      if (mounted) ref.read(milestoneAwardsProvider.notifier).celebrated(plant);
    }

    // On to the next one, if a backlog is owed. Through the same wait, so two
    // cards do not arrive on top of each other.
    _reconsider();
  }

  void _stopWaiting() {
    _waiting?.cancel();
    _waiting = null;
  }
}
