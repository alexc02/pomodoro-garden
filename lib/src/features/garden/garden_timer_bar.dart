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

/// The timer bar's parts, by name.
abstract final class GardenTimerBarKeys {
  static const Key bar = Key('gardenTimerBar');
  static const Key start = Key('gardenTimerBar.start');
}

/// US-006's single tap, from the screen the app opens on (PRD v2.2 §5.2).
///
/// The garden is where the app opens and the timer is a tab away, so without
/// this a session takes two taps to start. The bar is the PRD's Screen 1 ring
/// cut down to a line along the bottom of the garden:
///
/// - **Nothing counting:** the next session's length and START. Starting moves
///   to the timer, because the seed dropping into the soil is the first thing a
///   session shows and it happens there.
/// - **A session or a break counting:** the time left, and a tap goes to the
///   timer. Pause and cancel stay on the timer screen: the garden is somewhere
///   to look while a session runs, not a second set of controls for it.
///
/// It is gone while decor is being arranged (REQ-040): the arranging bar takes
/// the same edge, and that is the thing the user is doing.
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

    // Tabular, so the line does not shift as the seconds change.
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
      // A card of paper laid on the garden (PRD v2.3).
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
                // Side by side, and the button drops under the line when
                // the two will not fit: on the smallest phone at the
                // largest text sizes, "Plant it" and the session cannot
                // share a row.
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
                        // The session in the display face: it is the
                        // thing this card is about. One line at any text
                        // size; [spoken] is what a screen reader hears.
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
                        // Marigold: the one warm accent in the chrome, kept
                        // for the action a screen is for.
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                        ),
                        onPressed: () {
                          // §9.2's button tap, as the timer's own START has.
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

  /// The time left as a screen reader should say it: minutes, rounded up, and
  /// seconds only in the last minute.
  static String _spokenLeft(Duration remaining) {
    if (remaining.inSeconds < 60) {
      final seconds = remaining.inSeconds;
      return seconds == 1 ? '1 second left' : '$seconds seconds left';
    }
    final minutes = (remaining.inSeconds / 60).ceil();
    return minutes == 1 ? '1 minute left' : '$minutes minutes left';
  }
}
