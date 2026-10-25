import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../journal/journal_providers.dart';

/// The top of the garden: today's date, a line about the garden in the display
/// face, and the two things a user does *to* the garden (PRD v2.3).
///
/// In place of a centred "Garden" app bar. The tab bar already names the tab;
/// the space is better spent saying something about this garden in particular.
class GardenHeader extends ConsumerWidget {
  const GardenHeader({required this.plants, required this.actions, super.key});

  /// How many plants are standing in the garden.
  final int plants;

  /// REQ-035's export and REQ-040's arranging, top right.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);
    final today = ref.watch(todayProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.sm,
        Spacing.sm,
        Spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLine(today),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: GardenTypography.headingWeight,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Semantics(
                    header: true,
                    // Two lines at most: at the largest text sizes on the
                    // smallest phone the header would otherwise reach down
                    // into the garden. A screen reader still hears it whole.
                    child: Text(
                      headline(plants),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.displayLarge
                          ?.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  /// "Tuesday, 11 August".
  ///
  /// Spelled out here rather than through `MaterialLocalizations`, whose full
  /// date carries the year — the garden is about today, not about the record.
  static String dateLine(CalendarDay day) =>
      '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';

  /// What the garden amounts to, in a few words: "A garden of thirty-one."
  ///
  /// The count and nothing else — no streaks, no praise. The number is the
  /// garden's, and it only ever goes up.
  static String headline(int plants) => switch (plants) {
        0 => 'Bare soil, for now.',
        _ => 'A garden of ${inWords(plants)}.',
      };

  /// A count in words up to ninety-nine, and in figures above it: by then
  /// "a garden of a hundred and forty-two" is a mouthful, and the figure is
  /// what the user is proud of.
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
