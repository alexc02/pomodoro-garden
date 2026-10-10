import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A procedural painter for the garden's sprites (PRD v2.2 §9.1).
///
/// The app's style is **paper-cut** ([Finish.paperCut]), chosen by the owner in
/// ticket 28 over a watercolour and a flat finish, which are kept so the choice
/// can be revisited by eye.
///
/// ## What it paints, and why it paints it in grey
///
/// `ImageSpriteArt.paintTinted` lays a flat palette colour **over** the drawing,
/// at the strength the role mask gives each pixel. So the colour a user sees is
/// a mix of two things: the drawing's own pixel, and the season's colour for
/// that part of the plant. A drawing painted in its own greens would fight the
/// palette in autumn, and a mask at full strength would flatten it.
///
/// So the two files split the work:
///
/// - **The drawing carries value, not hue.** It is painted in a warm neutral,
///   light where a part is lit and dark where it is shaded: a paper layer's
///   shadow, the shaded half of a leaf.
/// - **The mask carries hue, and gives way where the drawing is dark**, so a
///   shadow stays a shadow in every season instead of being painted flat.
///
/// Every function here is deterministic: the same seeds give the same pixels,
/// so re-running the generator changes nothing unless a design changes.
///
/// The PNGs are encoded here rather than through `dart:ui`, because the
/// drawing has to be stored *unpremultiplied*: rounding a soft edge through
/// premultiplied bytes would quantise exactly the pixels that matter.

/// How a sheet is painted. The shapes are the same in every finish; what
/// changes is how a shape's area is filled and how its edge is cut.
enum Finish {
  /// Uneven washes, darker rims, granulation and paper grain.
  watercolour(wobble: 1),

  /// Flat sheets of coloured paper, cut with scissors and stacked: a crisp,
  /// slightly irregular edge, a fibre texture, and a soft shadow wherever one
  /// sheet lies over another.
  paperCut(wobble: 0.55),

  /// Smooth vector shapes in flat colour, with one hard-edged shade per part
  /// and no texture at all.
  flat(wobble: 0);

  const Finish({required this.wobble});

  /// How far an outline wanders, as a multiple of what each shape asks for.
  final double wobble;
}

/// Which of a sprite's palette roles a wash belongs to: the channel of the role
/// mask that carries it (`docs/art-pipeline.md`).
enum Role { foliage, bloom, soil }

/// Smooth value noise, seeded.
final class Noise {
  const Noise(this.seed);

  final int seed;

  /// Noise at ([x], [y]), in 0–1, varying over about one unit.
  double at(double x, double y) {
    final x0 = x.floor(), y0 = y.floor();
    final fx = _fade(x - x0), fy = _fade(y - y0);
    final a = _hash(x0, y0), b = _hash(x0 + 1, y0);
    final c = _hash(x0, y0 + 1), d = _hash(x0 + 1, y0 + 1);
    final top = a + (b - a) * fx;
    final bottom = c + (d - c) * fx;
    return top + (bottom - top) * fy;
  }

  /// Several octaves of [at], each half as strong and twice as fine, in 0–1.
  double fbm(double x, double y, {int octaves = 4}) {
    var total = 0.0, amplitude = 0.5, frequency = 1.0, norm = 0.0;
    for (var i = 0; i < octaves; i++) {
      total += at(x * frequency + i * 17.3, y * frequency - i * 9.1) *
          amplitude;
      norm += amplitude;
      amplitude *= 0.5;
      frequency *= 2;
    }
    return total / norm;
  }

  double _hash(int x, int y) {
    var h = seed * 374761393 + x * 668265263 + y * 2147483647;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return (h & 0xFFFFFF) / 0xFFFFFF;
  }

  static double _fade(double t) => t * t * (3 - 2 * t);
}

/// One sprite being painted: a square sheet of paper and what is on it.
final class Sheet {
  Sheet(this.side, {this.finish = Finish.watercolour})
      : coverage = Float32List(side * side),
        density = Float32List(side * side),
        roles = [
          for (var i = 0; i < Role.values.length; i++) Float32List(side * side),
        ];

  final int side;

  final Finish finish;

  /// How much of each pixel any wash covers, 0–1. Becomes the drawing's alpha.
  final Float32List coverage;

  /// How dense the pigment is, 0 (a thin wash) to 1 (pooled and dark).
  final Float32List density;

  /// How much of each pixel's coverage belongs to each [Role], unnormalised.
  final List<Float32List> roles;

  /// Lays one wash of [role] over the sheet, in the shape of [path].
  ///
  /// [depth] is how dense the wash is across its middle, and [rim] how much
  /// darker it dries at its edge. [shade], when given, adds density by
  /// position: what makes the underside of a leaf darker than its top.
  Future<void> wash(
    Path path, {
    required Role role,
    required int seed,
    double depth = 0.2,
    double rim = 0.55,
    double mottle = 0.12,
    double Function(double x, double y)? shade,
  }) async {
    final bounds = path.getBounds().inflate(_blurRadius * 3 + 2);
    final left = math.max(0, bounds.left.floor());
    final top = math.max(0, bounds.top.floor());
    final right = math.min(side, bounds.right.ceil());
    final bottom = math.min(side, bounds.bottom.ceil());
    if (right <= left || bottom <= top) return;

    final a = await _rasterise(path);
    final blurred = _blur(a, left, top, right, bottom);
    final noise = Noise(seed);
    final channel = role.index;

    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final i = y * side + x;
        final here = a[i];

        // A sheet of paper laid over another casts a shadow on it, down and to
        // the right, softened: the whole of what makes a paper-cut read as
        // layers rather than as a flat picture.
        if (finish == Finish.paperCut && coverage[i] > 0 && here < 1) {
          final sx = x - _shadowX, sy = y - _shadowY;
          final cast = sx < left || sy < top || sx >= right || sy >= bottom
              ? 0.0
              : blurred[sy * side + sx];
          density[i] = (density[i] + 0.6 * cast * (1 - here)).clamp(0.0, 1.0);
        }

        if (here <= 0) continue;

        final shaded = shade?.call(x / side, y / side) ?? 0;
        final double laid;
        switch (finish) {
          case Finish.watercolour:
            // The rim: inside the shape and near its edge, where the blurred
            // coverage falls below the sharp one. Pigment is carried there as
            // the wash dries, which is the single most recognisable thing
            // about one.
            final edge = ((here - blurred[i]) * 3.2).clamp(0.0, 1.0);
            // A rim is never even: pigment gathers in some stretches of an
            // edge and barely at all in others.
            final gathered =
                0.25 + 1.2 * noise.fbm(x / 45 + 100, y / 45 - 100);
            final blotch = noise.fbm(x / 38, y / 38) - 0.5;
            final grain =
                noise.fbm(x / 3.5 + 400, y / 3.5 - 400, octaves: 2) - 0.5;
            laid = (depth +
                    rim * 0.7 * edge * gathered +
                    mottle * 2.6 * blotch +
                    0.3 * grain * (0.35 + depth) +
                    shaded)
                .clamp(0.0, 1.0);
          case Finish.paperCut:
          case Finish.flat:
            // One flat tone per part, and one hard-edged shade over it.
            laid = (depth * 0.5 + (shaded > 0.06 ? 0.42 : 0)).clamp(0.0, 1.0);
        }

        // Watercolour glazes: the lower wash shows through, a little. Paper and
        // flat colour are opaque: what is on top is what is seen.
        final under = density[i];
        final over = finish == Finish.watercolour
            ? 1 - (1 - under * 0.45) * (1 - laid)
            : laid;
        density[i] = under * (1 - here) + over * here;

        for (var r = 0; r < roles.length; r++) {
          roles[r][i] = roles[r][i] * (1 - here) + (r == channel ? here : 0);
        }
        coverage[i] = 1 - (1 - coverage[i]) * (1 - here);
      }
    }
  }

  /// Writes the drawing and its role mask as PNGs at [art] and [mask], and
  /// answers the tight bounds of the drawing's ink as the manifest's
  /// `[left, top, right, bottom]` fractions.
  List<double> write({required String art, required String mask}) {
    final drawing = Uint8List(side * side * 4);
    final roleMask = Uint8List(side * side * 4);
    const paper = Noise(911);

    var left = side, top = side, right = -1, bottom = -1;

    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final i = y * side + x;
        final o = i * 4;
        roleMask[o + 3] = 255;

        final alpha = (coverage[i] * 255).round();
        if (alpha == 0) continue;

        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;

        final d = density[i];
        final grain = switch (finish) {
          Finish.watercolour => (paper.at(x / 1.6, y / 1.6) - 0.5) * 0.05,
          // Paper fibre: finer, fainter, and stretched one way.
          Finish.paperCut => (paper.fbm(x / 1.2, y / 6, octaves: 2) - 0.5) * 0.12,
          Finish.flat => 0.0,
        };
        final value = (0.95 - 1.15 * d + grain).clamp(0.05, 1.0);

        // Warm neutral: a touch of red and less blue, the colour of sepia on
        // cream paper. Grey reads as cold under every palette.
        drawing[o] = _byte(value + 0.015);
        drawing[o + 1] = _byte(value);
        drawing[o + 2] = _byte(value - 0.035);
        drawing[o + 3] = alpha;

        final strength = (0.95 - 0.75 * d).clamp(0.2, 0.95);
        final total = roles[0][i] + roles[1][i] + roles[2][i];
        for (var r = 0; r < 3; r++) {
          roleMask[o + r] =
              total <= 0 ? 0 : _byte(strength * roles[r][i] / total);
        }
      }
    }

    if (right < 0) throw StateError('nothing was painted');

    File(art).writeAsBytesSync(encodePng(drawing, side, side));
    File(mask).writeAsBytesSync(encodePng(roleMask, side, side));

    return [left / side, top / side, (right + 1) / side, (bottom + 1) / side];
  }

  /// The coverage of [path], antialiased, as one value per pixel.
  Future<Float32List> _rasterise(Path path) async {
    final recorder = PictureRecorder();
    Canvas(recorder).drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
    final picture = recorder.endRecording();
    final image = await picture.toImage(side, side);
    picture.dispose();
    final bytes = (await image.toByteData())!.buffer.asUint8List();
    image.dispose();

    final out = Float32List(side * side);
    for (var i = 0; i < out.length; i++) {
      out[i] = bytes[i * 4 + 3] / 255;
    }
    return out;
  }

  /// Two box blurs of [source] within the given window: near enough to a
  /// Gaussian to find a wash's rim.
  Float32List _blur(Float32List source, int left, int top, int right, int bottom) {
    var current = source;
    for (var pass = 0; pass < 2; pass++) {
      current = _boxVertical(_boxHorizontal(current, left, top, right, bottom),
          left, top, right, bottom);
    }
    return current;
  }

  Float32List _boxHorizontal(
      Float32List s, int left, int top, int right, int bottom) {
    final out = Float32List(side * side);
    const r = _blurRadius;
    for (var y = top; y < bottom; y++) {
      var sum = 0.0;
      for (var x = left - r; x <= left + r; x++) {
        sum += _get(s, x, y);
      }
      for (var x = left; x < right; x++) {
        out[y * side + x] = sum / (2 * r + 1);
        sum += _get(s, x + r + 1, y) - _get(s, x - r, y);
      }
    }
    return out;
  }

  Float32List _boxVertical(
      Float32List s, int left, int top, int right, int bottom) {
    final out = Float32List(side * side);
    const r = _blurRadius;
    for (var x = left; x < right; x++) {
      var sum = 0.0;
      for (var y = top - r; y <= top + r; y++) {
        sum += _get(s, x, y);
      }
      for (var y = top; y < bottom; y++) {
        out[y * side + x] = sum / (2 * r + 1);
        sum += _get(s, x, y + r + 1) - _get(s, x, y - r);
      }
    }
    return out;
  }

  double _get(Float32List s, int x, int y) =>
      x < 0 || y < 0 || x >= side || y >= side ? 0 : s[y * side + x];

  static const int _blurRadius = 4;

  /// Where a paper layer's shadow falls, in pixels at 512.
  static const int _shadowX = 4, _shadowY = 7;

  static int _byte(double v) => (v.clamp(0.0, 1.0) * 255).round();
}

// ---------------------------------------------------------------------------
// Shapes. Each answers an outline as a list of points, which [wobbly] turns
// into the slightly irregular edge a brush leaves.
// ---------------------------------------------------------------------------

/// [outline], resampled every few pixels and pushed in and out along its normal
/// by smooth noise: the edge a brush leaves rather than the one a compass does.
Path wobbly(
  List<Offset> outline, {
  required int seed,
  double amplitude = 1.6,
  double wavelength = 22,
}) {
  final points = _resample(outline, 2.5);
  final noise = Noise(seed);
  final path = Path();
  var along = 0.0;

  for (var i = 0; i < points.length; i++) {
    final previous = points[(i - 1 + points.length) % points.length];
    final next = points[(i + 1) % points.length];
    if (i > 0) along += (points[i] - points[i - 1]).distance;

    final tangent = next - previous;
    final length = tangent.distance;
    final normal =
        length == 0 ? Offset.zero : Offset(-tangent.dy, tangent.dx) / length;
    // A slow wander and a faster tremor: the line of a brush, not a pen.
    final push = ((noise.fbm(along / wavelength, 0.5, octaves: 3) - 0.5) * 2 +
            (noise.at(along / 5, 7.5) - 0.5) * 0.6) *
        amplitude;
    final p = points[i] + normal * push;

    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

List<Offset> _resample(List<Offset> outline, double spacing) {
  final out = <Offset>[];
  for (var i = 0; i < outline.length; i++) {
    final a = outline[i];
    final b = outline[(i + 1) % outline.length];
    final steps = math.max(1, ((b - a).distance / spacing).ceil());
    for (var s = 0; s < steps; s++) {
      out.add(Offset.lerp(a, b, s / steps)!);
    }
  }
  return out;
}

/// An ellipse centred on [centre], turned by [angle] radians.
List<Offset> ellipse(Offset centre, double rx, double ry, {double angle = 0}) {
  const steps = 72;
  final c = math.cos(angle), s = math.sin(angle);
  return [
    for (var i = 0; i < steps; i++)
      () {
        final t = i / steps * 2 * math.pi;
        final x = math.cos(t) * rx, y = math.sin(t) * ry;
        return centre + Offset(x * c - y * s, x * s + y * c);
      }(),
  ];
}

/// The upper half of an ellipse standing on [base], carried a few pixels below
/// it so that the ink reaches the bottom row of the sheet.
List<Offset> mound(Offset base, double rx, double ry) {
  const steps = 48;
  return [
    for (var i = 0; i <= steps; i++)
      base +
          Offset(
            -math.cos(i / steps * math.pi) * rx,
            -math.sin(i / steps * math.pi) * ry,
          ),
    base + Offset(rx, 6),
    base + Offset(-rx, 6),
  ];
}

/// A point along the quadratic curve from [a] through control [c] to [b].
Offset bezier(Offset a, Offset c, Offset b, double t) {
  final u = 1 - t;
  return a * (u * u) + c * (2 * u * t) + b * (t * t);
}

/// A shape grown along the curve from [from] to [to], bowed sideways by [bend]
/// (a fraction of its length), whose half-width at each point is
/// `width(t) / 2`.
List<Offset> along(
  Offset from,
  Offset to, {
  required double Function(double t) width,
  double bend = 0,
  int steps = 40,
}) {
  final axis = to - from;
  final length = axis.distance;
  final normal = Offset(-axis.dy, axis.dx) / length;
  final control = Offset.lerp(from, to, 0.5)! + normal * (bend * length);

  final leftSide = <Offset>[];
  final rightSide = <Offset>[];
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final p = bezier(from, control, to, t);
    final ahead = bezier(from, control, to, math.min(1, t + 0.01));
    final behind = bezier(from, control, to, math.max(0, t - 0.01));
    final tangent = ahead - behind;
    final n = Offset(-tangent.dy, tangent.dx) / tangent.distance;
    final half = width(t) / 2;
    leftSide.add(p + n * half);
    rightSide.add(p - n * half);
  }
  return [...leftSide, ...rightSide.reversed];
}

/// The width profile of a leaf: nothing at the stalk, fullest a little below
/// the middle, and a point at the tip.
double Function(double) leafProfile(double width) =>
    (t) => width * math.pow(math.sin(math.pi * math.pow(t, 0.85)), 0.8);

/// The width profile of a petal: narrow where it joins, broad and rounded at
/// the far end.
double Function(double) petalProfile(double width) =>
    (t) => width * math.pow(math.sin(math.pi * (0.08 + 0.84 * t)), 0.6) *
        (0.45 + 0.55 * t);

// ---------------------------------------------------------------------------
// PNG.
// ---------------------------------------------------------------------------

/// [rgba] as an 8-bit RGBA PNG, unpremultiplied, as the format stores it.
Uint8List encodePng(Uint8List rgba, int width, int height) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    raw.add(Uint8List.sublistView(rgba, y * width * 4, (y + 1) * width * 4));
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // colour type: RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);

  final out = BytesBuilder()
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  _chunk(out, 'IHDR', header.buffer.asUint8List());
  _chunk(out, 'IDAT',
      Uint8List.fromList(ZLibCodec(level: 9).encode(raw.takeBytes())));
  _chunk(out, 'IEND', Uint8List(0));
  return out.takeBytes();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final typed = Uint8List.fromList([...type.codeUnits, ...data]);
  out
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(typed)
    ..add((ByteData(4)..setUint32(0, _crc(typed))).buffer.asUint8List());
}

int _crc(Uint8List bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}
