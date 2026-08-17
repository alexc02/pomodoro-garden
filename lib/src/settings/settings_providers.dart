import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../analytics/analytics_providers.dart';
import '../data/database_providers.dart';

/// The current settings. Read fields off this, e.g.
/// `ref.watch(settingsProvider).sessionLength`.
///
/// Synchronous because `SettingsGate` waits for the load. Throws if read above
/// the gate; falling back to defaults would hide the wiring bug.
final settingsProvider = Provider<GardenSettings>((ref) {
  final stored = ref.watch(settingsControllerProvider);
  if (!stored.hasValue) {
    throw StateError(
      'Settings read before they finished loading. Anything that reads '
      'settingsProvider must be below SettingsGate, which is what guarantees '
      'there is a value here to read.',
    );
  }
  return stored.requireValue;
});

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, GardenSettings>(
  SettingsController.new,
);

/// The only writer of settings. Writes a whole [GardenSettings] at a time,
/// never single fields.
class SettingsController extends AsyncNotifier<GardenSettings> {
  @override
  Future<GardenSettings> build() async {
    try {
      return await ref.watch(settingsRepositoryProvider).load();
    } catch (error, stack) {
      // Report it, but keep the app usable on defaults.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('loading settings'),
      ));
      // Skip onboarding: an unreadable row isn't a new install, and with a
      // broken DB the "completed" flag could never be saved, so onboarding
      // would show on every launch.
      return GardenSettings.defaults.withOnboardingCompleted();
    }
  }

  /// Applies [settings] immediately, then saves. (Not `update`: [AsyncNotifier]
  /// already has one.)
  ///
  /// Also records `settings_changed` by diffing old and new
  /// ([AnalyticsEvent.forSettingsChange]), so controls don't have to.
  Future<void> change(GardenSettings settings) async {
    if (state.hasValue && state.requireValue == settings) return;

    // Null only before the first load.
    final before = state.hasValue ? state.requireValue : null;
    state = AsyncData(settings);

    if (before != null) {
      final analytics = ref.read(analyticsProvider);
      for (final event in AnalyticsEvent.forSettingsChange(
        before: before,
        after: settings,
      )) {
        analytics.record(event);
      }
    }

    try {
      await ref.read(settingsRepositoryProvider).save(settings);
    } catch (error, stack) {
      // Not rolled back; snapping the control back would look broken. It just
      // won't survive a relaunch.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('saving settings $settings'),
      ));
    }
  }
}
