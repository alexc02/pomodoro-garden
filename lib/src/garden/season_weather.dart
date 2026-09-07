import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design/season_palette.dart';
import 'garden_transition.dart';

/// Seasonal weather: blossom in spring, leaves in autumn, snow in winter,
/// nothing in summer.
///
/// Purely ambient: wrapped in [IgnorePointer] with no semantics, so taps and
/// screen readers go straight through. Particle count scales with window size
/// but is capped at [maximum], so cost is bounded next to a 200-plant garden.
/// Runs off a [Ticker] that `TickerMode` mutes on hidden tabs, and isn't
/// started at all when nothing is falling.
class SeasonWeather extends StatefulWidget {
  const SeasonWeather({required this.transition, super.key});

  /// During a theme or season change both skins' weather is drawn, one fading
  /// out as the other fades in.
  final GardenTransition transition;

  /// Cap on particles per season. Density in [Weather] sets the count on a
  /// normal phone; this stops big windows getting hundreds. Can briefly be
  /// exceeded during a crossfade, when two layers are up.
  static const int maximum = 48;

  /// The area `Weather.density` is quoted per.
  static const double densityArea = 100000;

  /// How many of [weather] belong in a window of [size], capped at [maximum].
  static int countIn(Size size, Weather weather) => math.min(
        maximum,
        (weather.density * size.width * size.height / densityArea).round(),
      );

  @override
  State<SeasonWeather> createState() => _SeasonWeatherState();
}

class _SeasonWeatherState extends State<SeasonWeather>
    with SingleTickerProviderStateMixin {
  /// Seconds the weather has been falling. A notifier passed to the painter
  /// as `repaint`, so frames repaint without rebuilding.
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

  /// Which of the two skins have anything in the air.
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
            // Leaving season thins out as the arriving one thickens.
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
/// Each particle's position is a pure function of time and index: no
/// per-particle state, no per-frame allocation. Public so
/// `test/garden/season_weather_test.dart` can time it directly, including the
/// two-layer crossfade worst case.
class WeatherPainter extends CustomPainter {
  WeatherPainter({required this.falling, required this.layers})
      : super(repaint: falling);

  /// Seconds since the weather started.
  final ValueListenable<double> falling;

  final List<WeatherLayer> layers;

  /// Per-particle variation (position, start phase, speed, wander, size),
  /// generated once from a fixed seed so it looks the same on every launch and
  /// platform. Shared by all layers; a layer with fewer takes the first ones.
  static final List<_Mote> _motes = _sow();

  static List<_Mote> _sow() {
    // Fixed seed so screenshot tests are stable.
    final random = math.Random(19);

    return List<_Mote>.generate(
      SeasonWeather.maximum,
      (_) => (
        across: random.nextDouble(),
        phase: random.nextDouble(),
        speed: 0.75 + random.nextDouble() * 0.5,
        drift: 0.6 + random.nextDouble() * 0.8,
        // Whole turns per fall, so a leaf points the same way each time it
        // wraps back to the top.
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

    // Enter above and leave below the window so nothing pops in or out.
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

  /// One paper-cut petal, leaf or flake with a small drop shadow. The shapes
  /// are unit paths built once and scaled here.
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
    // Shadow stays down-right however the mote is turned.
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

  /// Unit petal: round at one end, pointed at the other.
  static final Path _petal = Path()
    ..moveTo(0, -1)
    ..cubicTo(0.75, -0.7, 0.7, 0.4, 0, 1)
    ..cubicTo(-0.7, 0.4, -0.75, -0.7, 0, -1)
    ..close();

  /// Unit leaf: almond-shaped, broader than a petal.
  static final Path _leaf = Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(1.1, 0, 0, 1)
    ..quadraticBezierTo(-1.1, 0, 0, -1)
    ..close();

  /// Six-pointed paper snowflake.
  static final Path _flake = () {
    final path = Path();
    for (var i = 0; i < 12; i++) {
      final angle = i / 12 * 2 * math.pi;
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

/// One particle's variation, as fractions and multipliers rather than pixels,
/// so the same mote works as a flake or a leaf.
typedef _Mote = ({
  double across,
  double phase,
  double speed,
  double drift,
  double spin,
  double scale,
});
