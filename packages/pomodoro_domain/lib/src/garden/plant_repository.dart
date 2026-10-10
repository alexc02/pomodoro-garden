import 'garden_plot.dart';
import 'milestone.dart';
import 'plant.dart';

/// Where the garden is kept.
///
/// A port, like [SessionRepository]: the domain says what it needs of storage
/// and the app supplies SQLite. Nothing here knows about tables, and nothing in
/// the domain awaits a database.
abstract interface class PlantRepository {
  /// Writes [plant], replacing any earlier version of *that* plant.
  ///
  /// An upsert on the plant's own id, which is not the same as a guarantee that
  /// a session grows only one plant: two plantings of one session are two
  /// different ids and would be two rows. Callers ask [plantForSession] first;
  /// an implementation is expected to refuse the second write outright rather
  /// than trust them to.
  Future<void> save(Plant plant);

  /// Every plant in the garden, most recently planted first.
  Future<List<Plant>> plants();

  /// The plant grown by the session with this id, or null if that session grew
  /// nothing.
  ///
  /// Here so a completion can be recorded exactly once: the caller asks whether
  /// this session has already been planted before planting it.
  Future<Plant?> plantForSession(String sessionId);

  /// Every milestone that already has a plant standing for it: REQ-021.
  ///
  /// The whole set rather than one lookup per milestone, because there are
  /// seven of them and the question is only ever asked as "which of these does
  /// the user still have coming" — see [Milestone.dueFrom]. Asked before every
  /// award, which is what makes awarding idempotent without a counter to keep:
  /// the garden itself is the record of what has been handed out.
  ///
  /// A stored milestone this build does not recognise is left out rather than
  /// throwing, so a database written by a later version still opens.
  Future<Set<Milestone>> awardedMilestones();

  /// Every plot that already has something in it.
  ///
  /// What [GardenPlots.nextFree] needs, and all of it. Separate from [plants]
  /// because sowing one seed should not have to read a garden of two hundred
  /// rows and build two hundred objects to find out which plot is free — and
  /// because the answer is the same shape whatever else a plant grows to carry.
  Future<Set<GardenPlot>> occupiedPlots();
}
