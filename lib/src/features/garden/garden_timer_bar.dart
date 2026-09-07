import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/paper_card.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../feedback/feedback_providers.dart';
import '../../feedback/micro_sounds.dart';
import '../../garden/decor_providers.dart';
import '../../session/session_providers.dart';
import '../../settings/settings_providers.dart';
import '../../shell/shell_providers.dart';
import '../../shell/tab.dart';
import '../../shell/tab_glyph.dart';
import '../timer/countdown.dart';

abstract final class GardenTimerBarKeys {
  static const Key bar = Key('gardenTimerBar');
  static const Key start = Key('gardenTimerBar.start');
}

/// One-tap start from the garden, which is where the app opens.
///
/// Idle: next session length and PLANT IT, which also switches to the timer
/// tab so the seed drop is seen. Running or on a break: time left, tap to open
/// the timer. Pause and cancel stay on the timer screen.
///
/// Hidden while arranging decor, since the arrange bar uses the same edge.
class GardenTimerBar extends ConsumerWidget {
  const GardenTimerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(decorArrangerProvider) is! NotArranging) {
      return const SizedBox.shrink();
    }

    final snapshot = ref.watch(sessionControllerProvider);
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    void openTimer() =>
        ref.read(selectedTabProvider.notifier).select(AppTab.timer);

    final left = '${formatCountdown(snapshot.remaining)} left';
    final (String line, String spoken, bool startable) = switch (snapshot.phase) {
      SessionPhase.idle || SessionPhase.breakOver => () {
          final minutes = ref.watch(settingsProvider).sessionLength.inMinutes;
          return (
            '$minutes-minute session',
            'Start a $minutes-minute session',
            true,
          );
        }(),
      SessionPhase.running => (
          'Focusing · $left',
          'Focusing, ${_spokenLeft(snapshot.remaining)}. Open the timer.',
          false,
        ),
      SessionPhase.paused => (
          'Paused · $left',
          'Paused, ${_spokenLeft(snapshot.remaining)}. Open the timer.',
          false,
        ),
      SessionPhase.onBreak => (
          '${snapshot.breakKind == BreakKind.long ? 'Long break' : 'On a break'}'
              ' · $left',
          'On a break, ${_spokenLeft(snapshot.remaining)}. Open the timer.',
          false,
        ),
      SessionPhase.completed => (
          'Session complete',
          'Session complete. Open the timer.',
          false,
        ),
    };

    // Tabular so the line doesn't shift each second.
    final tabular = theme.textTheme.titleMedium?.copyWith(
      color: colors.textPrimary,
      fontFeatures: GardenTypography.tabularFigures,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.md,
      ),
      child: PaperCard(
        surfaceKey: GardenTimerBarKeys.bar,
        child: startable
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.md,
                  Spacing.md,
                  Spacing.md,
                ),
                // Button drops below the text when they don't fit (small
                // phone, largest text).
                child: OverflowBar(
                  spacing: Spacing.md,
                  overflowSpacing: Spacing.sm,
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'UP NEXT',
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: GardenTypography.headingWeight,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        // One line at any size; screen readers get [spoken].
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colors.textPrimary,
                            fontSize: 21,
                          ),
                        ),
                      ],
                    ),
                    Semantics(
                      label: spoken,
                      button: true,
                      excludeSemantics: true,
                      child: FilledButton(
                        key: GardenTimerBarKeys.start,
                        // Marigold, like the timer's PLANT IT.
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                        ),
                        onPressed: () {
                          // Same tap sound as the timer's start button.
                          unawaited(ref
                              .read(microSoundsProvider)
                              .play(MicroSound.buttonTap));
                          openTimer();
                          ref
                              .read(sessionControllerProvider.notifier)
                              .start();
                        },
                        child: const Text('Plant it'),
                      ),
                    ),
                  ],
                ),
              )
            : Semantics(
                label: spoken,
                button: true,
                excludeSemantics: true,
                child: InkWell(
                  onTap: openTimer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg,
                      vertical: Spacing.md,
                    ),
                    child: Row(
                      children: [
                        TabGlyph(
                          AppTab.timer,
                          size: 20,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tabular,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Rounded-up minutes, or seconds in the last minute.
  static String _spokenLeft(Duration remaining) {
    if (remaining.inSeconds < 60) {
      final seconds = remaining.inSeconds;
      return seconds == 1 ? '1 second left' : '$seconds seconds left';
    }
    final minutes = (remaining.inSeconds / 60).ceil();
    return minutes == 1 ? '1 minute left' : '$minutes minutes left';
  }
}
