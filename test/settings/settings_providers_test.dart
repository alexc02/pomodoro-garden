import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/analytics/analytics_providers.dart';
import 'package:pip_garden/src/data/database_providers.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/settings/settings_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';

/// A repository whose read is still in flight until a test says otherwise.
final class _PendingSettingsRepository implements SettingsRepository {
  final Completer<GardenSettings> loaded = Completer<GardenSettings>();

  @override
  Future<GardenSettings> load() => loaded.future;

  @override
  Future<void> save(GardenSettings settings) async {}
}

/// A repository backed by a database that will not answer.
final class _BrokenSettingsRepository implements SettingsRepository {
  _BrokenSettingsRepository({this.onLoad = true});

  /// Whether the read fails too, or only the write.
  final bool onLoad;

  @override
  Future<GardenSettings> load() async {
    if (onLoad) throw StateError('the database is not there');
    // A store that answers is a store that has been written to, so it answers
    // like one: onboarding behind the user. Only the *write* is broken here.
    return GardenSettings.defaults.withOnboardingCompleted();
  }

  @override
  Future<void> save(GardenSettings settings) async {
    throw StateError('the database is not there');
  }
}

/// Collects what would otherwise be a reported crash, so a test can assert on
/// it instead of failing on it.
List<FlutterErrorDetails> captureErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}

void main() {
  group('the accessor', () {
    test('refuses to be read before the settings have loaded', () {
      // The alternative — handing out defaults while the real settings are
      // still in flight — is how a user with a 50-minute session gets a
      // 25-minute one for tapping START quickly. Better to make the mistake
      // impossible to make quietly.
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider
              .overrideWithValue(_PendingSettingsRepository()),
        ],
      );
      addTearDown(container.dispose);

      // Matched on the message rather than the type: Riverpod wraps whatever a
      // provider throws, so what reaches a caller is its exception carrying
      // ours. The message is the part that has to tell someone what to do.
      expect(
        () => container.read(settingsProvider),
        throwsA(isA<Object>().having(
          (error) => error.toString(),
          'message',
          contains('must be below SettingsGate'),
        )),
      );
    });

    test('hands out the stored settings once they have loaded', () async {
      final repository = _PendingSettingsRepository();
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.listen(settingsControllerProvider, (_, _) {});

      repository.loaded.complete(
        GardenSettings.defaults.withSessionLength(const Duration(minutes: 50)),
      );
      await container.read(settingsControllerProvider.future);

      expect(
        container.read(settingsProvider).sessionLength,
        const Duration(minutes: 50),
      );
    });

    test('a change is visible through the accessor immediately', () async {
      final repository = _PendingSettingsRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          // A change is also a §7.1 event, and this container has no database
          // for one to land in — the port exists so a test can say so in a
          // line. What the event carries is `analytics/settings_events_test`.
          analyticsProvider.overrideWithValue(const NoAnalytics()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(settingsControllerProvider, (_, _) {});
      repository.loaded.complete(GardenSettings.defaults);
      await container.read(settingsControllerProvider.future);

      // Not awaited: what the next session reads is the in-memory value, and
      // it has to be right before the write finishes.
      unawaited(container
          .read(settingsControllerProvider.notifier)
          .change(GardenSettings.defaults.withLongBreakAfter(2)));

      expect(container.read(settingsProvider).longBreakAfter, 2);
    });
  });

  group('the gate', () {
    testWidgets('holds the app back until the settings are read',
        (tester) async {
      final repository = _PendingSettingsRepository();
      await pumpApp(
        tester,
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );

      expect(find.byType(NavigationBar), findsNothing,
          reason: 'no screen is reachable until settings are in hand');

      repository.loaded.complete(
        GardenSettings.defaults
            .withSessionLength(const Duration(minutes: 50))
            // A returning user: what is being tested is the wait, not REQ-003's
            // welcome, and a first-launch answer here would put onboarding over
            // the bar this test is looking for.
            .withOnboardingCompleted(),
      );
      // [settle] rather than `pumpAndSettle`: the app opens on the garden, and
      // REQ-023's sway is a ticker that never runs down — so there is no
      // moment of quiet for `pumpAndSettle` to wait for, and it would sit here
      // until it gave up. Pumping a bounded run of frames is what the harness
      // has this helper for.
      await settle(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      await tapTab(tester, AppTab.timer);

      // The point of the wait: the first thing the timer ever shows is the
      // user's own length, not a default it would have to correct.
      expect(find.text('50:00'), findsOneWidget);
    });
  });

  group('when the database will not answer', () {
    testWidgets('the app still opens, on the defaults, and says so',
        (tester) async {
      final errors = captureErrors();

      await pumpApp(
        tester,
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _BrokenSettingsRepository(),
          ),
        ],
      );
      await tapTab(tester, AppTab.timer);

      expect(find.text('25:00'), findsOneWidget,
          reason: 'a user who cannot read their settings still gets a timer');
      expect(
        errors.single.context.toString(),
        contains('loading settings'),
      );
    });

    testWidgets('a change that cannot be written is reported but still applies',
        (tester) async {
      final errors = captureErrors();

      await pumpApp(
        tester,
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _BrokenSettingsRepository(onLoad: false),
          ),
        ],
      );
      await tapTab(tester, AppTab.settings);
      await tester.tap(find.text('Deep · 50'));
      await tester.pumpAndSettle();

      // The control does not snap back under the user's finger: what was lost
      // is the change surviving a relaunch, not the change.
      expect(find.text('50 min'), findsOneWidget);
      expect(find.byKey(SettingsKeys.sessionLength), findsOneWidget);
      expect(
        errors.single.context.toString(),
        contains('saving settings'),
      );
    });
  });
}
