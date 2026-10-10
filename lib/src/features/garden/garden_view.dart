import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../analytics/analytics_providers.dart';
import '../../design/garden_colors.dart';
import '../../garden/decor_providers.dart';
import '../../garden/garden_hit_test.dart';
import '../../garden/garden_painter.dart';
import '../../garden/garden_projection.dart';
import '../../garden/garden_atlas.dart';
import '../../garden/garden_atlas_recipe.dart';
import '../../garden/plant_providers.dart';
import '../../garden/plant_sway.dart';
import '../../time/clock_provider.dart';
import 'decor_picker.dart';
import 'plant_card.dart';

/// The garden itself: two hundred plots of ground the user can drag around and
/// pinch into.
///
/// One `CustomPaint` over one texture, and no widget per plant — see
/// [GardenPainter]. What this class owns is everything the painter is not
/// allowed to: the camera, the gestures that move it, the texture, and §5.3's
/// entry animation.
class GardenView extends ConsumerStatefulWidget {
  const GardenView({required this.layout, super.key});

  /// The garden to draw.
  final GardenLayout layout;

  /// §5.3: the garden fades and scales in over this long.
  static const Duration entryDuration = Duration(milliseconds: 500);

  /// §5.3: and it starts this much smaller than it ends.
  static const double entryScale = 0.95;

  /// The shortest gap between two bakes of the texture.
  ///
  /// A bake is an offscreen render of every sprite in the registry — some
  /// milliseconds, which is nothing once and ruinous sixty times a second.
  /// Ticket 14 turns the garden's colours over three seconds, so without a
  /// floor here a change of season would rebake the atlas on every frame of the
  /// crossfade and drop most of them.
  ///
  /// With it, the texture steps through the change while the sky crossfades
  /// smoothly over it — twelve or so bakes rather than a hundred and eighty,
  /// and the last one lands on whatever the theme settled at. Soil and foliage
  /// moving in quarter-second steps is not something the eye picks out of a
  /// three-second wash; a dropped frame is.
  static const Duration rebakeInterval = Duration(milliseconds: 250);

  @override
  ConsumerState<GardenView> createState() => _GardenViewState();
}

class _GardenViewState extends ConsumerState<GardenView>
    with TickerProviderStateMixin {
  /// §5.3's "gentle fade-in + scale from 0.95", on app launch and on every
  /// return to the tab.
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: GardenView.entryDuration,
  );

  /// REQ-023's sway, as one loop the whole garden leans off.
  ///
  /// One controller for two hundred plants: [PlantSway] offsets each of them
  /// within the loop from the session that grew it, so the garden moves like a
  /// garden without two hundred tickers asking for a frame each. It is handed
  /// straight to [GardenPainter] as its `repaint`, so a frame of the sway is a
  /// repaint and nothing else — this state is never rebuilt by it.
  ///
  /// It repeats for as long as the garden is the tab on screen. `TickerMode`
  /// stops it behind another tab, which is the same mechanism that already stops
  /// the entry animation and ticket 14's weather, and it is what keeps a garden
  /// nobody is looking at off the vsync.
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: PlantSway.period,
  );

  /// Whether the phone has asked for no animation, as of the last time the
  /// dependencies changed. Null until it has been read once.
  bool? _still;

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entry,
    curve: Curves.easeOut,
  );

  late final Animation<double> _grow = Tween<double>(
    begin: GardenView.entryScale,
    end: 1,
  ).animate(_fade);

  /// Where the garden is being looked at from.
  ///
  /// Null until the first layout, because fitting the garden to the screen
  /// needs to know how big the screen is. Kept in this state and nowhere else,
  /// which is what makes the view come back where the user left it: the shell
  /// is an `IndexedStack`, so this state outlives a trip to the timer tab.
  GardenProjection? _camera;

  /// The window the camera is being clamped against.
  Size _viewport = Size.zero;

  /// The camera when the current drag began, and the point it began at. A
  /// gesture is applied to where it *started* rather than accumulated frame by
  /// frame, so a pinch and a drag in the same gesture do not compound.
  GardenProjection? _gestureFrom;
  Offset _gestureAt = Offset.zero;

  GardenAtlas? _atlas;

  /// How long since the last bake, so that [GardenView.rebakeInterval] can be
  /// enforced against real elapsed time rather than against a count of frames.
  final Stopwatch _sinceBake = Stopwatch();

  /// A bake that was asked for too soon after the last one and is waiting its
  /// turn. What guarantees the texture ends up matching the colours the theme
  /// finally settles on, rather than the ones it happened to be passing through
  /// when the interval last elapsed.
  Timer? _bakeDue;

  /// Whether this tab was the one on screen last time the dependencies changed.
  ///
  /// `TickerMode` is how the shell tells a hidden tab to stop animating, so it
  /// is also how a hidden tab finds out it has been shown again — which is the
  /// "returns" half of §5.3's "app launches / returns" trigger, without the
  /// shell having to know that the garden wants telling.
  bool _onScreen = false;

  /// When the visit on screen began, or null when the garden is not the tab in
  /// front of the user. The gap to now is §7.1's `time_spent`.
  ///
  /// A visit is measured here rather than by watching the shell's selected tab,
  /// because the other half of the event is the camera — and the camera is this
  /// state and nobody else's.
  ///
  /// Two instants from [Clock] rather than a [Stopwatch], which is what this
  /// wanted to be: every other duration this app records is measured by the
  /// clock a test can move, and a `time_spent` measured by a stopwatch is a
  /// parameter no test can ever pin to a number. What that costs is a visit
  /// spanning a device clock correction, which comes out wrong — a rarer thing
  /// than a parameter nothing verifies, and one row of a debugging aid either
  /// way.
  DateTime? _visitBegan;

  /// The port a finished visit is recorded through and the clock it is measured
  /// by, both held rather than read at the moment of use: a visit can end with
  /// this state being disposed, and `ref` is not something to reach for on the
  /// way out.
  Analytics _analytics = const NoAnalytics();
  Clock _clock = const SystemClock();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bakeAtlas();
    _followReduceMotion();
    _analytics = ref.read(analyticsProvider);
    _clock = ref.read(clockProvider);

    final onScreen = TickerMode.valuesOf(context).enabled;
    if (onScreen && !_onScreen) {
      _entry.forward(from: 0);
      _visitBegan = _clock.now();
    } else if (!onScreen && _onScreen) {
      _endVisit();
    }
    _onScreen = onScreen;
  }

  @override
  void dispose() {
    // The visit the user is still on when the app goes away. Recorded here
    // because the alternative is losing every garden visit that was never left
    // by switching tabs, which on a phone is most of them.
    _endVisit();
    _bakeDue?.cancel();
    _atlas?.dispose();
    _sway.dispose();
    _entry.dispose();
    super.dispose();
  }

  /// Starts or stops REQ-023's sway according to whether the phone has asked to
  /// be kept still.
  ///
  /// **The controller is stopped rather than merely ignored.** A repeating
  /// controller nobody reads still asks for a frame every vsync for as long as
  /// the garden is on screen, which on a phone with reduce-motion on is a
  /// continuous animation running to produce a still picture — the worst of both
  /// halves of PRD §4.4. Stopping it and setting it back to zero is also what
  /// leaves every plant upright rather than frozen at whatever angle it had
  /// reached, which is the picture the setting is actually asking for.
  ///
  /// Here rather than in `build` because reading the media query is what creates
  /// the dependency on it, so a user turning the setting on arrives as exactly
  /// this callback.
  void _followReduceMotion() {
    final still = MediaQuery.disableAnimationsOf(context);
    if (still == _still) return;
    _still = still;

    if (still) {
      _sway
        ..stop()
        ..value = 0;
    } else {
      _sway.repeat();
    }
  }

  /// Records the visit that has just ended — §7.1's `garden_viewed`.
  ///
  /// The zoom is read at the end rather than the beginning, because what the
  /// event is for is how far *into* their garden a user goes: the camera opens
  /// fitted to the screen every launch and is only interesting once somebody has
  /// moved it.
  void _endVisit() {
    final began = _visitBegan;
    if (began == null) return;
    _visitBegan = null;

    _analytics.record(GardenViewed(
      timeSpent: _clock.now().difference(began),
      zoomLevel: _camera?.scale ?? 1,
    ));
  }

  /// Bakes the texture, if the one already baked is no longer the right one and
  /// the last bake is far enough behind.
  ///
  /// Here rather than in `build` because the only things that change the recipe
  /// are the theme's colours, and a change to those is exactly what
  /// [didChangeDependencies] means. The registry is read rather than watched
  /// for the same reason: ticket 23 swaps it at the root of the app, once,
  /// before any of this is built.
  ///
  /// The first bake is never held back — there is no garden to draw without one
  /// — and neither is one that follows a settled theme, because
  /// [GardenView.rebakeInterval] will long since have elapsed. What the floor
  /// costs is only the frames of a change of season, which is exactly what it
  /// is for.
  void _bakeAtlas() {
    // The same call REQ-035's export bakes through, so that a picture the user
    // shares is the garden they were looking at rather than a second rendering
    // of it that happens to agree today.
    final recipe = gardenAtlasRecipe(
      colours: GardenColors.of(context),
      registry: ref.read(plantSpriteRegistryProvider),
      decorRegistry: ref.read(decorSpriteRegistryProvider),
    );

    final existing = _atlas;
    if (existing != null && existing.signature == recipe) {
      // Arrived at by itself: whatever was waiting for the interval to pass has
      // nothing left to bake.
      _bakeDue?.cancel();
      _bakeDue = null;
      return;
    }

    if (existing != null && _sinceBake.elapsed < GardenView.rebakeInterval) {
      // Too soon. The frames until then are drawn with the texture already in
      // hand, and this comes back to bake whatever the theme has reached by
      // the time it does — which, if the change of season has finished in the
      // meantime, is the season it finished at.
      _bakeDue ??= Timer(
        GardenView.rebakeInterval - _sinceBake.elapsed,
        () {
          _bakeDue = null;
          if (mounted) setState(_bakeAtlas);
        },
      );
      return;
    }

    _atlas = GardenAtlas.bake(recipe);
    _sinceBake
      ..reset()
      ..start();

    if (existing == null) return;
    // Not disposed on the spot: the frame that is being built still refers to
    // the old texture, and an image released underneath a layer that is about
    // to raster it is a crash rather than a stale pixel.
    SchedulerBinding.instance.addPostFrameCallback((_) => existing.dispose());
  }

  /// The camera to draw this frame with.
  ///
  /// The garden opens showing all of itself and stays where the user puts it
  /// after that. A resize — a rotation, or a phone unfolding — re-clamps rather
  /// than refits, because a user who had zoomed into one corner did not ask to
  /// be taken back out to the whole garden.
  GardenProjection _cameraFor(Size viewport) {
    // A window with no room in it cannot be fitted to, and a camera fitted to
    // one would be kept: the fit happens once, so getting it from a degenerate
    // first layout would leave the garden badly placed for good.
    if (viewport.isEmpty) return _camera ?? const GardenProjection();

    _viewport = viewport;
    final camera =
        _camera ?? GardenProjection.fitting(viewport, widget.layout.plots);
    return _camera = camera.boundedTo(viewport, widget.layout.plots);
  }

  void _startGesture(ScaleStartDetails details) {
    _gestureFrom = _camera;
    _gestureAt = details.localFocalPoint;
  }

  /// Drags and pinches, as one gesture.
  ///
  /// `onScale` covers both: a one-finger drag arrives with a scale of 1, so
  /// there is no separate pan handler to disagree with this one about where the
  /// garden is. The zoom is applied about the point the fingers started from
  /// and the pan about how far they have moved since, both measured from the
  /// camera the gesture began with.
  void _updateGesture(ScaleUpdateDetails details) {
    final from = _gestureFrom;
    if (from == null) return;

    final moved = from
        .zoomedTo(from.scale * details.scale, around: _gestureAt)
        .pannedBy(details.localFocalPoint - _gestureAt);

    setState(() {
      _camera = moved.boundedTo(_viewport, widget.layout.plots);
    });
  }

  /// What a tap on the garden does, which depends on what the user is doing.
  ///
  /// **REQ-020 ordinarily, and REQ-040 while arranging.** A tap means one thing
  /// at a time and the screen says which — see [ArrangeBar] — because a garden
  /// where a tap might open a card *or* pick up a bench is a garden the user
  /// has to be careful in, and being somewhere to look at is the whole of what
  /// this screen is for.
  ///
  /// Looking at it: a tap on a plant opens its card, and a tap on bare soil, on
  /// an object, on a plot the garden has not unlocked or on the sky does
  /// nothing at all — deliberately nothing, rather than a card that says the
  /// plot is empty.
  ///
  /// Arranging: a tap on an empty plot puts something in it, a tap on an object
  /// picks it up, and a tap on a plant still does nothing. A plant is not
  /// furniture; nothing in this mode can move one or take one out.
  void _tap(TapUpDetails details) {
    final camera = _camera;
    final atlas = _atlas;
    if (camera == null || atlas == null) return;

    final target = GardenHitTest(
      layout: widget.layout,
      projection: camera,
      // The texture the garden was drawn from, so that what the tap finds is
      // decided from the same pictures the user is looking at.
      atlas: atlas,
    ).at(details.localPosition);

    final arranging = ref.read(decorArrangerProvider);
    final arranger = ref.read(decorArrangerProvider.notifier);

    switch (arranging) {
      case NotArranging():
        if (target is PlantTarget) showPlantCard(context, target.plant);
      case Choosing():
        switch (target) {
          case SoilTarget(:final plot):
            unawaited(showDecorPicker(context, ref, plot));
          case DecorTarget(:final decor):
            arranger.pickUp(decor);
          case PlantTarget():
          case null:
            break;
        }
      case Holding(:final decor):
        switch (target) {
          case SoilTarget(:final plot):
            unawaited(arranger.move(decor, plot));
          // Tapping what is in hand puts it back down, which is the way out of
          // holding something that does not require finding the bar.
          case DecorTarget(decor: final tapped) when tapped.id == decor.id:
            arranger.putDown();
          case DecorTarget(:final decor):
            arranger.pickUp(decor);
          case PlantTarget():
          case null:
            break;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _atlas!;

    // A phone told to keep still is told by the garden too. Null rather than the
    // stopped controller, so that the painter is not subscribed to a listenable
    // it has no reason to hear from — see [_followReduceMotion] for the other
    // half of it.
    final sway = _still! ? null : _sway;

    return LayoutBuilder(
      builder: (context, constraints) {
        final camera = _cameraFor(constraints.biggest);

        // The gestures sit *inside* §5.3's entry rather than around it, so that
        // a point the user touched is a point in the garden's own coordinates —
        // the ones the painter and the camera both work in. Outside the scale,
        // every tap during the half-second the garden is arriving would be
        // read a few pixels away from where it landed.
        return FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _grow,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _tap,
              onScaleStart: _startGesture,
              onScaleUpdate: _updateGesture,
              onScaleEnd: (_) => _gestureFrom = null,
              child: CustomPaint(
                size: constraints.biggest,
                isComplex: true,
                painter: GardenPainter(
                  layout: widget.layout,
                  projection: camera,
                  atlas: atlas,
                  sway: sway,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
