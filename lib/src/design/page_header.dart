import 'package:flutter/material.dart';

import '../shell/torn_edge.dart';
import 'garden_colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// The top of a page that scrolls under a band of sky — the journal's and
/// the settings' (PRD v2.3, Paper Theatre): a small line, and a line in the
/// display face.
///
/// In place of an app bar. The tab bar already names the tab, so the space is
/// spent the way the garden spends its own: saying something in the display
/// face, at the size the garden says it.
class PageHeader extends StatelessWidget {
  const PageHeader({required this.headline, this.eyebrow, super.key});

  /// The line in the display face.
  final String headline;

  /// The small line over it, if there is one.
  final String? eyebrow;

  /// How a page under a [PageHeader] is inset: the screen's sides, and clear
  /// of the torn edge the tab bar reaches up with at the bottom.
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
            child: Text(
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
