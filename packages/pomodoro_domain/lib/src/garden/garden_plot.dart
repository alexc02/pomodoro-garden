/// A cell in the isometric grid. Grid coordinates, not screen position (see
/// `lib/src/garden/garden_projection.dart`).
///
/// Both axes run away from the viewer ([x] up-right, [y] up-left), so the
/// origin is the near point of the diamond.
final class GardenPlot {
  const GardenPlot(this.x, this.y);

  final int x;

  final int y;

  /// Larger is nearer. Draw in ascending depth for correct overlap.
  int get depth => x + y;

  /// Squared to stay an integer, so placement order is identical everywhere.
  int get distanceFromCentreSquared => x * x + y * y;

  @override
  bool operator ==(Object other) =>
      other is GardenPlot && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'GardenPlot($x, $y)';
}

/// Result of [GardenPlots.sow]. [plot] is null only when the garden is full
///. [displacing] is set (and equals [plot]) when decor had to
/// make way.
typedef Sowing = ({GardenPlot? plot, GardenPlot? displacing});

/// Garden size and placement. Everything is derived from the completed
/// session count and what's already planted, nothing stored.
abstract final class GardenPlots {
  static const int initial = 12;

  static const int perUnlock = 4;

  static const int sessionsPerUnlock = 10;

  static const int maximum = 200;

  static const int maximumLevel = 1 + (maximum - initial) ~/ perUnlock;

  /// A floor, not a ceiling: the garden always has a plot per plant too (ADR
  /// 0006, reconciled in [GardenLayout]).
  static int unlockedAfter(int completedSessions) {
    if (completedSessions <= 0) return initial;
    final unlocked = initial + perUnlock * (completedSessions ~/ sessionsPerUnlock);
    return unlocked > maximum ? maximum : unlocked;
  }

  /// Garden level, starting at 1. Same rule as [unlockedAfter], capped at
  /// [maximumLevel].
  static int levelAfter(int completedSessions) {
    if (completedSessions <= 0) return 1;
    final level = 1 + completedSessions ~/ sessionsPerUnlock;
    return level > maximumLevel ? maximumLevel : level;
  }

  /// All possible plots, nearest the centre first, so the garden fills from
  /// the middle out. Ties break on y then x (integers only), so the order is
  /// stable across platforms and versions.
  static final List<GardenPlot> inPlacementOrder = _placementOrder();

  /// Null if [plot] is outside the 200.
  static int? orderOf(GardenPlot plot) => _order[plot];

  /// Nearest free plot, or null if full. Ignores decor; use [sow] for that.
  static GardenPlot? nextFree(Set<GardenPlot> occupied) {
    for (final plot in inPlacementOrder) {
      if (!occupied.contains(plot)) return plot;
    }
    return null;
  }

  /// Where a new plant goes when there's decor too. Decor never costs a plant
  /// its plot:
  ///
  /// 1. Nearest plot with neither. Decor is skipped, not moved.
  /// 2. If all 200 are taken, the outermost decor plot; that item is
  ///    displaced and the caller removes it.
  /// 3. No plot if 200 plants are already in.
  static Sowing sow({
    required Set<GardenPlot> plants,
    required Set<GardenPlot> decor,
  }) {
    GardenPlot? outermostDecor;
    for (final plot in inPlacementOrder) {
      if (plants.contains(plot)) continue;
      if (decor.contains(plot)) {
        // Keep going: we want the last decor plot, not the first.
        outermostDecor = plot;
        continue;
      }
      return (plot: plot, displacing: null);
    }

    if (outermostDecor == null) return (plot: null, displacing: null);
    return (plot: outermostDecor, displacing: outermostDecor);
  }

  static final Map<GardenPlot, int> _order = {
    for (var index = 0; index < inPlacementOrder.length; index++)
      inPlacementOrder[index]: index,
  };

  /// Half-width of the candidate square. 200 lattice points fill a radius of
  /// about 8, so 9 covers the whole disc.
  static const int _reach = 9;

  static List<GardenPlot> _placementOrder() {
    final candidates = <GardenPlot>[
      for (var y = -_reach; y <= _reach; y++)
        for (var x = -_reach; x <= _reach; x++) GardenPlot(x, y),
    ]..sort((a, b) {
        final byDistance = a.distanceFromCentreSquared
            .compareTo(b.distanceFromCentreSquared);
        if (byDistance != 0) return byDistance;
        final byRow = a.y.compareTo(b.y);
        return byRow != 0 ? byRow : a.x.compareTo(b.x);
      });

    return List.unmodifiable(candidates.take(maximum));
  }
}
