import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../feedback/feedback_providers.dart';
import '../../feedback/micro_sounds.dart';
import '../../garden/growing_plant.dart';
import '../../session/session_announcer.dart';
import '../../session/session_providers.dart';
import '../../settings/settings_providers.dart';
import '../../shell/tab.dart';
import '../../time/clock_provider.dart';
import '../onboarding/coach_marks.dart';
import 'ambience_picker.dart';
import 'countdown.dart';
import 'session_ring.dart';

/// The focus timer: start a session, watch it run, see it finish.
class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(AppTab.timer.label)),
      body: SafeArea(
        // Scrollable, with the ring sized to the room left over, so a small
        // phone at a large text scale shows the whole screen rather than
        // overflowing it.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: Spacing.screenPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _TimerBody(ringDiameter: _ringDiameter(constraints)),
            ),
          ),
        ),
      ),
    );
  }

  /// The ring takes the room it can have: not so wide that it touches the edges
  /// of a large screen, not so tall that it crowds out the controls on a short
  /// one.
  ///
  /// The share of the height came down from 0.45 when ticket 05 gave a running
  /// session two controls to show. CANCEL and PAUSE are the whole of what the
  /// user can do while a session runs, and a screen that puts them below the
  /// fold has buried its own controls to make its ring bigger.
  static double _ringDiameter(BoxConstraints constraints) {
    final fromWidth = constraints.maxWidth - Spacing.md * 2;
    final fromHeight = constraints.maxHeight * 0.4;
    return (fromWidth < fromHeight ? fromWidth : fromHeight).clamp(140, 280);
  }
}

class _TimerBody extends ConsumerWidget {
  const _TimerBody({required this.ringDiameter});

  final double ringDiameter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(sessionControllerProvider);
    final theme = Theme.of(context);
    final garden = GardenColors.of(context);

    // Before the first session of the app's life there is nothing to count
    // down, so the ring shows the length of the session about to be started —
    // which is how a change made in settings shows up here without the running
    // session's countdown ever moving.
    final remaining = snapshot.phase == SessionPhase.idle
        ? ref.watch(settingsProvider).sessionLength
        : snapshot.remaining;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          switch (snapshot.phase) {
            SessionPhase.idle => 'Ready to focus',
            SessionPhase.running => 'Focusing',
            SessionPhase.paused => 'Paused',
            SessionPhase.completed => 'Session complete',
            // The kind is named, because a long break is the thing the cycle
            // has been counting towards and a user who has earned one should be
            // told they have.
            SessionPhase.onBreak =>
              snapshot.breakKind == BreakKind.long ? 'Long break' : 'On a break',
            SessionPhase.breakOver => 'Break over',
          },
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: Spacing.xl),
        Semantics(
          // The digits on their own read out as "twenty-five colon zero zero".
          label: '${formatCountdown(remaining)} remaining',
          child: SessionRing(
            // What the first of US-003's coach marks points at. The key is
            // carried by the real ring rather than by anything the tutorial
            // owns, which is the whole of what "over the live UI" asks of this
            // screen.
            key: CoachMarkTargets.timer,
            progress: snapshot.progress,
            // The one moment the bloom accent is spent: a finished session.
            // A held session drops back to the muted text colour, so the ring
            // reads as stopped from across a desk rather than only up close.
            //
            // A break takes the sky. It is the restful half of the treatment
            // the ticket asks for and it is the one colour on this screen that
            // is not about growing something: green is the session, and a break
            // that filled a green ring would look like work being done.
            color: switch (snapshot.phase) {
              SessionPhase.completed => garden.bloom,
              SessionPhase.paused => garden.textSecondary,
              SessionPhase.onBreak || SessionPhase.breakOver => garden.skyDay,
              _ => null,
            },
            diameter: ringDiameter,
            child: Text(
              formatCountdown(remaining),
              style: GardenTypography.timerDigitsInRing(ringDiameter)
                  .copyWith(color: garden.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        // The other half of the ring: the ring says how much time is left, the
        // plant says what the time is buying. Before the first session it is a
        // bed of bare soil, which is the invitation.
        GrowingPlant(
          growth: snapshot.growing,
          size: ringDiameter * 0.5,
          // §5.3's bloom, for a completion the user watched. One that ran out
          // with the app away is found complete on the way back in, and the
          // rule that keeps the chime quiet then keeps the petals in as well.
          completed: _watchedComplete(snapshot, ref),
          // §5.4's soil settle, at §5.4's moment — "seed planted", which §5.3
          // puts at the *end* of the 0.8-second drop. The plant knows when it
          // landed and this screen knows that landing makes a sound; see
          // [GrowingPlant.onLanded] for why those are two jobs.
          onLanded: () => _play(ref, MicroSound.soilSettle),
        ),
        const SizedBox(height: Spacing.md),
        // The controls come before anything explaining them. What the user can
        // do stays as close to the ring as the layout allows, so that on the
        // shortest supported screen it is the prose that falls below the fold
        // and never the buttons.
        switch (snapshot.phase) {
          SessionPhase.running ||
          SessionPhase.paused =>
            const _RunningControls(),
          SessionPhase.completed => const _BreakOffered(),
          SessionPhase.onBreak => const _BreakControls(),
          // Nothing is counting down and nothing is on offer, so there is one
          // thing to do. A break that ran its course lands here too: it is a
          // restful idle, and START is what is left.
          SessionPhase.idle || SessionPhase.breakOver => const _StartButton(),
        },
        // Only rendered when there is something to say. An empty [Text] still
        // takes a line, and lines are what this screen is short of.
        if (_noteFor(snapshot) case final note?) ...[
          const SizedBox(height: Spacing.md),
          Text(
            note,
            textAlign: TextAlign.center,
            // Tabular, because the paused note has a duration counting up in
            // the middle of it and a sentence that re-centres every second is
            // the same jitter the countdown is forbidden from having.
            style: theme.textTheme.labelSmall?.copyWith(
              color: garden.textSecondary,
              fontFeatures: GardenTypography.tabularFigures,
            ),
          ),
        ],
        // REQ-012, below the controls on purpose. The bed is a thing the user
        // sets and forgets, and CANCEL and PAUSE are the things they may need
        // in a hurry — so the picker takes the space under the fold on the
        // shortest supported screen and the buttons never do.
        const SizedBox(height: Spacing.lg),
        const AmbiencePicker(),
        const SizedBox(height: Spacing.lg),
        const _SessionsGrown(),
      ],
    );
  }
}

/// Whether [snapshot] is a session that has completed in front of the user,
/// this moment, rather than one found complete afterwards.
///
/// Read off the clock at the build the completion causes. A later rebuild of
/// the same finished session reads false, which [GrowingPlant] ignores — it
/// blooms on the turn to true and on nothing else.
bool _watchedComplete(SessionSnapshot snapshot, WidgetRef ref) {
  final due = snapshot.dueAt;
  return snapshot.phase == SessionPhase.completed &&
      due != null &&
      SessionAnnouncer.watched(dueAt: due, now: ref.read(clockProvider).now());
}

/// What the screen has to say under the plant, or null when it has nothing.
String? _noteFor(SessionSnapshot snapshot) => switch (snapshot.phase) {
      SessionPhase.running =>
        'The session ends on its own. Nothing to do but focus.',
      // REQ-009, said plainly: a pause is not free, and it is not a punishment
      // either. The number counts up so that the cost is something the user
      // watches rather than something they find out about afterwards.
      SessionPhase.paused =>
        'Paused for ${formatElapsed(snapshot.pausedSoFar)}. '
            'Your plant is still growing, at half speed.',
      // The other half of the restful treatment, and the honest one: a break
      // grows nothing, and the screen says so rather than leaving the user to
      // wonder what the empty soil means. It is not a loss — the plant the last
      // session grew is already in the garden.
      SessionPhase.onBreak =>
        'Nothing is growing while you rest. The break ends on its own.',
      SessionPhase.idle ||
      SessionPhase.completed ||
      SessionPhase.breakOver =>
        null,
    };

/// One of §9.2's micro-sounds, from this screen. Two of the four start here.
void _play(WidgetRef ref, MicroSound sound) {
  unawaited(ref.read(microSoundsProvider).play(sound));
}

/// §9.2's button tap, and the five actions that get one.
///
/// **The list is the requirement.** §9.2 says "button tap" and this app has a
/// great many buttons; a sound on all of them is a different product from the
/// one PRD §2 describes, and an app that clicks at every settings row is not it.
/// So the five here are the actions that *start or end something* — the taps
/// that change what the app is doing — and everything else on every screen stays
/// silent: settings, tabs, the theme and ambience pickers, dismissing a card.
///
/// It sits at the controls rather than in `SessionController` on purpose. The
/// same methods are called with nobody touching anything — REQ-032 starts a
/// break and the session after it on their own — and those are not taps. A
/// sound in the controller would make the app click at itself while the user's
/// phone is in their pocket.
void _tapped(WidgetRef ref) => _play(ref, MicroSound.buttonTap);

/// The one thing to do when nothing is counting down.
class _StartButton extends ConsumerWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
        onPressed: () {
          _tapped(ref);
          ref.read(sessionControllerProvider.notifier).start();
        },
        child: const Text('Start'),
      );
}

/// What a finished session offers: the break it earned, and the option of not
/// taking it.
///
/// The break is the filled button because it is what the app is recommending —
/// a Pomodoro is a session *and* the rest after it, and an app that made the
/// rest the quiet option would be selling half of its own method. Starting
/// straight into the next session is still one tap, because the user's day is
/// theirs.
///
/// The length is named on the button rather than left to the user to remember,
/// and it follows the offer: a break at the end of a cycle says fifteen minutes
/// where the three before it said five.
class _BreakOffered extends ConsumerWidget {
  const _BreakOffered();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = ref.watch(breakOnOfferProvider);
    final session = ref.read(sessionControllerProvider.notifier);

    // A [Wrap] for the reason [_RunningControls] uses one: on the smallest
    // supported phone at a large text size the two do not fit on one line.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.md,
      runSpacing: Spacing.sm,
      children: [
        TextButton(
          onPressed: () {
            _tapped(ref);
            session.start();
          },
          child: const Text('Start'),
        ),
        FilledButton(
          onPressed: () {
            _tapped(ref);
            session.startBreak();
          },
          child: Text(
            switch (offer.kind) {
              BreakKind.short => 'Take a ${offer.length.inMinutes} min break',
              BreakKind.long =>
                'Take a ${offer.length.inMinutes} min long break',
            },
          ),
        ),
      ],
    );
  }
}

/// The one control a break has: the way out of it.
///
/// Quiet, and alone. There is nothing to pause, nothing to cancel and nothing
/// to hurry — the break ends by itself — so the screen offers a single text
/// button rather than pushing a filled one at somebody it has just told to
/// rest. Leaving lands in idle, where START is waiting.
class _BreakControls extends ConsumerWidget {
  const _BreakControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
        onPressed: ref.read(sessionControllerProvider.notifier).skipBreak,
        child: const Text('Skip break'),
      );
}

/// PRD §5.2's two controls for a session in flight: leave, or hold.
///
/// Cancel is the quieter of the two by design. Pausing is a thing the user
/// should feel free to do; abandoning twenty minutes of work is not, and the
/// button that does it should not sit under the thumb that was reaching for
/// PAUSE.
class _RunningControls extends ConsumerWidget {
  const _RunningControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaused =
        ref.watch(sessionControllerProvider).phase == SessionPhase.paused;
    final session = ref.read(sessionControllerProvider.notifier);

    // A [Wrap] rather than a [Row]: on the smallest supported phone at a large
    // text size the two buttons are wider than the screen, and stacking them is
    // the answer that keeps both reachable. A row would clip PAUSE.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.md,
      runSpacing: Spacing.sm,
      children: [
        TextButton(
          // No sound here. This tap opens a question rather than answering
          // one — nothing has ended yet — and the sound is in [_cancel], on
          // the confirmation that actually abandons the session.
          onPressed: () =>
              _cancel(context, ref.read(microSoundsProvider), session),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            _tapped(ref);
            isPaused ? session.resume() : session.pause();
          },
          icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
          label: Text(isPaused ? 'Resume' : 'Pause'),
        ),
      ],
    );
  }

  /// Asks first. Cancelling is the one action on this screen that destroys
  /// something the user has already spent time on, and it is one tap away from
  /// the button they reach for to keep it.
  ///
  /// Takes the controller and the sounds rather than a `WidgetRef`, and that is
  /// not a style preference: the session can *finish* while this dialog is
  /// open, and when it does these controls are replaced by START and this
  /// widget leaves the tree. A `ref` read after the await would then be a read
  /// through a deactivated element, which throws. Both are taken before the
  /// dialog opens for exactly that reason.
  Future<void> _cancel(
    BuildContext context,
    MicroSounds sounds,
    SessionController session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this session?'),
        content: const Text(
          'The plant you are growing will not be planted, and nothing will be '
          'added to your garden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep focusing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel session'),
          ),
        ],
      ),
    );

    // The session has been running while the dialog was open, and may even have
    // finished under it. The controller is what decides whether there is still
    // anything to cancel — a session that reached its planned duration while
    // the user was deciding was earned, and confirming here does not un-earn
    // it.
    if (!(confirmed ?? false)) return;

    // §9.2's tap on the confirmation rather than on the button that opened the
    // dialog: this is the tap that ends something, and backing out of the
    // question ends nothing.
    unawaited(sounds.play(MicroSound.buttonTap));
    await session.cancel();
  }
}

/// How many sessions the user has completed, ever.
///
/// Read from the database rather than counted in memory, so it reads the same
/// after a relaunch as it did before one — which is the whole point of
/// recording sessions at all.
class _SessionsGrown extends ConsumerWidget {
  const _SessionsGrown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: GardenColors.of(context).textSecondary);

    return ref.watch(completedSessionsProvider).when(
          data: (sessions) => Text(
            switch (sessions.length) {
              0 => 'No sessions grown yet',
              1 => '1 session grown',
              final count => '$count sessions grown',
            },
            style: style,
          ),
          loading: () => const SizedBox(height: Spacing.md),
          error: (_, _) => Text('Could not read your garden', style: style),
        );
  }
}
