import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../feedback/feedback_providers.dart';
import '../../feedback/micro_sounds.dart';
import '../../onboarding/onboarding.dart';
import '../../onboarding/onboarding_providers.dart';
import '../../settings/settings_providers.dart';
import 'garden_preview.dart';

/// The controls on the flow, by name — the handles a test uses instead of
/// reaching for a word that also appears on the timer behind it.
abstract final class OnboardingKeys {
  /// The way past whichever step is on screen. Present on all three.
  static const Key skip = Key('onboarding.skip');

  /// The way on to the next step.
  static const Key next = Key('onboarding.next');

  /// The last step's one control, and the whole point of the flow.
  static const Key start = Key('onboarding.start');

  /// REQ-004's three lengths, as a group.
  static const Key lengths = Key('onboarding.lengths');

  /// One of those three.
  static Key preset(SessionPreset preset) =>
      Key('onboarding.preset.${preset.name}');
}

/// REQ-003's onboarding: three steps, and the third one starts a session.
///
/// **Three, counted by [OnboardingStep] rather than by this widget.** There is
/// no fourth branch to add here, and the step indicator reads its length off the
/// same enum — so a fourth screen would be a change to the vocabulary of the
/// app rather than a widget somebody slipped in.
///
/// **Nothing is asked for.** No account, no sign-in, no permission: REQ-001
/// keeps everything on the device, so there is nothing to ask about, and the
/// one system prompt this app ever raises — the notification permission — is
/// raised by [SessionAnnouncer] after a session is already running and cannot
/// hold one up.
///
/// **Every step is skippable.** One Skip, present on all three and meaning the
/// same thing each time: leave onboarding, keep the settings already in hand.
/// See [OnboardingController.skip], including why skipping takes the coach
/// marks with it.
class OnboardingSteps extends ConsumerWidget {
  const OnboardingSteps({required this.step, super.key});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.read(onboardingProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: Spacing.screenPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              // Centred rather than stretched down the page: the body is a
              // different height on each of the three steps, and a flow whose
              // buttons moved to the bottom edge on the shortest of them would
              // put the same tap in a different place three times.
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepDots(step: step),
                  const SizedBox(height: Spacing.xl),
                  _StepBody(step: step),
                  const SizedBox(height: Spacing.xl),
                  // A Wrap for the reason the timer's controls are one: at a
                  // large text size on a narrow phone the two buttons do not
                  // share a line, and stacking them is better than clipping the
                  // one that matters.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Spacing.md,
                    runSpacing: Spacing.sm,
                    children: [
                      TextButton(
                        key: OnboardingKeys.skip,
                        onPressed: onboarding.skip,
                        child: const Text('Skip'),
                      ),
                      if (step == OnboardingStep.start)
                        FilledButton(
                          key: OnboardingKeys.start,
                          // §9.2's button tap. This is a START like the timer
                          // screen's — it begins a real session — and ticket
                          // 26's list is about what a tap *does* rather than
                          // which screen it is on. Skip and Next get nothing:
                          // one abandons the flow and the other turns a page,
                          // and neither starts or ends anything.
                          onPressed: () {
                            unawaited(
                              ref
                                  .read(microSoundsProvider)
                                  .play(MicroSound.buttonTap),
                            );
                            onboarding.startFirstSession();
                          },
                          child: const Text('Start my first session'),
                        )
                      else
                        FilledButton(
                          key: OnboardingKeys.next,
                          onPressed: onboarding.advance,
                          child: const Text('Next'),
                        ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Which of the three the user is on, as three dots.
///
/// The length comes from [OnboardingStep.values], so the indicator cannot
/// disagree with the flow about how many steps there are — which is the
/// requirement this row is here to make visible.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});

  final OnboardingStep step;

  static const double _size = Spacing.sm;

  @override
  Widget build(BuildContext context) {
    final garden = GardenColors.of(context);

    return Semantics(
      label: 'Step ${step.index + 1} of ${OnboardingStep.values.length}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final each in OnboardingStep.values) ...[
              if (each.index > 0) const SizedBox(width: Spacing.sm),
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: each.index <= step.index
                      ? Theme.of(context).colorScheme.primary
                      : garden.textSecondary.withValues(alpha: 0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What each step has to say, and the one thing it offers.
class _StepBody extends ConsumerWidget {
  const _StepBody({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final garden = GardenColors.of(context);
    final settings = ref.watch(settingsProvider);

    final (title, body) = switch (step) {
      OnboardingStep.welcome => (
          'Focus, and something grows',
          'Every session you see through plants something that stays. This is '
              'what a few weeks of them looks like.',
        ),
      OnboardingStep.sessionLength => (
          'How long is your first session?',
          'A longer session grows a bigger plant. Nothing is fixed — this is '
              'the session length, and it lives in Settings afterwards.',
        ),
      OnboardingStep.start => (
          'That is the whole of it',
          '${settings.sessionLength.inMinutes} minutes of focus, and a seed '
              'goes into the soil the moment you start. There is nothing to '
              'sign up for and nothing else to set.',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: Spacing.sm),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: garden.textSecondary,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        switch (step) {
          // US-002 in the one place it can be honest: the user's own garden is
          // bare soil today, so what a welcome shows is a garden that has been
          // kept.
          OnboardingStep.welcome => const GardenPreview(),
          OnboardingStep.sessionLength => _Lengths(selected: settings.preset),
          // Nothing. The step is the tap, and a third screen that found
          // something to put on itself would be a fourth step wearing the
          // third's clothes.
          OnboardingStep.start => const SizedBox.shrink(),
        },
      ],
    );
  }
}

/// REQ-004's three lengths, in one tap each.
///
/// The same [SessionPreset] the settings screen offers, so the chip a user taps
/// here is the chip that is selected there afterwards — onboarding has no
/// lengths of its own to disagree with the app about.
class _Lengths extends ConsumerWidget {
  const _Lengths({required this.selected});

  final SessionPreset? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      key: OnboardingKeys.lengths,
      alignment: WrapAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final preset in SessionPreset.values)
          ChoiceChip(
            key: OnboardingKeys.preset(preset),
            label: Text(
              '${preset.label} · ${preset.length.inMinutes} min',
              semanticsLabel:
                  '${preset.label}, ${preset.length.inMinutes} minutes',
            ),
            selected: preset == selected,
            // Tapping the selected chip is not a way to have no session
            // length, so a deselecting tap does nothing — the same rule the
            // settings screen's chips follow.
            onSelected: (isSelected) {
              if (isSelected) {
                ref.read(onboardingProvider.notifier).chooseLength(preset.length);
              }
            },
          ),
      ],
    );
  }
}
