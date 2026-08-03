/// Wipes the garden in one transaction.
///
/// One port instead of a `clear` per repository: plants, sessions and decor
/// depend on each other (capacity, awarded milestones), so a partial clear
/// leaves an impossible state. Settings are deliberately left alone.
abstract interface class GardenReset {
  /// Clears plants, sessions, decor and the event log, all or nothing.
  /// Idempotent. Derived values (capacity, streak, level) reset on their own.
  Future<void> clear();
}
