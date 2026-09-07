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

/// The pannable, zoomable garden. One `CustomPaint` over one texture, no widget
/// per plant (see [GardenPainter]). This owns the camera, gestures, texture
/// and entry animation.
class GardenView extends ConsumerStatefulWidget {
  const GardenView({required this.layout, super.key});

  final GardenLayout layout;

  /// Entry fade and scale duration.
  static const Duration entryDuration = Duration(milliseconds: 500);

  /// Starting scale for the entry animation.
  static const double entryScale = 0.95;

  /// Minimum gap between texture bakes. A bake renders every sprite offscreen,
  /// and the season crossfade changes colours over three seconds, so without
  /// this it would rebake every frame. With it the texture steps (about twelve
  /// bakes) while the sky crossfades smoothly over it.
  static const Duration rebakeInterval = Duration(milliseconds: 250);

  @override
  ConsumerState<GardenView> createState() => _GardenViewState();
}

class _GardenViewState extends ConsumerState<GardenView>
    with TickerProviderStateMixin {
  /// Fade-in + scale from 0.95, on launch and on every return to the tab.
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: GardenView.entryDuration,
  );

  /// One sway loop for every plant; [PlantSway] offsets each within it. Passed
  /// to [GardenPainter] as `repaint`, so it repaints without rebuilding.
  /// `TickerMode` stops it when another tab is showing.
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: PlantSway.period,
  );

  /// Reduce-motion, as of the last dependency change. Null until first read.
  bool? _still;

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entry,
    curve: Curves.easeOut,
  );

  late final Animation<double> _grow = Tween<double>(
    begin: GardenView.entryScale,
    end: 1,
  ).animate(_fade);

  /// Null until first layout. Lives here so the view comes back where the user
  /// left it (the shell's `IndexedStack` keeps this state alive).
  GardenProjection? _camera;

  Size _viewport = Size.zero;

  /// Camera and focal point at gesture start. Gestures apply relative to the
  /// start so pinch and drag don't compound.
  GardenProjection? _gestureFrom;
  Offset _gestureAt = Offset.zero;

  GardenAtlas? _atlas;

  /// Real elapsed time, not frame count, for [GardenView.rebakeInterval].
  final Stopwatch _sinceBake = Stopwatch();

  /// A bake deferred by the interval. Makes sure the final texture matches the
  /// colours the theme settles on.
  Timer? _bakeDue;

  /// Last known `TickerMode`. Going from off to on is how we find out the tab
  /// was shown again, which replays the entry animation.
  bool _onScreen = false;

  /// Start of the current visit, null when the tab isn't in front. Used for
  /// `time_spent`.
  ///
  /// Uses [Clock] rather than a [Stopwatch] so tests can control it.
  DateTime? _visitBegan;

  /// Held rather than read when needed, because a visit can end in [dispose]
  /// and `ref` shouldn't be used there.
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
    // Record the visit still open when the app goes away; most visits end this
    // way rather than by switching tabs.
    _endVisit();
    _bakeDue?.cancel();
    _atlas?.dispose();
    _sway.dispose();
    _entry.dispose();
    super.dispose();
  }

  /// Stops the sway (and resets it to upright) under reduce-motion. Stopped,
  /// not just ignored: a repeating controller still asks for a frame every
  /// vsync.
  ///
  /// Called from [didChangeDependencies], since reading the media query is what
  /// subscribes to it.
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

  /// Records `garden_viewed`. Zoom is read at the end, since the camera always
  /// opens fitted and only gets interesting once moved.
  void _endVisit() {
    final began = _visitBegan;
    if (began == null) return;
    _visitBegan = null;

    _analytics.record(GardenViewed(
      timeSpent: _clock.now().difference(began),
      zoomLevel: _camera?.scale ?? 1,
    ));
  }

  /// Rebakes the texture if the recipe changed and the last bake is old enough.
  /// The recipe only depends on theme colours, hence [didChangeDependencies].
  /// The registry is read, not watched; it's set once at the app root.
  void _bakeAtlas() {
    // Same recipe as the export, so a shared picture matches the screen.
    final recipe = gardenAtlasRecipe(
      colours: GardenColors.of(context),
      registry: ref.read(plantSpriteRegistryProvider),
      decorRegistry: ref.read(decorSpriteRegistryProvider),
    );

    final existing = _atlas;
    if (existing != null && existing.signature == recipe) {
      // Caught up on its own; cancel any pending bake.
      _bakeDue?.cancel();
      _bakeDue = null;
      return;
    }

    if (existing != null && _sinceBake.elapsed < GardenView.rebakeInterval) {
      // Too soon. Keep drawing the old texture and bake whatever the theme
      // has reached when the timer fires.
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
    // Dispose after this frame: the frame being built still references the old
    // image, and freeing it before raster crashes.
    SchedulerBinding.instance.addPostFrameCallback((_) => existing.dispose());
  }

  /// Fits the whole garden on first layout, then keeps the user's camera. A
  /// resize re-clamps instead of refitting.
  GardenProjection _cameraFor(Size viewport) {
    // Don't fit to an empty viewport; the fit only happens once.
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

  /// Drag and pinch in one handler (a one-finger drag is scale 1). Zoom about
  /// the start point, pan by distance moved, both from the starting camera.
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

  /// Normally a tap on a plant opens its card and anything else does nothing.
  ///
  /// While arranging: tap empty soil to place decor, tap decor to pick it up.
  /// Plants can't be moved or removed. See [ArrangeBar].
  void _tap(TapUpDetails details) {
    final camera = _camera;
    final atlas = _atlas;
    if (camera == null || atlas == null) return;

    final target = GardenHitTest(
      layout: widget.layout,
      projection: camera,
      // Hit-test against the same texture that was drawn.
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
          // Tapping the held item puts it down.
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

    // Under reduce-motion pass null so the painter doesn't listen at all.
    final sway = _still! ? null : _sway;

    return LayoutBuilder(
      builder: (context, constraints) {
        final camera = _cameraFor(constraints.biggest);

        // Gestures go inside the scale transition so touch points are in
        // garden coordinates, even during the entry animation.
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
