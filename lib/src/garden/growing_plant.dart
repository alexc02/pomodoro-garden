import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'plant_painter.dart';
import 'plant_palettes.dart';
import 'plant_providers.dart';
import 'plant_sway.dart';

/// The plant a session is growing, animated: §5.3's four plant animations, and
/// nothing else.
///
/// Hand it the [PlantGrowth] off the session snapshot and it does the rest. It
/// holds no opinion about growth — which plant, which stage and which species
/// are all decided in the domain — only about how a change in any of them
/// should move.
///
/// | What moves | When | §5.3 |
/// |---|---|---|
/// | A seed falls into the soil | a session starts | 0.8s, ease-in-out, with a particle burst on landing |
/// | The plant pops up a size | a growth stage is reached | 1.2s underdamped spring, ratio 0.7, slight overshoot |
/// | The plant sways | continuously, once mature | 4s loop, 2°, offset per plant |
/// | The plant blooms | a session completes, watched | 2s, spring + ease, a spray of petals |
///
/// **The bloom is for a completion this widget watched happen.** It plays when
/// [completed] turns true under a plant that was already on screen, and never
/// for one handed over already complete: that plant was *found* completed — the
/// app opened, the tab rebuilt — and the rule `SessionAnnouncer` applies to the
/// chime applies here for the same reason. A cancelled or voided session clears
/// the soil instead, and an empty bed has nothing to bloom.
///
/// It does not end and hand over to anything. The sway starts at the instant
/// the plant matures, which is the same instant or earlier, so by the time the
/// last petal fades the plant is already swaying and simply goes on doing so.
///
/// A phone asking for reduced motion gets no bloom at all — not a still frame
/// of one, which would be petals hanging in the air for no reason. The plant is
/// simply mature, which is what the bloom was celebrating.
///
/// It makes no sound, and [onLanded] is why it does not have to. §5.4's soil
/// settle belongs at the instant the seed touches the soil, and this is the only
/// class that knows when that is — but "knows when" and "decides what it means"
/// are different jobs, and a drawing widget that reached for an audio player
/// would be a drawing widget nothing could render without one. So it reports the
/// landing and the screen above it plays the sound.
class GrowingPlant extends ConsumerStatefulWidget {
  const GrowingPlant({
    required this.growth,
    required this.size,
    this.completed = false,
    this.onLanded,
    super.key,
  });

  /// What is growing, or null when nothing is — an empty bed of soil.
  final PlantGrowth? growth;

  /// The side of the square the plant and its soil are drawn in.
  final double size;

  /// Whether the session growing this plant has completed, and the completion
  /// is one worth celebrating.
  ///
  /// The bloom plays when this turns true under a plant already on screen —
  /// once, at that instant. The caller decides what counts: the timer screen
  /// passes true only for a completion the user was there to see, so a session
  /// that ran out while the app was away does not bloom when it comes back.
  final bool completed;

  /// Called as the seed touches the soil, at [landsAt] of the way through the
  /// drop — the instant the particle burst begins.
  ///
  /// Once per seed, and never for soil being cleared. Optional because most
  /// things that draw a plant have nothing to say about it: the timer screen
  /// passes §5.4's soil settle, and `test/garden/plant_platform_parity_test.dart`
  /// passes nothing and renders in a scope with no audio in it at all.
  final VoidCallback? onLanded;

  /// §5.3: the seed takes this long to reach the soil.
  static const Duration dropDuration = Duration(milliseconds: 800);

  /// How far through the drop the seed actually touches the soil, 0 to 1.
  ///
  /// The last fifth of the fall is the landing: the particle burst is thrown up
  /// over it, and §5.4's soil settle plays as it starts. Named rather than
  /// written twice, because the picture and the sound have to agree about when
  /// the seed arrived — a sound a fifth of a second off the burst it belongs to
  /// is two events instead of one.
  static const double landsAt = 0.8;

  /// §5.3's growth spring: underdamped at a ratio of 0.7, so the plant
  /// overshoots its new size and settles back, and stiff enough to be done in
  /// about the 1.2 seconds the spec asks for.
  static final SpringDescription growthSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 24, ratio: 0.7);

  /// How much smaller the plant starts a stage transition. The spring runs 0 to
  /// 1 and overshoots past it, so the plant grows from 0.8 of its new size to a
  /// little over it and settles.
  static const double growthFrom = 0.8;

  /// §5.3: the bloom — the PRD's "session end celebration" — takes this long, from the instant the
  /// session completes to the last petal fading.
  static const Duration bloomDuration = Duration(seconds: 2);

  /// How hard the bloom kicks the growth spring outwards, for a plant whose
  /// stage did not change as it completed.
  ///
  /// A kick rather than the stage transition's 0-to-1 run, because the plant is
  /// already at its size and the same sprite: starting it at [growthFrom] would
  /// snap it visibly smaller before springing back. Kicked from rest at full
  /// size it swells a few percent and settles, inside the same 1.2 seconds.
  static const double bloomKick = 2.5;

  @override
  ConsumerState<GrowingPlant> createState() => _GrowingPlantState();
}

class _GrowingPlantState extends ConsumerState<GrowingPlant>
    with TickerProviderStateMixin {
  /// The seed on its way down. Runs once per session.
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: GrowingPlant.dropDuration,
  );

  /// The stage transition. Unbounded because a bounded controller would clamp
  /// away the overshoot that is the point of a spring.
  late final AnimationController _grow =
      AnimationController.unbounded(vsync: this, value: 1);

  /// The ambient sway. Repeats for as long as a mature plant is on screen.
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: PlantSway.period,
  );

  /// How much of the sway's amplitude is in play, 0 to 1.
  ///
  /// The sway is offset per plant, so at the instant a plant matures its sine
  /// is already somewhere in the middle of its swing — without this the plant
  /// would snap to a lean rather than drift into one. Eased in over half a
  /// period, which is slow enough not to read as a movement of its own.
  late final AnimationController _swayIn = AnimationController(
    vsync: this,
    duration: PlantSway.period ~/ 2,
  );

  /// The bloom. Runs once per watched completion, and is put
  /// back to zero by the next seed, by cleared soil, or by reduced motion.
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: GrowingPlant.bloomDuration,
  );

  /// Whether the phone has asked for reduced motion, as of the last time the
  /// media query was read.
  bool _still = false;

  /// Whether the seed on its way down has already been reported to have landed.
  ///
  /// The drop is watched rather than awaited, because §5.4 puts the soil settle
  /// at the *landing* and §5.3 puts the landing a fifth of the way from the end
  /// — so the moment is inside the animation, not at either end of it. A flag
  /// rather than a comparison against the last frame's value: the controller can
  /// be jumped, restarted or disposed mid-fall, and "have I said this yet" is
  /// the question actually being asked.
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
    // A bloom already in flight is ended rather than frozen: petals stopped
    // half way out are exactly the broken-looking still frame §4.4 is not
    // asking for.
    if (_still) _bloom.reset();
  }

  @override
  void didUpdateWidget(GrowingPlant old) {
    super.didUpdateWidget(old);
    _followGrowth(old.growth, widget.growth);
    _followCompletion(old, widget);
  }

  /// Reports the landing, once, at the instant the burst begins.
  ///
  /// Driven off the drop's own value, which means it cannot fire while the app
  /// is away: an animation controller advances on frames, and a backgrounded app
  /// is not given any. That is the whole of what keeps §5.4's soil settle in
  /// front of the user, and it is why nothing here checks the lifecycle.
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

  /// Starts whichever animations the change from [before] to [now] calls for.
  void _followGrowth(PlantGrowth? before, PlantGrowth? now) {
    if (now == null) {
      // Jumped rather than animated, so nothing is falling and there is nothing
      // to land. Marked as landed so that clearing the soil is not reported as
      // a seed arriving in it.
      _landed = true;
      _drop.value = 0;
      _bloom.reset();
      _stopSwaying();
      return;
    }

    if (before == null || before.sessionId != now.sessionId) {
      // A different plant, not a further-grown one: the last session's plant is
      // cleared away and a new seed drops.
      _grow.value = 1;
      _bloom.reset();
      _landed = false;
      _drop.forward(from: 0);
    } else if (before.stage != now.stage) {
      _grow.animateWith(
        SpringSimulation(GrowingPlant.growthSpring, 0, 1, 0),
      );
    }

    // REQ-023: only mature plants sway. Restarting a sway that is already
    // running would jerk it back to the start of its loop, so it is left alone.
    if (now.stage == GrowthStage.mature) {
      if (!_sway.isAnimating) {
        _sway.repeat();
        _swayIn.forward(from: 0);
      }
    } else if (_sway.isAnimating) {
      _stopSwaying();
    }
  }

  /// Starts the bloom, if the change from [before] to [now] is a completion
  /// watched as it happened.
  ///
  /// Only an edge counts — not completed, then completed, on the same plant. A
  /// completed session rebuilds this widget for as long as it sits on screen,
  /// and none of those rebuilds is a second completion; a plant that arrives
  /// already complete was found rather than watched; and a plant that changes
  /// session at the same moment is a new seed, not a bloom.
  void _followCompletion(GrowingPlant before, GrowingPlant now) {
    final grew = before.growth;
    final grows = now.growth;
    if (before.completed || !now.completed) return;
    if (grew == null || grows == null) return;
    if (grew.sessionId != grows.sessionId) return;
    if (_still) return;

    _bloom.forward(from: 0);

    // §5.3's "spring" half. A completion that also reaches the last stage is
    // already springing from [_followGrowth], and starting a second spring
    // over the first would throw away its overshoot; one that reached it
    // earlier — REQ-009's half-rate growth can mature a plant ahead of its
    // countdown — is kicked instead. The kick is added to whatever the spring
    // is already doing, so a plant that matured a moment ago and is still
    // settling swells on from where it is rather than reversing.
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

  /// How far the seed still has to fall, in pixels.
  ///
  /// Eased in and out: a seed that started and stopped abruptly would read as a
  /// dropped object rather than a planted one.
  double get _dropDistance {
    if (!_drop.isAnimating && _drop.value == 0) return 0;
    final fallen = Curves.easeInOut.transform(_drop.value);
    return (1 - fallen) * widget.size * 0.45;
  }

  /// The soil thrown up as the seed lands, over the last fifth of the fall.
  double get _burst {
    if (_drop.value <= GrowingPlant.landsAt) return 0;
    return (_drop.value - GrowingPlant.landsAt) / (1 - GrowingPlant.landsAt);
  }

  /// The lean of a swaying plant.
  ///
  /// The motion itself is [PlantSway]'s, because the garden leans the same plant
  /// through a `drawAtlas` rotation rather than through this painter and the two
  /// have to agree. What is this screen's own is the ease-in: one plant arriving
  /// mid-swing is something the eye is looking straight at, where a plant in the
  /// garden is one of two hundred.
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
                : registry.spriteFor(type: growth.type, stage: growth.stage),
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
            // Left at 1 once it is over: the painter draws nothing at either
            // end, and 1 is what says the bloom ran rather than never
            // started.
            bloom: _bloom.value,
          ),
        ),
      ),
    );
  }
}
