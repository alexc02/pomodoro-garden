import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/garden_colors.dart';
import '../../design/garden_skin.dart';
import '../../garden/garden_transition.dart';
import '../../garden/theme_providers.dart';

/// Applies season and theme to the garden subtree and crossfades changes over
/// three seconds.
///
/// It only swaps the [GardenColors] in the child's theme. Everything the garden
/// draws reads from there (sky, and the atlas bakes soil and foliage from the
/// same values), so no painter or layout knows about seasons or biomes. The
/// rest of the app's theme is untouched.
///
/// Colours and weather run off one controller so they can't get out of sync,
/// and a theme change and a season change are the same event here.
class SeasonalGarden extends ConsumerStatefulWidget {
  const SeasonalGarden({required this.builder, super.key});

  /// Builds the garden under the skin's theme, given the transition progress.
  final Widget Function(BuildContext context, GardenTransition skin) builder;

  /// Same duration for season and theme changes. Colour only; nothing moves.
  static const Duration crossfade = Duration(seconds: 3);

  @override
  ConsumerState<SeasonalGarden> createState() => _SeasonalGardenState();
}

class _SeasonalGardenState extends ConsumerState<SeasonalGarden>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turning = AnimationController(
    vsync: this,
    duration: SeasonalGarden.crossfade,
    // Start settled so launch shows the right season and theme instead of
    // fading in from the wrong one.
    value: 1,
  );

  /// Eased; a linear colour fade has a visible edge at the end.
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _turning,
    curve: Curves.easeInOut,
  );

  late GardenSkin _leaving;
  late GardenSkin _arriving;

  @override
  void initState() {
    super.initState();
    // Read, not watched: later skins come through the listener in [build] so
    // there's something to fade from.
    _leaving = _arriving = ref.read(gardenSkinProvider);
    _turning.addStatusListener(_arrive);
  }

  /// Drops the old skin once the fade finishes. Otherwise anything reading the
  /// pair (e.g. the weather overlay drawing autumn leaves at zero) keeps
  /// running forever.
  void _arrive(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_leaving == _arriving) return;

    setState(() => _leaving = _arriving);
  }

  @override
  void dispose() {
    _progress.dispose();
    _turning.dispose();
    super.dispose();
  }

  /// A change mid-transition starts from the target skin, not the on-screen
  /// blend. Small jump, but rare (debug season picker, or quick theme changes).
  void _turnTo(GardenSkin skin) {
    if (skin == _arriving) return;

    setState(() {
      _leaving = _arriving;
      _arriving = skin;
    });
    _turning.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GardenSkin>(gardenSkinProvider, (_, skin) => _turnTo(skin));

    // Reduce motion: changes still happen, just instantly.
    _turning.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SeasonalGarden.crossfade;

    final base = Theme.of(context);
    // Base colours the skins vary; text colours etc. pass through.
    final undressed = GardenColors.of(context);

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final skin = GardenTransition(
          from: _leaving,
          to: _arriving,
          progress: _progress.value,
        );

        return Theme(
          data: base.copyWith(
            extensions: [skin.applyTo(undressed)],
          ),
          // Builder so the child reads the skin's colours, not the app's.
          child: Builder(
            builder: (context) => widget.builder(context, skin),
          ),
        );
      },
    );
  }
}
