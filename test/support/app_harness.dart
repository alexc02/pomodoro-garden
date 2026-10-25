import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` — the type of a provider override — is not in Riverpod's main
// library, only in this one.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/ambience/ambience_providers.dart';
import 'package:pomodoro_garden/src/app.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/database_providers.dart';
import 'package:pomodoro_garden/src/data/drift_settings_repository.dart';
import 'package:pomodoro_garden/src/export/export_providers.dart';
import 'package:pomodoro_garden/src/export/garden_share.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/feedback/feedback_providers.dart';
import 'package:pomodoro_garden/src/garden/art_bundle.dart';
import 'package:pomodoro_garden/src/garden/art_providers.dart';
import 'package:pomodoro_garden/src/live/live_session_providers.dart';
import 'package:pomodoro_garden/src/notifications/notification_providers.dart';
import 'package:pomodoro_garden/src/quiet/quiet_mode_providers.dart';
import 'package:pomodoro_garden/src/session/session_providers.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';
import 'package:pomodoro_garden/src/time/clock_provider.dart';

import 'ambience_fake.dart';
import 'announcement_fakes.dart';
import 'garden_share_fake.dart';
import 'live_surface_fake.dart';
import 'quiet_mode_fake.dart';

/// Shared scaffolding for tests that drive the real app.
///
/// Every port the app reaches through is overridden here by default, so a test
/// only names the ones it cares about.

/// An arbitrary but fixed instant, used wherever a test needs a clock and does
/// not care what it reads.
final DateTime testInstant = DateTime.utc(2026, 8, 11, 9, 41);

/// Pumps the real app under a [ProviderScope].
///
/// Defaults to a [FixedClock] at [testInstant], because a test that renders a
/// live clock is a test that fails at midnight, and to an in-memory database,
/// because a widget test has no application documents directory to open a file
/// in. Pass `useSystemClock: true` to exercise the production clock.
///
/// Pass [database] to hold one database across two pumps — that is how the
/// "still there after a relaunch" test works.
///
/// Pass [settings] to launch with settings already stored. They are written to
/// the database rather than injected past it, so the test exercises the same
/// load the app does on a launch after the user changed something.
///
/// **Onboarding is behind the user by default**, whether or not [settings] is
/// passed: REQ-003's three steps stand between a first launch and the app, and
/// a suite where every test had to tap through them would be a suite testing
/// onboarding six hundred times over. A test about the first run passes
/// `firstLaunch: true` — see `test/features/onboarding/`.
///
/// [notifications], [endSound], [microSounds], [haptics], [liveSurface],
/// [ambience] and [quietMode] are always overridden, whether or not the test passes one: the
/// real implementations would schedule a notification on the machine running
/// the suite, open an audio session on a device that has none, decode a
/// megabyte of PCM into it, and call across platform channels nothing here
/// answers. A test passes its own only when it wants to look at what was asked
/// for — see `announcement_fakes.dart`, `live_surface_fake.dart`,
/// `ambience_fake.dart` and `quiet_mode_fake.dart`.
///
/// The quiet-mode fake defaults to reporting that this phone cannot silence
/// itself, which is the truth about the machine running the suite and keeps
/// REQ-014 out of every test that is not about it.
///
/// [gardenShare] is overridden always and for the same reason — REQ-035's share
/// sheet is a platform channel — and its default collects what it is handed
/// without opening anything. A test that cares what the exported image looked
/// like passes its own; see `garden_share_fake.dart`.
///
/// **[withArt] decides whether this launch decodes ticket 23's art set, and it
/// is off by default.** The shipping app loads seventy-eight images before its
/// first frame; a suite of nine hundred tests that each did the same would
/// spend most of its life decoding pictures none of them look at, and every one
/// of those tests was written against ticket 04's placeholder shapes anyway. So
/// the default is *no art*, which is a state the app genuinely supports — see
/// `artBundleProvider` — and which draws exactly what these tests have always
/// been asserting against.
///
/// Pass `withArt: true` to run a test through the real pipeline. Do it where
/// the art is the subject; `test/garden/art_pipeline_test.dart` is where the
/// production path is covered end to end.
Future<void> pumpApp(
  WidgetTester tester, {
  Clock? clock,
  bool useSystemClock = false,
  AppDatabase? database,
  IdSource? ids,
  Size? surface,
  GardenSettings? settings,
  bool firstLaunch = false,
  FakeSessionNotifications? notifications,
  FakeEndSoundPlayer? endSound,
  FakeMicroSounds? microSounds,
  FakeHaptics? haptics,
  FakeLiveSessionSurface? liveSurface,
  FakeAmbience? ambience,
  FakeQuietMode? quietMode,
  // The port rather than the fake, unlike the ports above it: a test about
  // REQ-035's progress needs a share sheet that stays open, which is a second
  // implementation rather than a setting on the first.
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

  // A launch that is not the app's first has been through onboarding, and says
  // so in the one place the app reads it from. Marked even when the test named
  // no settings of its own, because the *absence* of a settings row is exactly
  // what a first launch looks like — see [GardenSettings.onboardingCompleted].
  //
  // Read back and edited rather than written over, because `pumpApp` is also
  // how a test relaunches: the second pump shares the first one's database, and
  // a harness that stamped the defaults on it would undo the setting the test
  // is about to assert survived.
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

  // Decoded here rather than inside the override, because `tester.runAsync` has
  // to be awaited from the test body's own context — a provider body is already
  // inside the zone it exists to step out of.
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
        // Ticket 23's art. Off by default, and when it is on it is handed over
        // already decoded — see [withArt] and [loadedArt].
        artBundleProvider.overrideWith((ref) async => art),
        // Last, so a test that names a port explicitly wins over the default
        // this harness supplies for it.
        ...overrides,
      ],
      child: const PomodoroGardenApp(),
    ),
  );
  // [settle] rather than [WidgetTester.pumpAndSettle]: from ticket 05 a launch
  // can restore a session that is already in flight, and a session far enough
  // along puts a mature plant on screen before the first frame the user sees.
  // REQ-023's sway never stops, so `pumpAndSettle` would run to its timeout.
  await settle(tester);
}

/// Ticket 23's art set, decoded once for the whole test file.
///
/// **Two things here are not optional.**
///
/// `tester.runAsync` is the first. A `testWidgets` body runs in a zone where
/// time is fake and real asynchronous work never completes — which is what makes
/// the rest of the suite deterministic, and which means an image codec started
/// inside it simply never comes back. Decoding has to step outside that zone.
///
/// The cache is the second, and it is only about speed: seventy-eight PNGs is
/// a noticeable fraction of a second, and a file with six tests in it would
/// otherwise pay for it six times. Nothing disposes what is cached, because the
/// override below hands the bundle over directly rather than through
/// `artBundleProvider`'s own body — so the `ref.onDispose` that would release
/// these textures at the end of every test never runs, which is exactly what
/// makes reusing them safe.
ArtBundle? _art;

Future<ArtBundle> loadedArt(WidgetTester tester) async =>
    _art ??= (await tester.runAsync(() => ArtBundle.load(rootBundle)))!;

/// Taps a tab in the bottom bar by its label.
///
/// Settles by pumping a bounded run of frames rather than with
/// [WidgetTester.pumpAndSettle]: the tab being opened may have a mature plant
/// on it, and REQ-023's sway never stops.
Future<void> tapTab(WidgetTester tester, AppTab tab) async {
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(tab.label),
  ));
  await settle(tester);
}

/// Brings a settings control on screen and hands back its finder.
///
/// The settings screen is a list and most of its controls start below the fold
/// on the default test surface, so every test that touches one has to scroll
/// first — and adding a setting moves all the ones under it, which is why this
/// lives here rather than being written out per test.
///
/// Three steps, and neither of the outer two is redundant:
///
/// - **Back to the top first.** [WidgetTester.scrollUntilVisible] only ever
///   scrolls one way, so a test that has already scrolled down to one control
///   cannot reach a second one *above* it. Starting from the top makes the
///   answer the same whatever the test did before.
/// - **Then [WidgetTester.ensureVisible].** `scrollUntilVisible` stops as soon
///   as the control exists, which can leave one resting against the bottom edge
///   with its centre somewhere no tap can land — a warning, and then a tap that
///   hits the wrong thing.
Future<Finder> scrollToSetting(WidgetTester tester, Key key) =>
    scrollWithin(tester, find.byType(SettingsScreen), key);

/// Brings the control keyed [key] inside [screen] on screen.
///
/// Three steps, and neither of the outer two is redundant — see
/// [scrollToSetting], which is the caller this was written for.
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

/// Opens the timer tab and starts a session, as a user would.
///
/// From rest the button is "Plant it"; straight after a finished session,
/// beside the break on offer, it is "Plant another".
Future<void> startSession(WidgetTester tester) async {
  await tapTab(tester, AppTab.timer);
  final fresh = find.text('Plant it');
  await tester.tap(tester.any(fresh) ? fresh : find.text('Plant another'));
  await tester.pump();
}

/// Holds the running session.
Future<void> pauseSession(WidgetTester tester) async {
  await tester.tap(find.text('Pause'));
  await tester.pump();
}

/// Starts the held session again.
Future<void> resumeSession(WidgetTester tester) async {
  await tester.tap(find.text('Resume'));
  await tester.pump();
}

/// Taps CANCEL and answers the confirmation.
///
/// Both taps, because one of them is not a decision: the dialog is the point of
/// the control, and a test that reached past it would be testing a screen the
/// user never sees.
Future<void> cancelSession(WidgetTester tester, {required bool confirm}) async {
  await tester.tap(find.text('Cancel'));
  await settle(tester);
  await tester.tap(find.text(confirm ? 'Cancel session' : 'Keep focusing'));
  await settle(tester);
}

/// Tears the app down the way the *system* killing it does: the widget tree,
/// the provider scope, and everything either of them was holding — with no
/// warning to the app first.
///
/// This is the app being evicted to reclaim memory, or crashing: the process
/// stops and nothing gets a chance to write anything down. [forceQuitApp] is
/// the other way an app dies, and the difference between them is the whole of
/// ticket 05's interruption handling.
///
/// Pumping the app a second time without this would *update* the tree that is
/// already there, provider scope and all, and the "relaunch" would still be
/// looking at the state of the launch before it.
Future<void> killApp(WidgetTester tester) async {
  await _resumeBinding(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// Tears the app down the way the *user* force-quitting it does: the platform
/// says the engine is detaching, and then the process goes.
///
/// The `detached` notification is the only thing separating this from
/// [killApp], and REQ-013 hangs off it — see ADR 0005. Settled before the tree
/// goes, because the app really does get a moment here, and what it spends that
/// moment on is writing the session down as voided.
Future<void> forceQuitApp(WidgetTester tester) async {
  await sendToBackground(tester);
  await _lifecycle(tester, const [AppLifecycleState.detached]);
  await settle(tester);
  await killApp(tester);
}

/// Backgrounds the app, through every state the platform passes on the way.
///
/// Not an interruption: REQ-013 says a backgrounded session carries on, and the
/// states below `resumed` are exactly the ones the app must do nothing about.
Future<void> sendToBackground(WidgetTester tester) => _lifecycle(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);

/// Brings the app back to the foreground, through every state on the way up.
Future<void> bringToForeground(WidgetTester tester) =>
    _lifecycle(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

/// Puts the binding back in `resumed`, whatever state it was left in.
///
/// The binding stops producing frames once the app is `paused` or `detached`,
/// which is faithful to a real phone and ruinous for a test: `pumpWidget` is
/// quietly ignored, so tearing the app down and launching it again leaves the
/// *previous* launch on screen, and every expectation afterwards is asserted
/// against a tree that should not exist. A relaunch starts resumed, so this is
/// what a relaunch looks like from the binding's side of the fence.
///
/// Walked one state at a time, up the same ladder the platform comes up.
Future<void> _resumeBinding(WidgetTester tester) => _lifecycle(
      tester,
      switch (tester.binding.lifecycleState) {
        null || AppLifecycleState.resumed => const [],
        // The one jump the platform makes rather than walks: an app that has
        // detached comes back by starting again.
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

/// Walks the app through [states] in order.
///
/// One at a time and all of them, because `AppLifecycleListener` asserts on a
/// transition the platform could not have made — jumping straight from
/// `resumed` to `paused` would pass a test against a sequence no phone sends.
Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

/// Pumps frames for [over], without waiting for the screen to stop moving.
///
/// [WidgetTester.pumpAndSettle] cannot be used on a screen showing a mature
/// plant: REQ-023's ambient sway is a continuous loop by design, so the tree
/// never settles and `pumpAndSettle` runs to its timeout and fails. This pumps
/// a bounded run of frames instead — long enough for a database read to come
/// back, a tab transition to land, and a seed to finish dropping, which is what
/// the callers are actually waiting for.
///
/// **Ticket 24 widened this from a warning to a rule.** The sway used to be the
/// timer screen's alone, so "no plant on screen" was a state most tests were in.
/// It is now the garden's as well — every mature plant in it leans off one
/// controller that repeats for as long as the tab is up — and the app *opens* on
/// the garden. So there is no longer any launched-app screen that reliably
/// settles, and `pumpAndSettle` is only safe once the app has been torn down or
/// while a tab with no garden and no growing plant is in front.
///
/// Any new helper here that would have reached for `pumpAndSettle` should reach
/// for this instead.
Future<void> settle(
  WidgetTester tester, {
  Duration over = const Duration(seconds: 1),
}) async {
  const frame = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero; elapsed < over; elapsed += frame) {
    await tester.pump(frame);
  }
}

/// Renders the rest of this test in dark mode.
///
/// The app follows the system, so this is the switch a user's phone flips —
/// not a different widget tree.
void useDarkMode(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Moves both clocks forward together: the one the domain reads, and the one
/// the tester uses to fire timers.
///
/// Advancing only the tester's clock would fire the ticker against a frozen
/// session; advancing only the session's would leave the ticker asleep. The
/// pair is what a real second looks like.
Future<void> advance(
  WidgetTester tester,
  FixedClock clock,
  Duration delta,
) async {
  clock.advance(delta);
  await tester.pump(delta);
}
