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

/// The root widget. Sits below `ProviderScope` so tests can supply their own
/// scope with overrides.
class PipGardenApp extends StatelessWidget {
  const PipGardenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pip Garden',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // Gates run in order: art (slowest, ~78 image decodes, and everything
      // below may draw a plant), then settings, then any running session.
      // They're sequential, not parallel. Running them together is the first
      // thing to try if launch time needs clawing back.
      //
      // AppOpenKeeper goes first among the keepers since it records the
      // launch and needs both gates' data. MilestoneKeeper is last because
      // it's the only one that draws, and OnboardingOverlay sits over
      // everything.
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
