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

/// The focus timer: countdown under a band of sky, the plant in its pot, and
/// a progress strip.
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  /// How long the pot takes to shrink for the first coach mark, and grow back.
  static const Duration makingRoom = Duration(milliseconds: 300);

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  final GlobalKey _controlsKey = GlobalKey(debugLabel: 'timer.controls');

  /// Leaves room for the tab bar's torn edge.
  static final EdgeInsets _padding =
      Spacing.screenPadding + const EdgeInsets.only(bottom: TornEdge.height);

  double _drawn = 0;

  /// Pot height that puts the controls just above the first coach mark's
  /// card. Null until measured.
  double? _fitted;

  @override
  Widget build(BuildContext context) {
    final coached = ref.watch(onboardingProvider).mark == CoachMark.timer;
    if (!coached) _fitted = null;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Outside SafeArea so the sky runs up under the status bar.
          const SkyBandBackdrop(),
          SafeArea(
        // Scrollable so small phones at large text scales don't overflow.
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

  /// Shrinks the pot until CANCEL and PAUSE sit above the coach mark card at
  /// [cardTop]. Re-measured each frame until stable, since the column is
  /// centred and its top moves too.
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

  /// Capped by width and by a share of the height, so the controls stay above
  /// the fold on short screens.
  static double _stageHeight(BoxConstraints constraints) {
    final fromWidth = constraints.maxWidth - Spacing.md * 2;
    final fromHeight = constraints.maxHeight * 0.32;
    return (fromWidth < fromHeight ? fromWidth : fromHeight).clamp(120, 280);
  }
}

class _TimerBody extends ConsumerWidget {
  const _TimerBody({required this.stageHeight, required this.controlsKey});

  final double stageHeight;

  /// Lets the screen measure where the controls end.
  final GlobalKey controlsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(sessionControllerProvider);
    final theme = Theme.of(context);
    final garden = GardenColors.of(context);

    // When idle, show the configured session length, so settings changes show
    // up here.
    final remaining = snapshot.phase == SessionPhase.idle
        ? ref.watch(settingsProvider).sessionLength
        : snapshot.remaining;
    // Hidden during the first coach mark: the card says the same thing, and
    // the extra line would push PAUSE under it.
    final coached = ref.watch(onboardingProvider).mark == CoachMark.timer;
    final note = coached ? null : _noteFor(snapshot);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  // Name the long break; it's what the cycle counts towards.
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
          // Otherwise it reads as "twenty-five colon zero zero".
          label: '${formatCountdown(remaining)} remaining',
          excludeSemantics: true,
          // Scale down rather than wrap at huge text sizes.
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
        // An empty Text still takes a line.
        if (note != null)
          Text(
            note,
            // Tabular: the paused note has a counter in it.
            style: theme.textTheme.bodyMedium?.copyWith(
              color: garden.textSecondary,
              fontFeatures: GardenTypography.tabularFigures,
            ),
          ),
        const SizedBox(height: Spacing.md),
        Center(
          child: PottedPlant(
            // First coach mark target.
            key: CoachMarkTargets.timer,
            growth: snapshot.growing,
            height: stageHeight,
            // Bloom only if the user saw it finish, not if it was found
            // complete on returning to the app.
            completed: _watchedComplete(snapshot, ref),
            // Soil settle plays when the seed lands, at the end of the drop.
            // See [GrowingPlant.onLanded].
            onLanded: () => _play(ref, MicroSound.soilSettle),
          ),
        ),
        const SizedBox(height: Spacing.md),
        ProgressStrip(
          progress: snapshot.progress,
          // Bloom colour only for a finished session; muted when paused so it
          // reads as stopped from a distance; sky for breaks.
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
        // Controls before anything else under the pot, so on short screens
        // it's the picker that falls below the fold, not the buttons.
        KeyedSubtree(
          key: controlsKey,
          child: Center(
            child: switch (snapshot.phase) {
              SessionPhase.running ||
              SessionPhase.paused =>
                const _RunningControls(),
              SessionPhase.completed => const _BreakOffered(),
              SessionPhase.onBreak => const _BreakControls(),
              // A finished break is a restful idle too.
              SessionPhase.idle ||
              SessionPhase.breakOver =>
                const _StartButton(),
            },
          ),
        ),
        // Ambience picker below the controls on purpose (see above).
        const SizedBox(height: Spacing.lg),
        const AmbiencePicker(),
        const SizedBox(height: Spacing.lg),
        const Center(child: _SessionsGrown()),
      ],
    );
  }
}

/// What's in the pot now. Null before the first session and during breaks.
PlantGrowth? _growingNow(SessionSnapshot snapshot) => switch (snapshot.phase) {
      SessionPhase.running ||
      SessionPhase.paused ||
      SessionPhase.completed =>
        snapshot.growing,
      _ => null,
    };

/// Start and end times under the strip. Keeps its size when empty so the layout
/// doesn't jump.
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

    // dueAt moves out by every pause, so planted = due - (session + pauses).
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

/// True only at the build where the session completes in front of the user.
/// Later rebuilds read false, which [GrowingPlant] ignores (it blooms on the
/// edge to true).
bool _watchedComplete(SessionSnapshot snapshot, WidgetRef ref) {
  final due = snapshot.dueAt;
  return snapshot.phase == SessionPhase.completed &&
      due != null &&
      SessionAnnouncer.watched(dueAt: due, now: ref.read(clockProvider).now());
}

String? _noteFor(SessionSnapshot snapshot) => switch (snapshot.phase) {
      SessionPhase.running =>
        'The session ends on its own. Nothing to do but focus.',
      // The counter makes the cost of a pause visible as it happens.
      SessionPhase.paused =>
        'Paused for ${formatElapsed(snapshot.pausedSoFar)}. '
            'Your plant is still growing, at half speed.',
      SessionPhase.onBreak =>
        'Nothing is growing while you rest. The break ends on its own.',
      SessionPhase.idle ||
      SessionPhase.completed ||
      SessionPhase.breakOver =>
        null,
    };

void _play(WidgetRef ref, MicroSound sound) {
  unawaited(ref.read(microSoundsProvider).play(sound));
}

/// Button tap sound. Only on the five actions that start or end something;
/// everything else stays silent.
///
/// Played here, not in `SessionController`, because auto-start calls the same
/// methods with nobody touching the phone.
void _tapped(WidgetRef ref) => _play(ref, MicroSound.buttonTap);

class _StartButton extends ConsumerWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      // Marigold, same as the garden's PLANT IT.
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

/// After a session: take the break (the recommended, filled button) or start
/// another. The button names the break length, which is longer at the end of a
/// cycle.
class _BreakOffered extends ConsumerWidget {
  const _BreakOffered();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = ref.watch(breakOnOfferProvider);
    final session = ref.read(sessionControllerProvider.notifier);

    // Wrap so the two buttons stack on small phones at large text sizes.
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

/// Just a quiet skip button; the break ends by itself.
class _BreakControls extends ConsumerWidget {
  const _BreakControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
        onPressed: ref.read(sessionControllerProvider.notifier).skipBreak,
        child: const Text('Skip break'),
      );
}

/// Cancel is an outline next to a filled PAUSE so it isn't hit by accident.
class _RunningControls extends ConsumerWidget {
  const _RunningControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaused =
        ref.watch(sessionControllerProvider).phase == SessionPhase.paused;
    final session = ref.read(sessionControllerProvider.notifier);

    // Wrap, not Row: a Row would clip PAUSE on small phones at large text.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.md,
      runSpacing: Spacing.sm,
      children: [
        OutlinedButton(
          // No sound here; it plays in [_cancel] on confirmation.
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

  /// Confirms first.
  ///
  /// Takes the controller and sounds rather than a `WidgetRef`: the session can
  /// finish while the dialog is open, this widget leaves the tree, and reading
  /// `ref` after the await would throw.
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

    // The session may have finished while the dialog was open. The controller
    // decides whether there's still anything to cancel; a completed one stays
    // completed.
    if (!(confirmed ?? false)) return;

    unawaited(sounds.play(MicroSound.buttonTap));
    await session.cancel();
  }
}

/// Lifetime completed sessions, read from the database so it survives
/// relaunches.
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
