import 'package:flutter/material.dart';

import 'ambience/ambience_keeper.dart';
import 'analytics/app_open_keeper.dart';
import 'design/theme.dart';
import 'features/onboarding/onboarding_overlay.dart';
import 'garden/art_gate.dart';
import 'garden/milestone_keeper.dart';
import 'live/live_surface_keeper.dart';
import 'quiet/quiet_mode_keeper.dart';
import 'session/session_announcer.dart';
import 'session/session_gate.dart';
import 'session/session_lifecycle.dart';
import 'settings/settings_gate.dart';
import 'shell/app_shell.dart';

/// The app's root widget: themes, then the shell.
///
/// Deliberately below `ProviderScope` rather than containing it, so a widget
/// test can wrap this in its own scope with overrides.
class PipGardenApp extends StatelessWidget {
  const PipGardenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pip Garden',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // The garden has a day and a night look; follow the system so the app
      // matches whichever the user is already in.
      themeMode: ThemeMode.system,
      // What a launch has to know before it can draw a timer, in the order it
      // has to know it: what the plants look like, then the user's settings,
      // then whether they are already in a session.
      //
      // [ArtGate] is outermost because it is the longest of the three waits by a
      // distance — seventy-eight images decoded, against two single-row
      // selects — and because everything below it may draw a plant. The three
      // run one after another rather than together, which is a launch-budget
      // cost recorded in `docs/performance-record.md` rather than hidden: if
      // the device reading needs it back, starting the art decode alongside the
      // first query is where to get it.
      //
      // The shell runs with all three in hand, with the fact of the launch
      // written down — see [AppOpenKeeper] — with the app's lifecycle
      // wired to the session — see [SessionLifecycle] — and with what the
      // session has to say wired to the user, see [SessionAnnouncer], what
      // it looks like from outside the app, see [LiveSurfaceKeeper], what
      // it sounds like, see [AmbienceKeeper], how quiet everything else is
      // while it runs, see [QuietModeKeeper], and what a milestone reached
      // along the way is celebrated with, see [MilestoneKeeper].
      //
      // [AppOpenKeeper] is outermost of the keepers because what it records is
      // the launch itself, which happened before any of the rest of them had
      // anything to say — and it is below both gates because both halves of
      // what it writes down are read from the database.
      //
      // [MilestoneKeeper] is innermost of the seven on purpose: it is the only
      // one that puts something on screen, and it holds back for every one of
      // the others rather than the other way round.
      //
      // Inside all of them is [OnboardingOverlay], which is not a keeper: it
      // does not watch the session, it lays REQ-003's three steps over the
      // shell on a first launch and gets out of the way. It is innermost
      // because it is the one thing that should be over everything — a
      // milestone celebration cannot reach a user who has completed no
      // sessions, and a welcome screen under one would be a welcome screen
      // nobody could dismiss.
      home: const ArtGate(
        child: SettingsGate(
          child: SessionGate(
            child: AppOpenKeeper(
              child: SessionLifecycle(
                child: SessionAnnouncer(
                  child: LiveSurfaceKeeper(
                    child: AmbienceKeeper(
                      child: QuietModeKeeper(
                        child: MilestoneKeeper(
                          child: OnboardingOverlay(child: AppShell()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
