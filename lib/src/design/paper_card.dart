import 'package:flutter/material.dart';

import 'garden_colors.dart';
import 'spacing.dart';

/// Paper card with uneven [Radii.paperMd] corners, a hard shadow for the
/// cut edge and a soft one behind it.
class PaperCard extends StatelessWidget {
  const PaperCard({
    required this.child,
    this.surfaceKey,
    this.color,
    super.key,
  });

  final Widget child;

  /// Key for the surface itself; some tests look the card up by it.
  final Key? surfaceKey;

  /// Defaults to the theme surface.
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
