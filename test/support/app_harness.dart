import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` lives here, not in the main library.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/ambience/ambience_providers.dart';
import 'package:pip_garden/src/app.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/database_providers.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';
import 'package:pip_garden/src/export/export_providers.dart';
import 'package:pip_garden/src/export/garden_share.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/feedback/feedback_providers.dart';
import 'package:pip_garden/src/garden/art_bundle.dart';
import 'package:pip_garden/src/garden/art_providers.dart';
import 'package:pip_garden/src/live/live_session_providers.dart';
import 'package:pip_garden/src/notifications/notification_providers.dart';
import 'package:pip_garden/src/notifications/session_notifications.dart';
import 'package:pip_garden/src/quiet/quiet_mode_providers.dart';
import 'package:pip_garden/src/session/session_providers.dart';
import 'package:pip_garden/src/shell/tab.dart';
import 'package:pip_garden/src/time/clock_provider.dart';

import 'ambience_fake.dart';
import 'announcement_fakes.dart';
import 'garden_share_fake.dart';
import 'live_surface_fake.dart';
import 'quiet_mode_fake.dart';

// Shared scaffolding for tests that drive the real app. Every port is
// overridden by default, so a test only names the ones it cares about.

final DateTime testInstant = DateTime.utc(2026, 8, 11, 9, 41);

/// Pumps the real app under a [ProviderScope].
///
/// Defaults to a [FixedClock] at [testInstant] and an in-memory database.
/// Pass [database] to keep one database across two pumps (relaunch tests).
/// [settings] are written to the database, not injected, so the normal load
/// path runs. Onboarding is marked done unless `firstLaunch: true`.
///
/// All platform ports are faked by default; the quiet-mode fake reports that
/// the phone can't silence itself. Art is off by default (decoding 78 images
/// per test is too slow); pass `withArt: true` where the art matters.
Future<void> pumpApp(
  WidgetTester tester, {
  Clock? clock,
  bool useSystemClock = false,
  AppDatabase? database,
  IdSource? ids,
  Size? surface,
  GardenSettings? settings,
  bool firstLaunch = false,
  SessionNotifications? notifications,
  FakeEndSoundPlayer? endSound,
  FakeMicroSounds? microSounds,
  FakeHaptics? haptics,
  FakeLiveSessionSurface? liveSurface,
  FakeAmbience? ambience,
  FakeQuietMode? quietMode,
  // The port, not the fake: some tests need a share sheet that stays open.
  GardenShare? gardenShare,
  bool withArt = false,
  List<Override> overrides = const [],
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  final AppDatabase openDatabase;
  if (database != null) {
    openDatabase = database;
  } else {
    openDatabase = AppDatabase.forTesting();
    addTearDown(openDatabase.close);
  }

  final storedSettings = DriftSettingsRepository(openDatabase);
  if (settings != null) {
    await storedSettings.save(settings);
  }

  // Edit the stored row rather than overwrite it: a relaunch shares the
  // previous pump's database and must keep whatever the test changed.
  if (!firstLaunch) {
    final current = await storedSettings.load();
    if (!current.onboardingCompleted) {
      await storedSettings.save(current.withOnboardingCompleted());
    }
  }

  final openSurface = liveSurface ?? FakeLiveSessionSurface();
  addTearDown(openSurface.close);

  final openQuietMode = quietMode ?? FakeQuietMode();
  addTearDown(openQuietMode.close);

  // Decoded here: `tester.runAsync` has to be awaited from the test body, not
  // from inside a provider.
  final art = withArt ? await loadedArt(tester) : null;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (!useSystemClock)
          clockProvider.overrideWithValue(clock ?? FixedClock(testInstant)),
        databaseProvider.overrideWithValue(openDatabase),
        idSourceProvider.overrideWithValue(ids ?? SequentialIdSource()),
        sessionNotificationsProvider
            .overrideWithValue(notifications ?? FakeSessionNotifications()),
        endSoundPlayerProvider
            .overrideWithValue(endSound ?? FakeEndSoundPlayer()),
        microSoundsProvider
            .overrideWithValue(microSounds ?? FakeMicroSounds()),
        hapticsProvider.overrideWithValue(haptics ?? FakeHaptics()),
        liveSessionSurfaceProvider.overrideWithValue(openSurface),
        ambienceProvider.overrideWithValue(ambience ?? FakeAmbience()),
        quietModeProvider.overrideWithValue(openQuietMode),
        gardenShareProvider
            .overrideWithValue(gardenShare ?? FakeGardenShare()),
        artBundleProvider.overrideWith((ref) async => art),
        // Last, so explicit overrides win.
        ...overrides,
      ],
      child: const PipGardenApp(),
    ),
  );
  // Not pumpAndSettle: a restored session can put a swaying plant on screen.
  await settle(tester);
}

/// The art set, decoded once per test file.
///
/// Has to go through `tester.runAsync`: image decoding never completes inside
/// the fake-async zone. Cached for speed; safe because the override hands the
/// bundle over directly, so its `ref.onDispose` never releases it.
ArtBundle? _art;

Future<ArtBundle> loadedArt(WidgetTester tester) async =>
    _art ??= (await tester.runAsync(() => ArtBundle.load(rootBundle)))!;

/// Taps a tab in the bottom bar by its label.
Future<void> tapTab(WidgetTester tester, AppTab tab) async {
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(tab.label),
  ));
  await settle(tester);
}

/// Scrolls a settings control into view and returns its finder.
Future<Finder> scrollToSetting(WidgetTester tester, Key key) =>
    scrollWithin(tester, find.byType(SettingsScreen), key);

/// Scrolls the control keyed [key] inside [screen] into view.
///
/// Jumps to the top first because `scrollUntilVisible` only scrolls one way,
/// then `ensureVisible` because it can stop with the control half off screen.
Future<Finder> scrollWithin(
  WidgetTester tester,
  Finder screen,
  Key key,
) async {
  final control = find.byKey(key);
  final list = find.descendant(of: screen, matching: find.byType(Scrollable));

  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pump();

  await tester.scrollUntilVisible(control, 300, scrollable: list);
  await tester.ensureVisible(control);
  await settle(tester);

  return control;
}

/// Opens the timer tab and starts a session. The button reads "Plant another"
/// straight after a finished session.
Future<void> startSession(WidgetTester tester) async {
  await tapTab(tester, AppTab.timer);
  final fresh = find.text('Plant it');
  await tester.tap(tester.any(fresh) ? fresh : find.text('Plant another'));
  await tester.pump();
}

Future<void> pauseSession(WidgetTester tester) async {
  await tester.tap(find.text('Pause'));
  await tester.pump();
}

Future<void> resumeSession(WidgetTester tester) async {
  await tester.tap(find.text('Resume'));
  await tester.pump();
}

/// Taps Cancel and answers the confirmation dialog.
Future<void> cancelSession(WidgetTester tester, {required bool confirm}) async {
  await tester.tap(find.text('Cancel'));
  await settle(tester);
  await tester.tap(find.text(confirm ? 'Cancel session' : 'Keep focusing'));
  await settle(tester);
}

/// Tears the app down the way the system killing it does: no warning, nothing
/// gets written. Compare [forceQuitApp].
///
/// Pumping the app again without this would just update the existing tree.
Future<void> killApp(WidgetTester tester) async {
  await _resumeBinding(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// Tears the app down the way a user force-quit does: `detached` arrives first
/// and the app gets to record the session as voided (ADR 0004).
Future<void> forceQuitApp(WidgetTester tester) async {
  await sendToBackground(tester);
  await _lifecycle(tester, const [AppLifecycleState.detached]);
  await settle(tester);
  await killApp(tester);
}

/// Backgrounds the app through each lifecycle state. A backgrounded session
/// keeps running.
Future<void> sendToBackground(WidgetTester tester) => _lifecycle(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);

Future<void> bringToForeground(WidgetTester tester) =>
    _lifecycle(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

/// Puts the binding back in `resumed`. Once paused or detached the binding
/// stops producing frames and `pumpWidget` is silently ignored, so a relaunch
/// would leave the previous launch on screen.
Future<void> _resumeBinding(WidgetTester tester) => _lifecycle(
      tester,
      switch (tester.binding.lifecycleState) {
        null || AppLifecycleState.resumed => const [],
        // A detached app comes back by starting again.
        AppLifecycleState.detached => const [AppLifecycleState.resumed],
        AppLifecycleState.paused => const [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ],
        AppLifecycleState.hidden => const [
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ],
        AppLifecycleState.inactive => const [AppLifecycleState.resumed],
      },
    );

/// Walks the app through [states] one at a time; `AppLifecycleListener`
/// asserts on skipped transitions.
Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

/// Pumps frames for [over] without waiting for the screen to settle.
///
/// Use this instead of pumpAndSettle anywhere the app is up: mature plants
/// sway forever (on the timer and in the garden), so pumpAndSettle times out.
Future<void> settle(
  WidgetTester tester, {
  Duration over = const Duration(seconds: 1),
}) async {
  const frame = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero; elapsed < over; elapsed += frame) {
    await tester.pump(frame);
  }
}

/// Switches the platform to dark mode for the rest of this test.
void useDarkMode(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Moves the domain clock and the tester's timer clock forward together.
Future<void> advance(
  WidgetTester tester,
  FixedClock clock,
  Duration delta,
) async {
  clock.advance(delta);
  await tester.pump(delta);
}
