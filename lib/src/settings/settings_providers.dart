import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../analytics/analytics_providers.dart';
import '../data/database_providers.dart';

/// The user's settings, as the app is running on them right now.
///
/// **This is the accessor.** Everything that needs a setting watches this and
/// reads a field off it — `ref.watch(settingsProvider).sessionLength` — rather
/// than reaching for a key, a column or a provider of its own. A later ticket
/// adding a setting adds a field to [GardenSettings] and a row to the settings
/// screen; no existing call site changes, and no two call sites can disagree
/// about what a setting is called or what its default is.
///
/// Synchronous, and deliberately so: `SettingsGate` holds the app back until
/// the stored settings have been read, so below the gate there is no loading
/// state for a caller to handle and no window in which a fast tap could start a
/// session on a length the user replaced three launches ago.
///
/// Throws if read above the gate. That is a wiring bug — the same judgement
/// `GardenColors.of` makes — and papering over it with defaults would mean
/// shipping a build that silently ignores the user's settings.
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

/// Reads the stored settings once at launch, and writes every change back.
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, GardenSettings>(
  SettingsController.new,
);

/// The one writer of settings.
///
/// Settings move as a whole [GardenSettings] rather than a field at a time: a
/// caller that could write one field could write half a change, and the value
/// object is what makes "these three numbers are consistent with each other" a
/// thing that can be true.
class SettingsController extends AsyncNotifier<GardenSettings> {
  @override
  Future<GardenSettings> build() async {
    try {
      return await ref.watch(settingsRepositoryProvider).load();
    } catch (error, stack) {
      // A database that will not answer is a broken app, not a broken setting —
      // sessions are stored in the same file. Reported loudly, then the timer
      // is left working on the defaults, because a user who cannot read their
      // settings is still better served by a 25-minute session than by a screen
      // that will not open.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pomodoro_garden',
        context: ErrorDescription('loading settings'),
      ));
      // The defaults, except for the one field where "we could not read it" and
      // "this is a new install" are not the same claim. REQ-003's onboarding is
      // shown to a user with no settings row; a user whose row cannot be read
      // has one, and greeting them as a stranger — every launch, because the
      // flag written at the end of the flow cannot be written either — would
      // turn a bad database into an app they can never get past.
      return GardenSettings.defaults.withOnboardingCompleted();
    }
  }

  /// Applies [settings] and writes them down.
  ///
  /// Named `change` rather than `update` because [AsyncNotifier] already has an
  /// `update`, which does something else.
  ///
  /// The new value is live the moment this returns to the caller, before the
  /// write finishes: the screen has to follow the user's finger, and a stored
  /// row is not what the next session reads its length from. It is what the
  /// launch *after* the next one reads it from, which is why a failed write is
  /// worth reporting.
  ///
  /// §7.1's `settings_changed` is recorded here rather than by the controls,
  /// and that is the one place it can be: settings move as a whole value, so
  /// *which* setting changed is a comparison of two of them — see
  /// [AnalyticsEvent.forSettingsChange]. The settings screen, the ambience
  /// picker on the timer and onboarding's length step are all instrumented by
  /// this one line, and a ticket adding a setting adds no call site.
  Future<void> change(GardenSettings settings) async {
    if (state.hasValue && state.requireValue == settings) return;

    // Null only above the gate, where nothing has been read yet — there is no
    // "what it was" for a change from a value the app never had.
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
      // Not rolled back. The user changed a setting and the app is behaving as
      // though they did; snapping the control back under their finger would
      // make a lost write look like a broken control. What is lost is the
      // change surviving a relaunch, and that is what gets reported.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pomodoro_garden',
        context: ErrorDescription('saving settings $settings'),
      ));
    }
  }
}
