import 'milestone.dart';
import 'plant.dart';
import 'plant_type.dart';

/// What a session species earns as more of it are grown.
///
/// One ladder for every species, however long its sessions are: the first
/// marks come quickly and the last is meant to take a long time. Milestone
/// plants have no marks; each is awarded once.
enum MasteryMark {
  first(1),
  fifth(5),
  twentyFifth(25),
  hundredth(100);

  const MasteryMark(this.grown);

  /// Plants of the species needed for this mark. Ascending; [reachedBy]
  /// relies on that.
  final int grown;

  /// Ascending.
  static List<MasteryMark> reachedBy(int grown) {
    final reached = <MasteryMark>[];
    for (final mark in values) {
      if (grown < mark.grown) break;
      reached.add(mark);
    }
    return List.unmodifiable(reached);
  }

  /// The mark still ahead, or null once the last is earned.
  static MasteryMark? nextAfter(int grown) {
    for (final mark in values) {
      if (grown < mark.grown) return mark;
    }
    return null;
  }
}

/// One species' place on the shelf.
final class ShelfSpot {
  const ShelfSpot._({
    required this.species,
    required this.grown,
    required this.stored,
  });

  final PlantSpecies species;

  /// Every plant of this species ever grown or awarded, wherever it stands.
  /// Mastery counts these, so the garden and the shelf don't compete.
  final int grown;

  /// The ones on the shelf right now, most recently planted first.
  final List<Plant> stored;

  /// False until the first one is grown; the spot keeps its name back until
  /// then.
  bool get isDiscovered => grown > 0;

  /// Grown, but every one of them is in the garden.
  bool get isBare => isDiscovered && stored.isEmpty;

  /// The milestone that awards this species. Null if sessions grow it.
  Milestone? get milestone => Milestone.awarding(species);

  /// Ascending. Always empty for a milestone plant.
  List<MasteryMark> get marks =>
      milestone == null ? MasteryMark.reachedBy(grown) : const [];

  /// Null once every mark is earned, and for a milestone plant.
  MasteryMark? get nextMark =>
      milestone == null ? MasteryMark.nextAfter(grown) : null;

  @override
  String toString() =>
      'ShelfSpot(${species.name}, $grown grown, ${stored.length} stored)';
}

/// The spots for one [PlantType], in the order the species are declared (for
/// milestone plants, the order they're awarded).
final class ShelfRow {
  const ShelfRow._(this.type, this.spots);

  final PlantType type;

  final List<ShelfSpot> spots;

  int get discovered => spots.where((spot) => spot.isDiscovered).length;

  @override
  String toString() =>
      'ShelfRow(${type.name}, $discovered of ${spots.length})';
}

/// The shelf: a spot for every species, holding the plants that aren't in the
/// garden. Recomputed from the stored plants, like `GardenLayout`; nothing
/// about it is stored.
final class Shelf {
  const Shelf._(this.rows, this._spots);

  factory Shelf.of(List<Plant> plants) {
    final grown = <PlantSpecies, int>{};
    final stored = <PlantSpecies, List<Plant>>{};

    for (final plant in plants) {
      grown[plant.species] = (grown[plant.species] ?? 0) + 1;
      if (plant.isShelved) (stored[plant.species] ??= []).add(plant);
    }

    final spots = <PlantSpecies, ShelfSpot>{
      for (final species in PlantSpecies.values)
        species: ShelfSpot._(
          species: species,
          grown: grown[species] ?? 0,
          stored: List.unmodifiable(
            (stored[species] ?? <Plant>[])..sort(_newestFirst),
          ),
        ),
    };

    return Shelf._(
      List.unmodifiable([
        for (final type in PlantType.values)
          ShelfRow._(
            type,
            List.unmodifiable([
              for (final species in PlantSpecies.of(type)) spots[species]!,
            ]),
          ),
      ]),
      spots,
    );
  }

  /// One per [PlantType], smallest sessions first, milestone plants last.
  final List<ShelfRow> rows;

  final Map<PlantSpecies, ShelfSpot> _spots;

  ShelfSpot spotFor(PlantSpecies species) => _spots[species]!;

  /// Plants on the shelf, across every spot.
  int get stored =>
      _spots.values.fold(0, (total, spot) => total + spot.stored.length);

  /// Species grown at least once.
  int get discovered =>
      _spots.values.where((spot) => spot.isDiscovered).length;

  /// Every species there is, milestone plants included.
  int get species => _spots.length;

  /// The id breaks ties so the order doesn't depend on the query's.
  static int _newestFirst(Plant a, Plant b) {
    final byDate = b.plantedAt.compareTo(a.plantedAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }
}
