import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'plant_painter.dart';
import 'plant_palettes.dart';
import 'plant_providers.dart';
import 'plant_sway.dart';

/// The plant a session is growing, animated. Growth decisions all come from
/// the domain via [PlantGrowth]; this only decides how changes move.
///
/// | What moves | When | How |
/// |---|---|---|
/// | A seed falls into the soil | a session starts | 0.8s, ease-in-out, particle burst on landing |
/// | The plant pops up a size | a growth stage is reached | 1.2s underdamped spring, ratio 0.7 |
/// | The plant sways | continuously, once mature | 4s loop, 2°, offset per plant |
/// | The plant blooms | a watched session completes | 2s, spring + ease, spray of petals |
///
/// The bloom only plays when [completed] flips to true on a plant already on
/// screen, never for one that arrives completed (same rule as the chime in
/// `SessionAnnouncer`). Reduced motion skips it entirely.
///
/// Makes no sound itself; [onLanded] lets the screen above play the soil
/// settle at the right moment.
class GrowingPlant extends ConsumerStatefulWidget {
  const GrowingPlant({
    required this.growth,
    required this.size,
    this.completed = false,
    this.onLanded,
    super.key,
  });

  /// What is growing, or null for an empty bed of soil.
  final PlantGrowth? growth;

  final double size;

  /// Whether the session finished and the caller wants it celebrated. The
  /// timer screen only passes true for a completion the user actually saw.
  final bool completed;

  /// Called as the seed touches the soil ([landsAt] through the drop), once per
  /// seed. Never called when soil is cleared.
  final VoidCallback? onLanded;

  static const Duration dropDuration = Duration(milliseconds: 800);

  /// How far through the drop the seed touches the soil. The burst and the
  /// [onLanded] sound both key off this so they line up.
  static const double landsAt = 0.8;

  /// Underdamped (ratio 0.7) so the plant overshoots and settles in about
  /// 1.2s.
  static final SpringDescription growthSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 24, ratio: 0.7);

  /// Scale a stage transition starts from. The spring runs 0 to 1 (with
  /// overshoot), so the plant grows from 0.8 to a bit over full size.
  static const double growthFrom = 0.8;

  /// From completion to the last petal fading.
  static const Duration bloomDuration = Duration(seconds: 2);

  /// Velocity kick for the bloom when the stage didn't change. Restarting at
  /// [growthFrom] would visibly snap the plant smaller first.
  static const double bloomKick = 2.5;

  @override
  ConsumerState<GrowingPlant> createState() => _GrowingPlantState();
}

class _GrowingPlantState extends ConsumerState<GrowingPlant>
    with TickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: GrowingPlant.dropDuration,
  );

  /// Unbounded, or the controller would clamp away the spring's overshoot.
  late final AnimationController _grow =
      AnimationController.unbounded(vsync: this, value: 1);

  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: PlantSway.period,
  );

  /// Sway amplitude, 0 to 1. Plants mature mid-swing because of the phase
  /// offset, so this eases the lean in instead of snapping.
  late final AnimationController _swayIn = AnimationController(
    vsync: this,
    duration: PlantSway.period ~/ 2,
  );

  /// Reset by the next seed, cleared soil, or reduced motion.
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: GrowingPlant.bloomDuration,
  );

  /// Reduced motion, as of the last media query read.
  bool _still = false;

  /// Whether this seed's landing has been reported. A flag rather than a value
  /// comparison because the controller can be jumped, restarted or disposed
  /// mid-fall.
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _drop.addListener(_watchForTheLanding);
    _followGrowth(null, widget.growth);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    // End an in-flight bloom rather than freeze petals mid-air.
    if (_still) _bloom.reset();
  }

  @override
  void didUpdateWidget(GrowingPlant old) {
    super.didUpdateWidget(old);
    _followGrowth(old.growth, widget.growth);
    _followCompletion(old, widget);
  }

  /// Reports the landing once. Driven off frames, so it can't fire while the
  /// app is backgrounded.
  void _watchForTheLanding() {
    if (_landed || _drop.value < GrowingPlant.landsAt) return;

    _landed = true;
    widget.onLanded?.call();
  }

  @override
  void dispose() {
    _drop.removeListener(_watchForTheLanding);
    _drop.dispose();
    _grow.dispose();
    _sway.dispose();
    _swayIn.dispose();
    _bloom.dispose();
    super.dispose();
  }

  void _followGrowth(PlantGrowth? before, PlantGrowth? now) {
    if (now == null) {
      // Mark as landed so clearing the soil isn't reported as a seed
      // arriving.
      _landed = true;
      _drop.value = 0;
      _bloom.reset();
      _stopSwaying();
      return;
    }

    if (before == null || before.sessionId != now.sessionId) {
      // A new plant, not a further-grown one: new seed drops.
      _grow.value = 1;
      _bloom.reset();
      _landed = false;
      _drop.forward(from: 0);
    } else if (before.stage != now.stage) {
      _grow.animateWith(
        SpringSimulation(GrowingPlant.growthSpring, 0, 1, 0),
      );
    }

    // Only mature plants sway. Don't restart a running sway or it jumps back
    // to the start of its loop.
    if (now.stage == GrowthStage.mature) {
      if (!_sway.isAnimating) {
        _sway.repeat();
        _swayIn.forward(from: 0);
      }
    } else if (_sway.isAnimating) {
      _stopSwaying();
    }
  }

  /// Starts the bloom on a watched completion: only the false-to-true edge on
  /// the same session counts.
  void _followCompletion(GrowingPlant before, GrowingPlant now) {
    final grew = before.growth;
    final grows = now.growth;
    if (before.completed || !now.completed) return;
    if (grew == null || grows == null) return;
    if (grew.sessionId != grows.sessionId) return;
    if (_still) return;

    _bloom.forward(from: 0);

    // If the stage changed too, [_followGrowth] is already springing and a
    // second spring would kill its overshoot. Otherwise (e.g. the plant
    // matured early) add a kick on top of whatever the spring is doing.
    if (grew.stage == grows.stage) {
      _grow.animateWith(
        SpringSimulation(
          GrowingPlant.growthSpring,
          _grow.value,
          1,
          _grow.velocity + GrowingPlant.bloomKick,
        ),
      );
    }
  }

  void _stopSwaying() {
    _sway.stop();
    _sway.value = 0;
    _swayIn.stop();
    _swayIn.value = 0;
  }

  /// Pixels the seed still has to fall, eased in and out.
  double get _dropDistance {
    if (!_drop.isAnimating && _drop.value == 0) return 0;
    final fallen = Curves.easeInOut.transform(_drop.value);
    return (1 - fallen) * widget.size * 0.45;
  }

  /// Soil burst over the last fifth of the fall.
  double get _burst {
    if (_drop.value <= GrowingPlant.landsAt) return 0;
    return (_drop.value - GrowingPlant.landsAt) / (1 - GrowingPlant.landsAt);
  }

  /// The sway itself is [PlantSway]'s so it matches the garden; the ease-in is
  /// this screen's.
  double _lean(PlantGrowth growth) {
    if (!_sway.isAnimating) return 0;

    return PlantSway.leanAt(
      _sway.value,
      seed: growth.sessionId,
      amount: Curves.easeInOut.transform(_swayIn.value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final growth = widget.growth;
    final registry = ref.watch(plantSpriteRegistryProvider);

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_drop, _grow, _sway, _swayIn, _bloom]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: PlantPainter(
            sprite: growth == null
                ? null
                : registry.spriteFor(
                    form: growth.species.form,
                    stage: growth.stage,
                  ),
            palette: growth == null
                ? bareSoilPalette(context)
                : plantPaletteFor(context, growth.species),
            scale: growth == null
                ? 1
                : GrowingPlant.growthFrom +
                    (1 - GrowingPlant.growthFrom) * _grow.value,
            lean: growth == null ? 0 : _lean(growth),
            drop: _dropDistance,
            burst: _burst,
            // Stays at 1 when done; the painter draws nothing at either end.
            bloom: _bloom.value,
          ),
        ),
      ),
    );
  }
}
