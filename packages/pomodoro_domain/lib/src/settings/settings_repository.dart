import 'garden_settings.dart';

/// Persists [GardenSettings] as one value. No per-key writes, so a caller
/// can't save half a change.
abstract interface class SettingsRepository {
  /// Returns [GardenSettings.defaults] if nothing is saved yet. Doesn't throw.
  Future<GardenSettings> load();

  Future<void> save(GardenSettings settings);
}
