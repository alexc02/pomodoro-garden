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

/// Keys for the onboarding controls; the button labels also appear on the
/// timer behind the flow.
abstract final class OnboardingKeys {
  /// Shown on every step.
  static const Key skip = Key('onboarding.skip');

  static const Key next = Key('onboarding.next');

  /// Last step only.
  static const Key start = Key('onboarding.start');

  static const Key lengths = Key('onboarding.lengths');

  static Key preset(SessionPreset preset) =>
      Key('onboarding.preset.${preset.name}');
}

/// The three onboarding steps; the last one starts a session. Step count comes
/// from [OnboardingStep]. Nothing to sign up for or grant here (the
/// notification prompt comes later, from [SessionAnnouncer]). Skip is on every
/// step; see [OnboardingController.skip].
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
              // Centred, so the buttons don't jump around between steps of
              // different heights.
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepDots(step: step),
                  const SizedBox(height: Spacing.xl),
                  _StepBody(step: step),
                  const SizedBox(height: Spacing.xl),
                  // Wrap so the buttons stack on narrow phones at large text.
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
                          // Tap sound, since this starts a real session. Skip
                          // and Next stay silent.
                          onPressed: () {
                            unawaited(
                              ref
                                  .read(microSoundsProvider)
                                  .play(MicroSound.buttonTap),
                            );
                            onboarding.startFirstSession();
                          },
                          child: const Text('Plant my first seed'),
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

/// Step indicator. Length comes from [OnboardingStep.values].
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
          'Every session you finish plants something that stays. This is a few '
              'weeks\' worth.',
        ),
      OnboardingStep.sessionLength => (
          'How long is your first session?',
          'Longer sessions grow bigger plants. You can change this any time in '
              'Settings.',
        ),
      OnboardingStep.start => (
          'That\'s all there is to it',
          '${settings.sessionLength.inMinutes} minutes of focus, and a seed goes '
              'in the moment you start. No account, and nothing else to set up.',
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
          // A sample garden, since the user's own is still bare soil.
          OnboardingStep.welcome => const GardenPreview(),
          OnboardingStep.sessionLength => _Lengths(selected: settings.preset),
          OnboardingStep.start => const SizedBox.shrink(),
        },
      ],
    );
  }
}

/// Same [SessionPreset]s as settings, so the choice carries over.
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
            // Tapping the selected chip doesn't deselect it.
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
