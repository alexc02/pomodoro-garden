import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/garden_colors.dart';
import '../../design/garden_skin.dart';
import '../../garden/garden_transition.dart';
import '../../garden/theme_providers.dart';

/// Puts REQ-019's season and REQ-034's theme around the garden, and turns
/// either of them over three seconds rather than in a frame.
///
/// **What it changes, and what it cannot.** One thing: the [GardenColors] in
/// the theme its child is built under. Everything the garden draws already
/// reads its colours from there — the sky behind it is `GardenColors.of`, the
/// soil, the foliage and the plot edging are baked into the atlas out of the
/// same values — so the whole of the repaint is this one substitution, and no
/// painter, projection or layout knows that either a season or a biome exists.
///
/// That is also why neither can leak. This widget wraps the garden tab and
/// nothing else, so the app's own theme is untouched: the timer's ring, the
/// settings sliders and the tab bar are the same colour in January as in July
/// and the same colour in the greenhouse as in the meadow. And nothing here is
/// readable from the code that decides what a session grows — a plant is chosen
/// by its session's length and its id, and neither of those has a month or a
/// biome in it.
///
/// **One clock, for both kinds of change.** The colours and the weather move
/// together off a single controller, so there is no way for the sky to have
/// finished turning while it is still snowing — and no way for a theme change
/// to race a season change, because to everything below here they are the same
/// kind of event: the skin the garden is arriving at has changed.
class SeasonalGarden extends ConsumerStatefulWidget {
  const SeasonalGarden({required this.builder, super.key});

  /// Builds the garden, under the skin's theme and told how far through a
  /// change of dress it is.
  final Widget Function(BuildContext context, GardenTransition skin) builder;

  /// How long a change of season or theme takes.
  ///
  /// The ticket's "~3 seconds": long enough that a user looking at the garden
  /// at midnight on the first of March sees it happen rather than catching a
  /// cut, and short enough that a reviewer forcing a season does not think the
  /// control is broken.
  ///
  /// Ticket 19 asks that switching themes crossfade rather than cut, and takes
  /// this same three seconds for it — one duration, because they are one
  /// motion. What it must not do is *move* anything: a crossfade is colour
  /// only, so the plants stand exactly where they stood and go on growing at
  /// the rate they were growing at.
  static const Duration crossfade = Duration(seconds: 3);

  @override
  ConsumerState<SeasonalGarden> createState() => _SeasonalGardenState();
}

class _SeasonalGardenState extends ConsumerState<SeasonalGarden>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turning = AnimationController(
    vsync: this,
    duration: SeasonalGarden.crossfade,
    // Settled: the first frame of the app is already in its season and its
    // theme, and a garden that faded in from the wrong one on every launch
    // would be a bug that looked like a feature. This is also the half of
    // "theme choice is restored on launch" that the user can see — a paid-for
    // meadow opens as a meadow, not as a Zen garden turning into one.
    value: 1,
  );

  /// Eased, because a linear colour crossfade arrives with a visible edge — the
  /// last few frames of it are the ones the eye notices.
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _turning,
    curve: Curves.easeInOut,
  );

  late GardenSkin _leaving;
  late GardenSkin _arriving;

  @override
  void initState() {
    super.initState();
    // Read rather than watched: the first skin is where the garden starts, and
    // every one after it arrives through the listener in [build] so that it
    // arrives *as a change* with something to crossfade from.
    _leaving = _arriving = ref.read(gardenSkinProvider);
    _turning.addStatusListener(_arrive);
  }

  /// Forgets the skin that has finished leaving.
  ///
  /// Not housekeeping: a transition that stayed half-described would leave the
  /// garden permanently *between* two skins at a progress of one. The colours
  /// would be right — they are wholly the arriving skin's by then — and
  /// everything that reads the pair rather than the blend would be wrong
  /// forever. The case that shows it is a garden that has arrived at summer:
  /// autumn's leaves are drawn at nothing, but the overlay is still asking for
  /// sixty frames a second to draw them at it.
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

  /// Starts the garden turning towards [skin].
  ///
  /// A change that lands while one is already running takes the skin being
  /// arrived at as its starting point rather than the blend on screen. That
  /// costs a small jump, and it is worth the simplicity: for a season it can
  /// only happen from the debug affordance, since real boundaries are three
  /// months apart, and for a theme it takes a user changing their mind twice
  /// inside three seconds.
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

    // A phone told to keep still is told by everything, weather included. The
    // season and the theme still change; they simply arrive rather than
    // approaching.
    _turning.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SeasonalGarden.crossfade;

    final base = Theme.of(context);
    // The app's own garden colours, which the skins are a variation on: text
    // colours and the golden hour come through untouched.
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
          // A [Builder], so that what the caller builds is below the [Theme]
          // and reads the skin's colours rather than the app's.
          child: Builder(
            builder: (context) => widget.builder(context, skin),
          ),
        );
      },
    );
  }
}
