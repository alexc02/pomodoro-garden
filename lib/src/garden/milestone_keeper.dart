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

/// Shows the milestone card when a bonus plant is awarded.
///
/// Also keeps [milestoneAwardsProvider] alive by watching it, so awards are
/// made even when nothing else is reading them.
///
/// Timing rules: never during a running/paused session or a break, and after a
/// session ends wait [afterTheSession] so the card doesn't land on top of the
/// bloom. A backlog (e.g. after an upgrade) shows one card at a time, oldest
/// first.
class MilestoneKeeper extends ConsumerStatefulWidget {
  const MilestoneKeeper({required this.child, super.key});

  final Widget child;

  /// Delay after the timer comes to rest: the bloom plus a small margin.
  /// Public so tests can wait on it.
  static final Duration afterTheSession =
      GrowingPlant.bloomDuration + const Duration(milliseconds: 300);

  @override
  ConsumerState<MilestoneKeeper> createState() => _MilestoneKeeperState();
}

class _MilestoneKeeperState extends ConsumerState<MilestoneKeeper> {
  Timer? _waiting;

  /// Kept because the queue and the session both change while a card is up.
  bool _showing = false;

  AppLifecycleListener? _listener;

  /// Only used to skip the unlock sound when the app is backgrounded; the card
  /// still shows, since [_waiting] keeps running in the background.
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
    // Watched so awarding runs for the app's lifetime; the session listen is
    // what puts a pending celebration back on hold.
    ref.watch(milestoneAwardsProvider);
    ref.listen(sessionControllerProvider, (_, _) => _reconsider());
    // Post-frame: can't push a route during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconsider());

    return widget.child;
  }

  void _reconsider() {
    if (!mounted || _showing) return;

    if (ref.read(milestoneAwardsProvider).isEmpty) {
      _stopWaiting();
      return;
    }

    if (_countingDown) {
      // A session started while we were waiting; wait for the next lull.
      _stopWaiting();
      return;
    }

    _waiting ??= Timer(MilestoneKeeper.afterTheSession, _celebrate);
  }

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

    // Re-read: things may have changed during the wait.
    final queue = ref.read(milestoneAwardsProvider);
    if (queue.isEmpty || _countingDown) {
      _reconsider();
      return;
    }

    final plant = queue.first;
    _showing = true;
    // Sound plays as the card rises. Skipped if the app is backgrounded.
    if (_inForeground) {
      unawaited(ref.read(microSoundsProvider).play(MicroSound.unlock));
    }
    try {
      await showMilestoneCard(context, plant);
    } finally {
      _showing = false;
      // Dropped however it was dismissed; the plant is in the garden anyway.
      if (mounted) ref.read(milestoneAwardsProvider.notifier).celebrated(plant);
    }

    // Next in the backlog, via the same wait so cards don't stack.
    _reconsider();
  }

  void _stopWaiting() {
    _waiting?.cancel();
    _waiting = null;
  }
}
