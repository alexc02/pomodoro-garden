import 'package:flutter/material.dart';

import 'garden_colors.dart';
import 'spacing.dart';

/// A card of paper laid on the page (PRD v2.3, Paper Theatre).
///
/// The hard shadow is its cut edge standing off the page, the soft one is the
/// light behind it. The corners are [Radii.paperMd]'s uneven ones, as if cut
/// by hand. The garden's "Up next" card and the journal's pages are both this
/// card, so the two read as cut from the same sheet.
class PaperCard extends StatelessWidget {
  const PaperCard({
    required this.child,
    this.surfaceKey,
    this.color,
    super.key,
  });

  final Widget child;

  /// A key for the card's surface itself, for the callers whose tests find
  /// the card by it.
  final Key? surfaceKey;

  /// The paper's colour. Defaults to the theme's surface.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.paperMd,
        boxShadow: [
          BoxShadow(
            color: colors.soil.withValues(alpha: 0.45),
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.18),
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Material(
        key: surfaceKey,
        color: color ?? Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.paperMd),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
