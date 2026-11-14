import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/headline.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../journal/journal_providers.dart';

/// Date, a headline about the garden, and the garden actions. Used instead of
/// an app bar.
class GardenHeader extends ConsumerWidget {
  const GardenHeader({required this.plants, required this.actions, super.key});

  final int plants;

  /// Export and arrange, top right.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);
    final today = ref.watch(todayProvider);

    // At night the light text can end up over the moon, or over the plants
    // when large text makes the header tall. The shadow keeps it readable
    // and doesn't show against the dark sky.
    final shadows = colors.textPrimary.computeLuminance() > 0.5
        ? const [Shadow(color: Color(0xB3000000), blurRadius: 10)]
        : null;

    final date = Text(
      dateLine(today),
      // Scales with the headline under it.
      textScaler: Headline.scalerOf(context),
      style: theme.textTheme.bodySmall?.copyWith(
        color: colors.textPrimary,
        fontWeight: GardenTypography.headingWeight,
        shadows: shadows,
      ),
    );
    final title = Semantics(
      header: true,
      child: Headline(
        headline(plants),
        style: theme.textTheme.displayLarge
            ?.copyWith(color: colors.textPrimary, shadows: shadows),
      ),
    );

    // At large text the headline gets the full width. Next to the buttons it
    // wraps to twice as many lines and runs down over the plants.
    final large = systemTextScale(context) > largeTextFrom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.sm,
        Spacing.sm,
        Spacing.sm,
      ),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: Spacing.sm),
                        child: date,
                      ),
                    ),
                    ...actions,
                  ],
                ),
                title,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Spacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        date,
                        const SizedBox(height: Spacing.xs),
                        title,
                      ],
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
    );
  }

  /// System text size past which the headline goes under the buttons rather
  /// than beside them.
  static const double largeTextFrom = 1.3;

  /// "Tuesday, 11 August". Hand-built because `MaterialLocalizations`'s full
  /// date includes the year.
  static String dateLine(CalendarDay day) =>
      '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';

  /// "A garden of thirty-one." Just the count.
  static String headline(int plants) => switch (plants) {
        0 => 'Bare soil, for now.',
        _ => 'A garden of ${inWords(plants)}.',
      };

  /// Words up to 99, figures from 100.
  static String inWords(int n) {
    if (n >= 100) return '$n';
    if (n < 20) return _ones[n];
    final tens = _tens[n ~/ 10];
    final ones = n % 10;
    return ones == 0 ? tens : '$tens-${_ones[ones]}';
  }

  static const List<String> _ones = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
    'sixteen', 'seventeen', 'eighteen', 'nineteen',
  ];

  static const List<String> _tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
    'eighty', 'ninety',
  ];

  static const List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];
}
