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

/// A repository whose load never completes until the test completes it.
final class _PendingSettingsRepository implements SettingsRepository {
  final Completer<GardenSettings> loaded = Completer<GardenSettings>();

  @override
  Future<GardenSettings> load() => loaded.future;

  @override
  Future<void> save(GardenSettings settings) async {}
}

/// A repository whose writes (and optionally reads) throw.
final class _BrokenSettingsRepository implements SettingsRepository {
  _BrokenSettingsRepository({this.onLoad = true});

  final bool onLoad;

  @override
  Future<GardenSettings> load() async {
    if (onLoad) throw StateError('the database is not there');
    // Reads succeed as a returning user; only the write is broken.
    return GardenSettings.defaults.withOnboardingCompleted();
  }

  @override
  Future<void> save(GardenSettings settings) async {
    throw StateError('the database is not there');
  }
}

/// Captures reported Flutter errors so a test can assert on them.
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
      // Handing out defaults while the real settings load would give a
      // 50-minute user a 25-minute session for tapping start too soon.
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider
              .overrideWithValue(_PendingSettingsRepository()),
        ],
      );
      addTearDown(container.dispose);

      // Matched on the message: Riverpod wraps whatever the provider throws.
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
          // Settings changes also log an analytics event; there's no database
          // here, so stub the log. The event itself is covered in
          // `analytics/settings_events_test`.
          analyticsProvider.overrideWithValue(const NoAnalytics()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(settingsControllerProvider, (_, _) {});
      repository.loaded.complete(GardenSettings.defaults);
      await container.read(settingsControllerProvider.future);

      // Not awaited: the in-memory value has to be right before the write
      // lands.
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
            // Returning user, so onboarding doesn't cover the bar.
            .withOnboardingCompleted(),
      );
      // Not pumpAndSettle: the garden sway never stops.
      await settle(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      await tapTab(tester, AppTab.timer);

      // The first length the timer shows is the user's, not a default.
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

      // The control doesn't snap back; only persistence is lost.
      expect(find.text('50 min'), findsOneWidget);
      expect(find.byKey(SettingsKeys.sessionLength), findsOneWidget);
      expect(
        errors.single.context.toString(),
        contains('saving settings'),
      );
    });
  });
}
