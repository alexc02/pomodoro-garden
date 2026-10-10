import 'garden_settings.dart';

/// Where the user's settings are kept.
///
/// A port, like `SessionRepository`: the domain says it needs somewhere to put
/// one [GardenSettings] and get it back, and the app supplies SQLite. There is
/// no key-by-key interface here on purpose — a caller that could write one
/// field at a time is a caller that can write half a change, and the whole
/// point of the typed accessor is that settings move as one value.
abstract interface class SettingsRepository {
  /// The stored settings, or [GardenSettings.defaults] on a first run.
  ///
  /// Never throws for want of a stored value. "Nothing saved yet" is the normal
  /// state of a freshly installed app, not an error it has to handle.
  Future<GardenSettings> load();

  /// Writes [settings], replacing whatever was stored before.
  Future<void> save(GardenSettings settings);
}
