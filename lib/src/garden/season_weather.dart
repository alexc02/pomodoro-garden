import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design/season_palette.dart';
import 'garden_transition.dart';

/// REQ-019's weather: blossom in spring, leaves in autumn, snow in winter, and
/// an empty sky in summer.
///
/// **Ambient, and nothing else.** It is wrapped in an [IgnorePointer], so every
/// tap goes straight through it to the garden underneath — a plant behind a
/// falling leaf is exactly as easy to open as one in clear air. It carries no
/// semantics, so a screen reader walks past it. And it never covers enough of
/// the screen to hide anything: see [maximum] and `Weather.opacity`.
///
/// **Bounded by construction.** The count is derived from the size of the
/// window and then capped, so the cost of the overlay is a fixed number of
/// canvas primitives however big the screen and whatever is behind it. That is
/// the ticket's "particle counts must not put the 200-plant garden below target
/// frame rate", made a property of the code rather than a hope.
///
/// **It stops when nobody is looking.** The motion runs off a [Ticker], which
/// `TickerMode` mutes for a tab that is not on screen — so the garden's weather
/// costs nothing at all while the user is on the timer. It is not started at
/// all in a season with nothing falling in it, because a ticker with nothing to
/// draw would still ask for a frame sixty times a second.
class SeasonWeather extends StatefulWidget {
  const SeasonWeather({required this.transition, super.key});

  /// How far through a change of dress the garden is. Both skins' weather is in
  /// the air during one, the leaving skin's fading out as the arriving one
  /// fades in.
  ///
  /// A change of *theme* moves this as well as a change of season, which is
  /// what puts the greenhouse's thinner snow in the air while the meadow's is
  /// still falling out.
  final GardenTransition transition;

  /// The most that will ever be in the air at once, per season.
  ///
  /// A ceiling rather than a target: the density in [Weather] decides the count on
  /// an ordinary phone, and this is what stops a desktop-sized window turning
  /// that density into hundreds. A crossfade briefly has two seasons' worth up,
  /// which is the one moment the total can exceed this — for three seconds, and
  /// with the second layer near-transparent for most of them.
  static const int maximum = 48;

  /// How much sky one of these needs before it draws a single flake.
  ///
  /// `Weather.density` is quoted per this much area.
  static const double densityArea = 100000;

  /// How many of [weather] belong in a window of [size].
  ///
  /// Public because it is the claim worth testing: the count is a function of
  /// the window and a constant, and it has a ceiling.
  static int countIn(Size size, Weather weather) => math.min(
        maximum,
        (weather.density * size.width * size.height / densityArea).round(),
      );

  @override
  State<SeasonWeather> createState() => _SeasonWeatherState();
}

class _SeasonWeatherState extends State<SeasonWeather>
    with SingleTickerProviderStateMixin {
  /// How long the weather has been falling, in seconds.
  ///
  /// A [ValueNotifier] handed to the painter as its `repaint` rather than state
  /// the widget rebuilds on: sixty rebuilds a second of a subtree that only
  /// ever repaints is sixty rebuilds a second nobody needed.
  final ValueNotifier<double> _falling = ValueNotifier<double>(0);

  late final Ticker _ticker = createTicker(
    (elapsed) => _falling.value = elapsed.inMicroseconds / 1000000,
  );

  @override
  void initState() {
    super.initState();
    _runIfAnythingFalls();
  }

  @override
  void didUpdateWidget(SeasonWeather old) {
    super.didUpdateWidget(old);
    _runIfAnythingFalls();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _falling.dispose();
    super.dispose();
  }

  /// Which of the two skins in play have anything in the air.
  ///
  /// Both, during most of a crossfade; one, once it has settled; and neither,
  /// in a summer that has finished arriving.
  ({Weather? leaving, Weather? arriving}) get _weather => (
        leaving: widget.transition.from.palette.weather,
        arriving: widget.transition.to.palette.weather,
      );

  void _runIfAnythingFalls() {
    final weather = _weather;
    final anything = weather.leaving != null || weather.arriving != null;

    if (anything && !_ticker.isActive) {
      _ticker.start();
    } else if (!anything && _ticker.isActive) {
      _ticker.stop();
      _falling.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    if (weather.leaving == null && weather.arriving == null) {
      return const SizedBox.shrink();
    }

    final progress = widget.transition.progress;

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: WeatherPainter(
            falling: _falling,
            // The leaving season's weather thins out as the arriving season's
            // thickens, which is what makes a change of season a crossfade in
            // the air as well as in the colours. Neither layer is ever drawn at
            // an alpha the season itself would not use.
            layers: [
              if (weather.leaving != null)
                (weather: weather.leaving!, alpha: 1 - progress),
              if (weather.arriving != null)
                (weather: weather.arriving!, alpha: progress),
            ],
          ),
        ),
      ),
    );
  }
}

/// One layer of weather: what falls, and how visible it is right now.
typedef WeatherLayer = ({Weather weather, double alpha});

/// Draws the weather.
///
/// Every particle's position is a pure function of the time and its index —
/// there is no per-particle state to advance and nothing is allocated per frame
/// — so the whole overlay is a fixed number of canvas primitives and the
/// arithmetic to place them.
///
/// Public, and for the same reason `GardenPainter.batchFor` is: the ticket's
/// budget is a claim about what this costs per frame, and a budget measured
/// only through the widget tree is a budget measured with everything else's
/// noise in it. `test/garden/season_weather_test.dart` times it directly,
/// including the two-layer crossfade that is the worst case.
class WeatherPainter extends CustomPainter {
  WeatherPainter({required this.falling, required this.layers})
      : super(repaint: falling);

  /// Seconds since the weather started.
  final ValueListenable<double> falling;

  final List<WeatherLayer> layers;

  /// The variation between one particle and the next: where it sits across the
  /// window, how far down its fall it starts, how fast it goes, how wide it
  /// wanders and how big it is.
  ///
  /// Drawn once from a seeded generator and shared by every layer, so that a
  /// garden's snow falls the same way on every launch and on both platforms —
  /// the same reasoning as a species being chosen by a hash rather than rolled
  /// for. Enough of them for [SeasonWeather.maximum]; a layer with fewer
  /// takes the ones at the front.
  static final List<_Mote> _motes = _sow();

  static List<_Mote> _sow() {
    // A fixed seed, because a screenful of weather is a picture and a picture
    // should not change under a test that screenshots it.
    final random = math.Random(19);

    return List<_Mote>.generate(
      SeasonWeather.maximum,
      (_) => (
        across: random.nextDouble(),
        phase: random.nextDouble(),
        speed: 0.75 + random.nextDouble() * 0.5,
        drift: 0.6 + random.nextDouble() * 0.8,
        // Whole turns per fall, either way round, so a leaf that spins is
        // pointing the same way each time it reappears at the top.
        spin: (random.nextInt(3) - 1).toDouble(),
        scale: 0.7 + random.nextDouble() * 0.5,
      ),
      growable: false,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    for (final layer in layers) {
      if (layer.alpha <= 0) continue;
      _paintLayer(canvas, size, layer);
    }
  }

  void _paintLayer(Canvas canvas, Size size, WeatherLayer layer) {
    final weather = layer.weather;
    final count = SeasonWeather.countIn(size, weather);
    final crossing = weather.crossing.inMilliseconds / 1000;
    final paint = Paint()
      ..color = weather.colour.withValues(alpha: weather.opacity * layer.alpha)
      ..isAntiAlias = true;

    // Particles enter from above the window and leave below it, so nothing pops
    // into existence at the top edge or vanishes at the bottom one.
    final margin = weather.size * 2;
    final travel = size.height + margin * 2;

    for (var index = 0; index < count; index++) {
      final mote = _motes[index];
      final progress =
          (falling.value / crossing * mote.speed + mote.phase) % 1.0;

      final y = progress * travel - margin;
      final x = mote.across * size.width +
          math.sin(progress * 2 * math.pi * 2 + mote.phase * 2 * math.pi) *
              weather.sway *
              mote.drift;

      _paintOne(
        canvas,
        paint,
        shape: weather.shape,
        at: Offset(x, y),
        radius: weather.size * mote.scale / 2,
        turn: progress * mote.spin,
      );
    }
  }

  /// One petal, leaf or flake.
  ///
  /// A flake is a circle and needs no transform; the other two are ovals that
  /// turn as they fall, which is what stops a leaf looking like a falling
  /// pebble.
  /// One mote, cut from paper (PRD v2.2 §9.1): a petal, a leaf or a paper
  /// snowflake, with a small shadow under it as if lifted off the sky.
  ///
  /// The shapes are unit paths built once and scaled here, so a cut-out costs
  /// two path draws where a disc cost one.
  static void _paintOne(
    Canvas canvas,
    Paint paint, {
    required WeatherShape shape,
    required Offset at,
    required double radius,
    required double turn,
  }) {
    final cut = switch (shape) {
      WeatherShape.petal => _petal,
      WeatherShape.leaf => _leaf,
      WeatherShape.flake => _flake,
    };

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(turn * 2 * math.pi);
    canvas.scale(radius);
    // The shadow first, down and to the right whichever way the mote is
    // turned: the light does not spin with the leaf.
    canvas.save();
    canvas.rotate(-turn * 2 * math.pi);
    canvas.translate(0.18, 0.28);
    canvas.rotate(turn * 2 * math.pi);
    final shadow = const Color(0xFF000000)
        .withValues(alpha: paint.color.a * 0.18);
    canvas.drawPath(cut, Paint()..color = shadow);
    canvas.restore();
    canvas.drawPath(cut, paint);
    canvas.restore();
  }

  /// A petal one unit long from its middle: round at one end, pointed at the
  /// other.
  static final Path _petal = Path()
    ..moveTo(0, -1)
    ..cubicTo(0.75, -0.7, 0.7, 0.4, 0, 1)
    ..cubicTo(-0.7, 0.4, -0.75, -0.7, 0, -1)
    ..close();

  /// A leaf: an almond, pointed at both ends, and broader than a petal.
  static final Path _leaf = Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(1.1, 0, 0, 1)
    ..quadraticBezierTo(-1.1, 0, 0, -1)
    ..close();

  /// A paper snowflake: a six-pointed star, as folded paper cuts one.
  static final Path _flake = () {
    final path = Path();
    for (var i = 0; i < 12; i++) {
      final angle = i / 12 * 2 * math.pi;
      // A point, then the valley before the next one.
      final reach = switch (i % 2) { 0 => 1.0, _ => 0.42 };
      final p = Offset(math.sin(angle), -math.cos(angle)) * reach;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }();

  @override
  bool shouldRepaint(WeatherPainter old) =>
      !listEquals(old.layers, layers) || old.falling != falling;
}

/// One particle's share of the variation, as fractions and multipliers rather
/// than pixels: the same mote is a snowflake in January and a leaf in November.
typedef _Mote = ({
  double across,
  double phase,
  double speed,
  double drift,
  double spin,
  double scale,
});
