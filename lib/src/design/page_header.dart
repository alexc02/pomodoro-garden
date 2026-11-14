import 'package:flutter/material.dart';

import '../shell/torn_edge.dart';
import 'garden_colors.dart';
import 'headline.dart';
import 'spacing.dart';
import 'typography.dart';

/// Page header for screens that scroll under the sky band (journal,
/// settings): an optional small line above a display-face title. Used instead
/// of an app bar since the tab bar already names the page.
class PageHeader extends StatelessWidget {
  const PageHeader({required this.headline, this.eyebrow, super.key});

  final String headline;

  /// Optional line above [title].
  final String? eyebrow;

  /// Padding for content under a [PageHeader]: screen sides, plus room for
  /// the tab bar's torn edge at the bottom.
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    Spacing.md,
    0,
    Spacing.md,
    Spacing.xxl + TornEdge.height,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sm,
        Spacing.md,
        Spacing.sm,
        Spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow case final eyebrow?) ...[
            Text(
              eyebrow,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: GardenTypography.headingWeight,
              ),
            ),
            const SizedBox(height: Spacing.xs),
          ],
          Semantics(
            header: true,
            child: Headline(
              headline,
              style: theme.textTheme.displayLarge
                  ?.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
