import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/sky_band_backdrop.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../feedback/feedback_providers.dart';
import '../../feedback/micro_sounds.dart';
import '../../garden/growing_plant.dart';
import '../../onboarding/onboarding.dart';
import '../../onboarding/onboarding_providers.dart';
import '../../session/session_announcer.dart';
import '../../session/session_providers.dart';
import '../../settings/settings_providers.dart';
import '../../time/clock_provider.dart';
import '../../shell/torn_edge.dart';
import '../onboarding/coach_marks.dart';
import 'ambience_picker.dart';
import 'countdown.dart';
import 'potted_plant.dart';
import 'progress_strip.dart';

/// The focus timer: start a session, watch it run, see it finish.
///
/// PRD v2.3's Paper Theatre: no app bar — the tab bar names the tab — a large
/// countdown under a band of sky, the plant growing in a clay pot, and a strip
/// of paper filling across as the session is spent.
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  /// How long the pot takes to make room for the first coach mark, and to
  /// take it back.
  static const Duration makingRoom = Duration(milliseconds: 300);

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  final GlobalKey _controlsKey = GlobalKey(debugLabel: 'timer.controls');

  /// Room along the bottom for the tab bar's torn edge, which rises over the
  /// screen.
  static final EdgeInsets _padding =
      Spacing.screenPadding + const EdgeInsets.only(bottom: TornEdge.height);

  /// The height the pot was last drawn at.
  double _drawn = 0;

  /// The pot's height that puts the controls just above the first coach
  /// mark's card, or null before it has been worked out.
  double? _fitted;

  @override
  Widget build(BuildContext context) {
    final coached = ref.watch(onboardingProvider).mark == CoachMark.timer;
    if (!coached) _fitted = null;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Outside the safe area, so the band of sky runs up under the
          // status bar.
          const SkyBandBackdrop(),
          SafeArea(
        // Scrollable, with the pot sized to the room left over, so a small
        // phone at a large text scale shows the whole screen rather than
        // overflowing it.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final full = _stageHeight(constraints);
            final fitted = _fitted;
            return ValueListenableBuilder<double?>(
              valueListenable: CoachMarkLayer.timerCardTop,
              builder: (context, cardTop, _) {
                if (coached && cardTop != null) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _fit(cardTop));
                }
                return TweenAnimationBuilder<double>(
                  tween: Tween(
                    end: coached && fitted != null && fitted < full
                        ? fitted
                        : full,
                  ),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : TimerScreen.makingRoom,
                  curve: Curves.easeInOut,
                  onEnd: () {
                    if (coached && cardTop != null) _fit(cardTop);
                  },
                  builder: (context, height, _) => SingleChildScrollView(
                    padding: _padding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - _padding.vertical,
                      ),
                      child: _TimerBody(
                        stageHeight: _drawn = height,
                        controlsKey: _controlsKey,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
          ),
        ],
      ),
    );
  }

  /// Works out how small the pot has to be for CANCEL and PAUSE to sit above
  /// the first coach mark's card, whose top is at [cardTop].
  ///
  /// The pot is the only thing above the controls that changes size, so the
  /// controls move by whatever it gives up. Measured off the frame just drawn,
  /// and again after the next one until it stops changing: the column is
  /// centred when it is shorter than the screen, which moves its top too.
  void _fit(double cardTop) {
    if (!mounted) return;
    final controls = _controlsKey.currentContext?.findRenderObject();
    if (controls is! RenderBox || !controls.hasSize) return;
    final bottom = controls.localToGlobal(Offset(0, controls.size.height)).dy;
    final fitted = (_drawn - (bottom - cardTop)).clamp(64.0, 280.0);
    if (_fitted == null || (fitted - _fitted!).abs() > 0.5) {
      setState(() => _fitted = fitted);
    }
  }

  /// The pot takes the room it can have: not so wide that it touches the
  /// edges of a large screen, not so tall that it crowds out the controls on a
  /// short one.
  ///
  /// A smaller share of the height than the ring had, because the countdown
  /// now stands above the pot rather than inside it. CANCEL and PAUSE are the
  /// whole of what the user can do while a session runs, and a screen that
  /// puts them below the fold has buried its own controls to make its pot
  /// bigger.
  static double _stageHeight(BoxConstraints constraints) {
    final fromWidth = constraints.maxWidth - Spacing.md * 2;
    final fromHeight = constraints.maxHeight * 0.32;
    return (fromWidth < fromHeight ? fromWidth : fromHeight).clamp(120, 280);
  }
}

class _TimerBody extends ConsumerWidget {
  const _TimerBody({required this.stageHeight, required this.controlsKey});

  /// How tall the plant and its pot stand.
  final double stageHeight;

  /// Carried by the controls, so the screen can tell where they end.
  final GlobalKey controlsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(sessionControllerProvider);
    final theme = Theme.of(context);
    final garden = GardenColors.of(context);

    // Before the first session of the app's life there is nothing to count
    // down, so the countdown shows the length of the session about to be
    // started — which is how a change made in settings shows up here without
    // the running session's countdown ever moving.
    final remaining = snapshot.phase == SessionPhase.idle
        ? ref.watch(settingsProvider).sessionLength
        : snapshot.remaining;
    // Not while the first coach mark is up: its card says the same thing,
    // and the line it would take is what keeps PAUSE above the card.
    final coached = ref.watch(onboardingProvider).mark == CoachMark.timer;
    final note = coached ? null : _noteFor(snapshot);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Where the session is, and — once something is growing — what it is.
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                switch (snapshot.phase) {
                  SessionPhase.idle => 'Ready to focus',
                  SessionPhase.running => 'Focusing',
                  SessionPhase.paused => 'Paused',
                  SessionPhase.completed => 'Session complete',
                  // The kind is named, because a long break is the thing the
                  // cycle has been counting towards and a user who has earned
                  // one should be told they have.
                  SessionPhase.onBreak => snapshot.breakKind == BreakKind.long
                      ? 'Long break'
                      : 'On a break',
                  SessionPhase.breakOver => 'Break over',
                },
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: garden.textPrimary),
              ),
            ),
            if (_growingNow(snapshot) case final growth?) ...[
              const SizedBox(width: Spacing.sm),
              Text(
                growth.species.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: garden.textPrimary,
                  fontWeight: GardenTypography.headingWeight,
                ),
              ),
            ],
          ],
        ),
        Semantics(
          // The digits on their own read out as "twenty-five colon zero zero".
          label: '${formatCountdown(remaining)} remaining',
          excludeSemantics: true,
          // Scaled down rather than wrapped or clipped: at the largest text
          // sizes on the smallest phone five digits this big are wider than
          // the screen, and a countdown is no use in two halves.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCountdown(remaining),
              style: GardenTypography.timerDigitsFor(
                MediaQuery.sizeOf(context).width,
              ).copyWith(color: garden.textPrimary),
            ),
          ),
        ),
        // Only rendered when there is something to say. An empty [Text] still
        // takes a line, and lines are what this screen is short of.
        if (note != null)
          Text(
            note,
            // Tabular, because the paused note has a duration counting up in
            // the middle of it and a sentence that reflows every second is the
            // same jitter the countdown is forbidden from having.
            style: theme.textTheme.bodyMedium?.copyWith(
              color: garden.textSecondary,
              fontFeatures: GardenTypography.tabularFigures,
            ),
          ),
        const SizedBox(height: Spacing.md),
        // What the time is buying. Before the first session it is a pot of
        // bare soil, which is the invitation.
        Center(
          child: PottedPlant(
            // What the first of US-003's coach marks points at. The key is
            // carried by the real pot rather than by anything the tutorial
            // owns, which is the whole of what "over the live UI" asks of this
            // screen.
            key: CoachMarkTargets.timer,
            growth: snapshot.growing,
            height: stageHeight,
            // §5.3's bloom, for a completion the user watched. One that ran
            // out with the app away is found complete on the way back in, and
            // the rule that keeps the chime quiet then keeps the petals in as
            // well.
            completed: _watchedComplete(snapshot, ref),
            // §5.4's soil settle, at §5.4's moment — "seed planted", which §5.3
            // puts at the *end* of the 0.8-second drop. The plant knows when it
            // landed and this screen knows that landing makes a sound; see
            // [GrowingPlant.onLanded] for why those are two jobs.
            onLanded: () => _play(ref, MicroSound.soilSettle),
          ),
        ),
        const SizedBox(height: Spacing.md),
        ProgressStrip(
          progress: snapshot.progress,
          // The one moment the bloom accent is spent: a finished session. A
          // held session drops back to the muted text colour, so the strip
          // reads as stopped from across a desk rather than only up close.
          //
          // A break takes the sky. It is the restful half of the treatment the
          // ticket asks for and it is the one colour on this screen that is
          // not about growing something: a break that filled the strip in the
          // session's marigold would look like work being done.
          color: switch (snapshot.phase) {
            SessionPhase.completed => garden.bloom,
            SessionPhase.paused => garden.textSecondary,
            SessionPhase.onBreak || SessionPhase.breakOver => garden.skyDay,
            _ => null,
          },
        ),
        const SizedBox(height: Spacing.xs),
        _StripTimes(snapshot: snapshot),
        const SizedBox(height: Spacing.md),
        // The controls come before anything else below the pot. What the user
        // can do stays as close to the countdown as the layout allows, so that
        // on the shortest supported screen it is the picker that falls below
        // the fold and never the buttons.
        KeyedSubtree(
          key: controlsKey,
          child: Center(
            child: switch (snapshot.phase) {
              SessionPhase.running ||
              SessionPhase.paused =>
                const _RunningControls(),
              SessionPhase.completed => const _BreakOffered(),
              SessionPhase.onBreak => const _BreakControls(),
              // Nothing is counting down and nothing is on offer, so there is
              // one thing to do. A break that ran its course lands here too: it
              // is a restful idle, and PLANT IT is what is left.
              SessionPhase.idle ||
              SessionPhase.breakOver =>
                const _StartButton(),
            },
          ),
        ),
        // REQ-012, below the controls on purpose. The bed is a thing the user
        // sets and forgets, and CANCEL and PAUSE are the things they may need
        // in a hurry — so the picker takes the space under the fold on the
        // shortest supported screen and the buttons never do.
        const SizedBox(height: Spacing.lg),
        const AmbiencePicker(),
        const SizedBox(height: Spacing.lg),
        const Center(child: _SessionsGrown()),
      ],
    );
  }
}

/// What is growing in the pot right now, or null when nothing is — before the
/// first session, and through a break, which grows nothing.
PlantGrowth? _growingNow(SessionSnapshot snapshot) => switch (snapshot.phase) {
      SessionPhase.running ||
      SessionPhase.paused ||
      SessionPhase.completed =>
        snapshot.growing,
      _ => null,
    };

/// The two ends of the strip, said as times of day: when this session was
/// planted and when it will be ready — or, through a break, when it ends.
///
/// Kept in the layout when there is nothing to say, so the screen does not
/// jump by a line as a session starts and finishes.
class _StripTimes extends StatelessWidget {
  const _StripTimes({required this.snapshot});

  final SessionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = snapshot.dueAt;
    final localizations = MaterialLocalizations.of(context);
    final twentyFour = MediaQuery.alwaysUse24HourFormatOf(context);
    String at(DateTime instant) => localizations.formatTimeOfDay(
          TimeOfDay.fromDateTime(instant.toLocal()),
          alwaysUse24HourFormat: twentyFour,
        );

    // The planted instant is the due one, less the session and every pause in
    // it: [SessionSnapshot.dueAt] moves out by exactly as long as the session
    // has been held.
    final held = snapshot.elapsed + snapshot.remaining + snapshot.pausedSoFar;

    final (String, String)? ends = switch ((snapshot.phase, due)) {
      (SessionPhase.running || SessionPhase.paused, final due?) =>
        ('Planted ${at(due.subtract(held))}', 'Ready ${at(due)}'),
      (SessionPhase.onBreak, final due?) => ('Resting', 'Back at ${at(due)}'),
      _ => null,
    };

    final style = theme.textTheme.labelSmall?.copyWith(
      color: GardenColors.of(context).textSecondary,
      fontWeight: GardenTypography.headingWeight,
      fontFeatures: GardenTypography.tabularFigures,
    );
    return Visibility(
      visible: ends != null,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Row(
        children: [
          Expanded(child: Text(ends?.$1 ?? ' ', style: style, maxLines: 1)),
          Text(ends?.$2 ?? ' ', style: style, maxLines: 1),
        ],
      ),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      // Marigold, as the garden's PLANT IT is: the one warm accent in the
      // chrome, kept for the action a screen is for.
      style: FilledButton.styleFrom(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
      ),
      onPressed: () {
        _tapped(ref);
        ref.read(sessionControllerProvider.notifier).start();
      },
      child: const Text('Plant it'),
    );
  }
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
          child: const Text('Plant another'),
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
/// Cancel is the quieter of the two by design — an outline beside a filled
/// button. Pausing is a thing the user
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
        OutlinedButton(
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
          'The plant you\'re growing won\'t be planted.',
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
          error: (_, _) => Text('Couldn\'t read your garden', style: style),
        );
  }
}
