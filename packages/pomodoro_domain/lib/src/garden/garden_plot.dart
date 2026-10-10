/// One slot in the isometric grid, where a plant can grow.
///
/// Grid coordinates, not a position on screen. Where a plot *lands* depends on
/// the tile size and how far the user has zoomed in, and changes every frame
/// they drag; which slot of the grid a plant stands in is decided once, when it
/// is planted, and written down. The projection between the two is the view's
/// business — see `lib/src/garden/garden_projection.dart`.
///
/// Both axes run away from the viewer: [x] to the upper right and [y] to the
/// upper left, so the origin sits at the near point of the diamond and the
/// garden grows around it.
final class GardenPlot {
  const GardenPlot(this.x, this.y);

  /// The grid axis running away to the right.
  final int x;

  /// The grid axis running away to the left.
  final int y;

  /// How near the viewer this plot is: larger is nearer.
  ///
  /// The whole of the isometric sort. Because both axes run away, a plot's
  /// distance towards the viewer is the sum of them, and drawing in ascending
  /// depth is what makes a plant in front overlap the one behind it. Two plots
  /// at the same depth cannot overlap, so their order between themselves does
  /// not matter.
  int get depth => x + y;

  /// How far the plot is from the middle of the garden, squared.
  ///
  /// Squared because that is the whole of what it is used for — [GardenPlots]
  /// sorts on it — and squaring keeps it an integer, which keeps the placement
  /// order identical on every platform and in every future version of Dart. A
  /// square root would put a float in the middle of a decision that decides
  /// where every plant in the garden stands.
  int get distanceFromCentreSquared => x * x + y * y;

  /// Plots compare by value: a plot read back off a plant is the plot it was
  /// planted in.
  @override
  bool operator ==(Object other) =>
      other is GardenPlot && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'GardenPlot($x, $y)';
}

/// Where a new plant is going, and the decor that has to leave for it.
///
/// Two fields rather than one because they answer two different questions, and
/// a caller has to act on both: [plot] is where the plant stands — null only in
/// ADR 0006's full garden — and [displacing] is the plot whose decor item the
/// planting has evicted, null in every case but the last one [GardenPlots.sow]
/// reaches for. When [displacing] is set it is always equal to [plot]: the
/// plant is standing where the item stood.
typedef Sowing = ({GardenPlot? plot, GardenPlot? displacing});

/// How many plots the garden has, and which one a new plant goes into.
///
/// REQ-017 and REQ-018, as the two questions they actually are: how big is the
/// garden, and where does the next plant stand. Both are answered from the
/// count of completed sessions and from what is already in the ground — nothing
/// here is stored, incremented or unlocked by an event, so a user arriving at
/// this build with four hundred sessions behind them gets the garden they
/// earned on their first launch rather than starting again at twelve plots.
abstract final class GardenPlots {
  /// REQ-018: what the garden starts at, before a single session is finished.
  static const int initial = 12;

  /// REQ-018: how many plots an unlock is worth.
  static const int perUnlock = 4;

  /// REQ-018: how many completed sessions buy one unlock.
  static const int sessionsPerUnlock = 10;

  /// REQ-018: the largest the garden ever gets.
  static const int maximum = 200;

  /// The level a garden of [maximum] plots is at: the last one there is.
  ///
  /// Derived from the other four rather than written down, so the day one of
  /// them changes this follows instead of contradicting them.
  static const int maximumLevel = 1 + (maximum - initial) ~/ perUnlock;

  /// How many plots [completedSessions] have unlocked.
  ///
  /// This is a *floor*, not a ceiling: it is how much empty soil the garden
  /// puts in front of the user, and the garden always has at least one plot per
  /// plant besides. See
  /// `docs/adr/0006-the-garden-has-a-plot-for-every-plant-it-can-hold.md`, and
  /// [GardenLayout], which is where the two are reconciled.
  static int unlockedAfter(int completedSessions) {
    if (completedSessions <= 0) return initial;
    final unlocked = initial + perUnlock * (completedSessions ~/ sessionsPerUnlock);
    return unlocked > maximum ? maximum : unlocked;
  }

  /// REQ-028's garden level: how many times the garden has grown, counting the
  /// one it arrives with as the first.
  ///
  /// The same rule as [unlockedAfter] said as a number the user keeps rather
  /// than a number of plots — a level is what a journal puts on a page, and
  /// "Garden level 9" is a sentence where "52 plots" is a measurement. Because
  /// it is the same rule, the two cannot disagree: level *n* is always
  /// [initial] plus [perUnlock] for each level above the first.
  ///
  /// Levels stop where the garden does, at [maximumLevel] — the four hundred
  /// and seventieth completed session. A level that kept climbing past a garden
  /// that cannot would be a number about nothing.
  static int levelAfter(int completedSessions) {
    if (completedSessions <= 0) return 1;
    final level = 1 + completedSessions ~/ sessionsPerUnlock;
    return level > maximumLevel ? maximumLevel : level;
  }

  /// Every plot the garden can ever have, nearest the middle first.
  ///
  /// The order is the placement rule. A new plant takes the first plot in it
  /// that is free, so the garden fills from the centre outwards and a user who
  /// has done twenty sessions sees a small dense garden rather than twenty
  /// plants scattered over two hundred plots.
  ///
  /// Ties — the four plots one step from the middle are all equally near — are
  /// broken by y and then x, integers both. Nothing in this order is decided by
  /// a float, so it is the same order on iOS and Android and after every
  /// upgrade, which is what lets the plot a plant was planted in be recomputed
  /// rather than only ever read back.
  static final List<GardenPlot> inPlacementOrder = _placementOrder();

  /// Where [plot] comes in [inPlacementOrder], or null if it is not a plot the
  /// garden has room for at all.
  static int? orderOf(GardenPlot plot) => _order[plot];

  /// The plot a new plant goes into, given the plots already taken, or null if
  /// the garden is full.
  ///
  /// "Nearest available" rather than "next": a garden with a hole in the middle
  /// grows back into the hole. Nothing in the app removes a single plant —
  /// ticket 22's reset empties the garden wholesale and leaves no hole to grow
  /// into — but the rule that reads correctly is the one that stays correct if
  /// anything ever does.
  ///
  /// Knows nothing about REQ-040's decor. A caller that has an arrangement to
  /// respect wants [sow], which is this rule with decor written into it.
  static GardenPlot? nextFree(Set<GardenPlot> occupied) {
    for (final plot in inPlacementOrder) {
      if (!occupied.contains(plot)) return plot;
    }
    return null;
  }

  /// Where a new plant goes in a garden that also holds decor, and what has to
  /// move for it.
  ///
  /// **REQ-040's rule that decor never costs a session its plot, as one
  /// function.** Three answers, in the order they are reached for:
  ///
  /// 1. **The nearest plot holding neither.** The ordinary case, and the one
  ///    that runs for the whole life of every real garden: decor is *skipped
  ///    over* rather than pushed aside, so an arrangement the user composed is
  ///    exactly as they left it and the garden simply reaches one plot further
  ///    out than it would have. Capacity follows, because `GardenLayout` grows
  ///    the garden to hold whatever is standing in it.
  /// 2. **The outermost decor plot**, when every one of the two hundred plots
  ///    holds a plant or an item. The item there is displaced — [displacing] is
  ///    its plot, and the caller is expected to take it out of the garden — and
  ///    the plant stands where it stood. The *outermost* rather than the
  ///    nearest, because a garden fills from the middle and what a user composed
  ///    is nearest the middle: the item that gives way is the one furthest from
  ///    anything they were looking at.
  /// 3. **No plot at all**, when two hundred *plants* are already in the ground.
  ///    ADR 0006's case, unchanged and untouched by any of this: the plant is
  ///    recorded and counted, and the garden says it is holding it.
  ///
  /// The guarantee is therefore exact, and worth stating as what it is: decor
  /// is never the reason a completed session goes unplaced. A plant that has no
  /// plot in a garden with decor in it would have had no plot without it
  /// either. See `docs/adr/0017-decor-never-costs-a-plant-its-plot.md`.
  static Sowing sow({
    required Set<GardenPlot> plants,
    required Set<GardenPlot> decor,
  }) {
    GardenPlot? outermostDecor;
    for (final plot in inPlacementOrder) {
      if (plants.contains(plot)) continue;
      if (decor.contains(plot)) {
        // Walked to the end rather than stopped at, because which item gives
        // way is decided by the *last* one in the order and not the first.
        outermostDecor = plot;
        continue;
      }
      return (plot: plot, displacing: null);
    }

    if (outermostDecor == null) return (plot: null, displacing: null);
    return (plot: outermostDecor, displacing: outermostDecor);
  }

  /// [inPlacementOrder], as a lookup.
  static final Map<GardenPlot, int> _order = {
    for (var index = 0; index < inPlacementOrder.length; index++)
      inPlacementOrder[index]: index,
  };

  /// How far out the candidates run.
  ///
  /// Wide enough that the 200 nearest of them are a disc rather than a square
  /// with its corners clipped off: 200 lattice points fill a circle of radius
  /// about 8, so a square of half-width 9 has every plot that could make the
  /// cut and 161 that cannot.
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
