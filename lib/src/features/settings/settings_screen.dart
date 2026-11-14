import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/headline.dart';
import '../../design/page_header.dart';
import '../../design/paper_card.dart';
import '../../design/sky_band_backdrop.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../garden/daylight_providers.dart';
import '../../garden/garden_providers.dart';
import '../../garden/garden_reset_providers.dart';
import '../../session/session_providers.dart';
import '../../garden/season_providers.dart';
import '../../garden/theme_providers.dart';
import '../../onboarding/onboarding_providers.dart';
import '../../quiet/quiet_mode.dart';
import '../../quiet/quiet_mode_providers.dart';
import '../../settings/settings_providers.dart';
import '../../shell/tab.dart';
import '../../time/clock_provider.dart';
import '../garden/export_garden.dart';
import '../garden/theme_picker.dart';
import 'end_sound_picker.dart';
import 'event_log_screen.dart';
import 'reset_garden.dart';

/// Keys for the settings controls, so tests don't have to find "the second
/// slider".
abstract final class SettingsKeys {
  static const Key sessionLength = Key('settings.sessionLength');

  static Key sessionPreset(SessionPreset preset) =>
      Key('settings.sessionPreset.${preset.name}');

  static Key breakPreset(BreakPreset preset) =>
      Key('settings.breakPreset.${preset.name}');
  static const Key breakLength = Key('settings.breakLength');
  static const Key longBreakAfter = Key('settings.longBreakAfter');
  static const Key haptics = Key('settings.haptics');
  static const Key liveSurface = Key('settings.liveSurface');
  static const Key autoStartBreak = Key('settings.autoStartBreak');
  static const Key autoStartNextSession = Key('settings.autoStartNextSession');

/// Only shown where the platform can act on it.
  static const Key quietMode = Key('settings.quietMode');

/// Only shown where the platform can't. See [_QuietModeSection].
  static const Key quietModeHint = Key('settings.quietModeHint');
  static const Key quietModeRecipe = Key('settings.quietModeRecipe');

  static const Key quietModeUnsupported = Key('settings.quietModeUnsupported');

  static const Key gardenTheme = Key('settings.gardenTheme');

/// Debug builds only.
  static const Key season = Key('settings.season');

  /// Debug only.
  static const Key timeOfDay = Key('settings.timeOfDay');
  static const Key timeOfDaySlider = Key('settings.timeOfDaySlider');

/// Debug builds only.
  static const Key milestonePreview = Key('settings.milestonePreview');

/// Debug builds only.
  static const Key onboardingReset = Key('settings.onboardingReset');

/// Debug builds only.
  static const Key eventLog = Key('settings.eventLog');
}

/// Settings screen. Every control reads and writes one [GardenSettings]
/// through `settingsProvider`.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SkyBandBackdrop(depth: 0.24),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: PageHeader.pagePadding,
              children: [
                PageHeader(headline: AppTab.settings.label),
                const _FocusSessionSection(),
                const SizedBox(height: Spacing.lg),
                const _BreaksSection(),
                const SizedBox(height: Spacing.lg),
                const _FeedbackSection(),
                const SizedBox(height: Spacing.lg),
                const _LiveSessionSection(),
                const SizedBox(height: Spacing.lg),
                const _QuietModeSection(),
                const SizedBox(height: Spacing.lg),
                const _GardenSection(),
                const SizedBox(height: Spacing.lg),
                const _ResetSection(),
                // Debug-only tools go last so the list doesn't open on them.
                if (kDebugMode) ...[
                  const SizedBox(height: Spacing.lg),
                  const _SeasonSection(),
                  const SizedBox(height: Spacing.lg),
                  const _TimeOfDaySection(),
                  const SizedBox(height: Spacing.lg),
                  const _MilestonePreviewSection(),
                  const SizedBox(height: Spacing.lg),
                  const _OnboardingSection(),
                  const SizedBox(height: Spacing.lg),
                  const _EventLogSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusSessionSection extends ConsumerWidget {
  const _FocusSessionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return _Section(
      title: 'Focus session',
      children: [
        _PresetChips(
          presets: SessionPreset.values,
          describe: (preset) => (preset.label, preset.length),
          keyOf: SettingsKeys.sessionPreset,
          selected: settings.preset,
          onSelected: (preset) => _change(ref, (s) => s.withPreset(preset)),
        ),
        _SettingSlider(
          key: SettingsKeys.sessionLength,
          label: 'Session length',
          value: settings.sessionLength.inMinutes,
          min: SettingsRanges.sessionLength.min.inMinutes,
          max: SettingsRanges.sessionLength.max.inMinutes,
          format: _minutes,
          onChanged: (minutes) => _change(
            ref,
            (s) => s.withSessionLength(Duration(minutes: minutes)),
          ),
        ),
        const _Note(
          'Changes apply from your next session. One that\'s already growing '
          'keeps its length.',
        ),
      ],
    );
  }
}

class _BreaksSection extends ConsumerWidget {
  const _BreaksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return _Section(
      title: 'Breaks',
      children: [
        // Presets set the ordinary break; the long break follows it.
        _PresetChips(
          presets: BreakPreset.values,
          describe: (preset) => (preset.label, preset.length),
          keyOf: SettingsKeys.breakPreset,
          selected: settings.breakPreset,
          onSelected: (preset) =>
              _change(ref, (s) => s.withBreakPreset(preset)),
        ),
        _SettingSlider(
          key: SettingsKeys.breakLength,
          label: 'Break length',
          value: settings.breakLength.inMinutes,
          min: SettingsRanges.breakLength.min.inMinutes,
          max: SettingsRanges.breakLength.max.inMinutes,
          format: _minutes,
          onChanged: (minutes) => _change(
            ref,
            (s) => s.withBreakLength(Duration(minutes: minutes)),
          ),
        ),
        _SettingSlider(
          key: SettingsKeys.longBreakAfter,
          label: 'Long break after',
          value: settings.longBreakAfter,
          min: SettingsRanges.longBreakAfter.min,
          max: SettingsRanges.longBreakAfter.max,
          format: _sessions,
          onChanged: (count) => _change(ref, (s) => s.withLongBreakAfter(count)),
        ),
        // Two switches, not one: plenty of people want the break started for
        // them but want to start the next session themselves.
        SwitchListTile(
          key: SettingsKeys.autoStartBreak,
          value: settings.autoStartBreak,
          onChanged: (enabled) =>
              _change(ref, (s) => s.withAutoStartBreak(enabled: enabled)),
          title: const Text('Start breaks automatically'),
          subtitle: const Text(
            'Your break starts as soon as a session ends, without waiting for a '
            'tap.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          key: SettingsKeys.autoStartNextSession,
          value: settings.autoStartNextSession,
          onChanged: (enabled) =>
              _change(ref, (s) => s.withAutoStartNextSession(enabled: enabled)),
          title: const Text('Start sessions automatically'),
          subtitle: const Text(
            'The next session starts as soon as a break ends.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const _Note(
          'With both on, the timer goes from focus to break and back by itself. '
          'Nothing starts while the app is closed; it picks up when you open it '
          'again.',
        ),
      ],
    );
  }
}

/// End sound and haptics. "None" in the sound picker is how sound is turned
/// off, so there's no separate switch.
class _FeedbackSection extends ConsumerWidget {
  const _FeedbackSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return _Section(
      title: 'Feedback',
      children: [
        const EndSoundPicker(),
        // The preview plays on the same audio session as the real chime, which
        // the silent switch mutes on purpose.
        const _Note(
          'Plays when a session finishes, in the app or in the notification if '
          'you\'re away. Tap one to hear it, unless your phone is on silent.',
        ),
        SwitchListTile(
          key: SettingsKeys.haptics,
          value: settings.hapticsEnabled,
          onChanged: (enabled) =>
              _change(ref, (s) => s.withHaptics(enabled: enabled)),
          title: const Text('Haptics'),
          subtitle: const Text(
            'A gentle tap when a session finishes, and a lighter one each time '
            'your plant grows.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// Live Activity on iOS, ongoing notification on Android. Same copy on both.
class _LiveSessionSection extends ConsumerWidget {
  const _LiveSessionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return _Section(
      title: 'Live session',
      children: [
        SwitchListTile(
          key: SettingsKeys.liveSurface,
          value: settings.liveSurfaceEnabled,
          onChanged: (enabled) =>
              _change(ref, (s) => s.withLiveSurface(enabled: enabled)),
          title: const Text('Show on the lock screen'),
          subtitle: const Text(
            'Your countdown and your plant, while the app is closed.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        // The session is clock-anchored and its end notification is already
        // scheduled, so this switch only hides the surface.
        const _Note(
          'Turning this off doesn\'t stop a session. It still finishes, and '
          'still lets you know.',
        ),
      ],
    );
  }
}

/// Quiet mode. Branches on [QuietModeAccess], never on platform: a switch where
/// the app can silence the phone, the Shortcuts recipe where it can't. No
/// switch at all where it would do nothing.
class _QuietModeSection extends ConsumerWidget {
  const _QuietModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing until the platform answers (one channel call at launch), rather
    // than guessing and showing a switch that then disappears.
    final access = ref.watch(quietModeAccessProvider).value;
    if (access == null) return const SizedBox.shrink();

    return _Section(
      title: 'Quiet mode',
      children: switch (access) {
        QuietModeAccess.granted ||
        QuietModeAccess.denied =>
          _automatic(context, ref, access: access),
        QuietModeAccess.byAutomation => _byHand(context, ref),
        QuietModeAccess.unavailable => const [
            _Note(
              key: SettingsKeys.quietModeUnsupported,
              'This phone doesn\'t let apps change Do Not Disturb, so sessions '
              'keep your sound as it is. You can switch it on yourself before '
              'you start.',
            ),
          ],
      },
    );
  }

  List<Widget> _automatic(
    BuildContext context,
    WidgetRef ref, {
    required QuietModeAccess access,
  }) {
    final settings = ref.watch(settingsProvider);
    final granted = access == QuietModeAccess.granted;
    // Show what's actually happening, not what was asked for: if the
    // permission was revoked in system settings the switch reads off.
    final revoked = settings.quietModeEnabled && !granted;

    return [
      SwitchListTile(
        key: SettingsKeys.quietMode,
        value: settings.quietModeEnabled && granted,
        onChanged: (enabled) =>
            _setQuietMode(context, ref, enabled: enabled, granted: granted),
        title: const Text('Silence your phone'),
        subtitle: const Text(
          'Calls and notifications are held back while a session runs, and '
          'come through again the moment it ends.',
        ),
        contentPadding: EdgeInsets.zero,
      ),
      if (revoked)
        const _Note(
          'Pip Garden doesn\'t have permission to silence your phone, so '
          'sessions run with the sound on. Turn the switch on again to grant '
          'it.',
        )
      else
        const _Note(
          'Alarms and reminders still come through, and so does the note that '
          'your session\'s finished.',
        ),
    ];
  }

  List<Widget> _byHand(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(settingsProvider).quietModeHintDismissed;

    return [
      if (!dismissed)
        _QuietModeHint(
          key: SettingsKeys.quietModeHint,
          // Either answer dismisses the hint for good.
          onShowMe: () {
            _change(ref, (s) => s.withQuietModeHintDismissed());
            _showTheRecipe(context);
          },
          onDismiss: () => _change(ref, (s) => s.withQuietModeHintDismissed()),
        ),
      // Stays after the hint is dismissed so the instructions aren't lost.
      ListTile(
        key: SettingsKeys.quietModeRecipe,
        onTap: () => _showTheRecipe(context),
        title: const Text('Silencing your phone for a session'),
        subtitle: const Text(
          'Your phone doesn\'t let apps turn on a Focus. A Shortcut can, and it '
          'can start your session at the same time.',
        ),
        trailing: const Icon(Icons.chevron_right),
        contentPadding: EdgeInsets.zero,
      ),
    ];
  }

/// Writes the setting, then if access hasn't been granted yet explains and
/// offers to open system settings. The setting is saved either way.
  void _setQuietMode(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
    required bool granted,
  }) {
    _change(ref, (s) => s.withQuietMode(enabled: enabled));
    if (!enabled || granted) return;

    // Explain first: system settings opens on a list of every app with no
    // context, and there's no runtime dialog for this permission.
    unawaited(showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('One thing to switch on'),
        content: const Text(
          'Your phone has to give Pip Garden permission first, and that '
          'happens in system settings.\n\nFind Pip Garden in the list that '
          'opens and turn it on, then come straight back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(ref.read(quietModeProvider).requestAccess());
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    ));
  }

/// Written out rather than linked, since it's four steps. The App Intent in
/// step 3 is `QuietMode.sessionRequests`.
  void _showTheRecipe(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silence your phone for a session'),
        content: const SingleChildScrollView(
          child: Text(
            'No app can turn on a Focus mode for you, but Shortcuts can, and it '
            'can start your session at the same time.\n\n'
            '1. Open Shortcuts and create a new shortcut.\n'
            '2. Add "Set Focus". Choose Do Not Disturb, turn it on, and set it '
            'to last until the time your session will end.\n'
            '3. Add "Start a focus session" — it is under Pip Garden.\n'
            '4. Name it, then run it instead of tapping Start. It works from '
            'the Home Screen, from the share sheet, or by asking Siri.\n\n'
            'Do Not Disturb turns itself off at the time you chose, so your '
            'phone won\'t stay silenced.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ));
  }
}

/// A row that opens the theme picker; the previews need more room than a
/// settings list has. Not locked during a session.
class _GardenSection extends ConsumerWidget {
  const _GardenSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(gardenThemeProvider);

    return _Section(
      title: 'Garden',
      children: [
        OutlinedButton(
          key: SettingsKeys.gardenTheme,
          onPressed: () => unawaited(showThemePicker(context)),
          child: Text('Theme: ${chosen.label}'),
        ),
        const _Note(
          'Every theme turns with the seasons.',
        ),
        // Export lives here since it's a picture of this garden.
        const ExportGardenTile(),
      ],
    );
  }
}

/// Reset. Kept at the bottom so nobody hits it on the way to a slider, and so
/// the control disappearing doesn't shift anything above it.
///
/// Disabled while a timer is running rather than cancelling the session. See
/// [gardenMayBeResetProvider].
class _ResetSection extends StatelessWidget {
  const _ResetSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      title: 'Reset',
      children: [
        _ResetDoor(),
        _Note(
          'Your settings and theme stay as they are.',
        ),
      ],
    );
  }
}

class _ResetDoor extends ConsumerWidget {
  const _ResetDoor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(gardenMayBeResetProvider)) {
      // A finished session has nothing to cancel, so it gets its own message.
      final finished = ref.watch(sessionControllerProvider).phase ==
          SessionPhase.completed;
      return _Note(
        key: ResetGardenKeys.heldBack,
        finished
            ? 'Your session\'s just finished. Take its break first (you can '
                'skip it), then you can reset.'
            : 'A session or break is running. Finish or cancel it first; '
                'resetting won\'t end it for you.',
      );
    }

    // Outlined in the error colour so it reads as the exit, not the next step.
    final scheme = Theme.of(context).colorScheme;
    final clearing =
        ref.watch(gardenResetControllerProvider) == Resetting.clearing;

    return OutlinedButton(
      key: ResetGardenKeys.control,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error),
      ),
      onPressed: clearing ? null : () => unawaited(_reset(context, ref)),
      child: const Text('Reset your garden'),
    );
  }

/// Confirms twice, clears, and reports the outcome in a snack bar. Not a line
/// under the control: the tab is kept alive by an `IndexedStack`, so a
/// state-bound note would go stale.
///
/// Messenger and controller are grabbed before the first await; the screen may
/// be gone by the time both dialogs close.
  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(gardenResetControllerProvider.notifier);
    if (!await confirmGardenReset(context)) return;

    final said = switch (await controller.clear()) {
      ResetOutcome.cleared =>
        'Your garden\'s clear. Your next session plants the first thing in it.',
      ResetOutcome.failed => 'Your garden couldn\'t be cleared just now. '
          'Nothing\'s been removed.',
      // The section already shows the held-back note explaining why.
      ResetOutcome.refused => null,
    };
    if (said == null) return;

    messenger.showSnackBar(
      SnackBar(key: ResetGardenKeys.outcome, content: Text(said)),
    );
  }
}

/// Debug only: preview the milestone glow and shimmer without reaching 500 or
/// 1000 sessions. Writes nothing.
class _MilestonePreviewSection extends ConsumerWidget {
  const _MilestonePreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewing = ref.watch(milestonePreviewProvider);

    return _Section(
      title: 'Milestone effects (debug)',
      children: [
        Wrap(
          key: SettingsKeys.milestonePreview,
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final (milestone, label) in const [
              (null, 'Off'),
              (Milestone.fiveHundred, '500 · willow'),
              (Milestone.oneThousand, '1000 · golden'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: previewing == milestone,
                onSelected: (isSelected) {
                  if (isSelected) {
                    ref.read(milestonePreviewProvider.notifier).show(milestone);
                  }
                },
              ),
          ],
        ),
        const _Note(
          'Shows the garden as though these milestones had been reached: the '
          'enchanted willow in its halo, and at 1000 the golden garden '
          'shimmering. Nothing is saved.',
        ),
      ],
    );
  }
}

/// Debug only: pin a season. Held in memory ([ForcedSeason]), forgotten on the
/// next launch.
class _SeasonSection extends ConsumerWidget {
  const _SeasonSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forced = ref.watch(forcedSeasonProvider);
    final showing = ref.watch(seasonProvider);

    return _Section(
      title: 'Season (debug)',
      children: [
        Wrap(
          key: SettingsKeys.season,
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final season in <Season?>[null, ...Season.values])
              ChoiceChip(
                label: Text(season?.label ?? 'Automatic'),
                selected: forced == season,
                onSelected: (isSelected) {
                  if (isSelected) {
                    ref.read(forcedSeasonProvider.notifier).force(season);
                  }
                },
              ),
          ],
        ),
        _Note(
          'The garden reads the date and shows ${showing.label}. Pinning a '
          'season changes the garden tab and nothing else — not the timer, and '
          'not what a session grows.',
        ),
      ],
    );
  }
}

/// Debug only: pin the garden sky to a time of day. Not saved.
class _TimeOfDaySection extends ConsumerWidget {
  const _TimeOfDaySection();

  static const int _step = 15;

  static String _hhmm(Duration t) {
    final h = t.inHours.toString().padLeft(2, '0');
    final m = (t.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forced = ref.watch(forcedTimeOfDayProvider);
    final season = ref.watch(seasonProvider);
    final now = ref.watch(clockProvider).now().toLocal();
    final showing = forced ?? Duration(hours: now.hour, minutes: now.minute);

    void force(Duration? time) =>
        ref.read(forcedTimeOfDayProvider.notifier).force(time);

    final presets = <(String, Duration?)>[
      ('Follow the clock', null),
      ('Sunrise', Daylight.sunriseIn(season)),
      ('Noon', const Duration(hours: 12)),
      ('Sunset', Daylight.sunsetIn(season)),
      ('Midnight', Duration.zero),
    ];

    return _Section(
      title: 'Time of day (debug)',
      children: [
        Wrap(
          key: SettingsKeys.timeOfDay,
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final (label, time) in presets)
              ChoiceChip(
                label: Text(label),
                selected: forced == time,
                onSelected: (isSelected) {
                  if (isSelected) force(time);
                },
              ),
          ],
        ),
        Slider(
          key: SettingsKeys.timeOfDaySlider,
          value: (showing.inMinutes ~/ _step * _step).toDouble(),
          max: (24 * 60 - _step).toDouble(),
          divisions: 24 * 60 ~/ _step - 1,
          semanticFormatterCallback: (v) => _hhmm(Duration(minutes: v.round())),
          onChanged: (v) => force(Duration(minutes: v.round())),
        ),
        _Note(
          forced == null
              ? 'Following the clock (${_hhmm(showing)}).'
              : 'Sky pinned to ${_hhmm(showing)}. Garden tab only.',
        ),
      ],
    );
  }
}

/// Debug only: shows onboarding again and clears the flag, so a relaunch
/// behaves like a fresh install. Garden and settings are untouched.
class _OnboardingSection extends ConsumerWidget {
  const _OnboardingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: 'Onboarding (debug)',
      children: [
        OutlinedButton(
          key: SettingsKeys.onboardingReset,
          onPressed: ref.read(onboardingProvider.notifier).reset,
          child: const Text('Show onboarding again'),
        ),
        const _Note(
          'Puts the three welcome steps back, from the beginning, as though '
          'the app had just been installed. Your garden, your sessions and '
          'everything else you have chosen are untouched.',
        ),
      ],
    );
  }
}

/// Debug only: the on-device event log.
class _EventLogSection extends StatelessWidget {
  const _EventLogSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Event log (debug)',
      children: [
        OutlinedButton(
          key: SettingsKeys.eventLog,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EventLogScreen()),
          ),
          child: const Text('Show the event log'),
        ),
        const _Note(
          'Every event the app has recorded, newest first. There is no '
          'analytics service behind it — the log is a table in this device\'s '
          'own database, it is capped, and nothing in it is ever sent '
          'anywhere.',
        ),
      ],
    );
  }
}

/// One-time nudge towards the recipe. Dismissal is stored, so it's once ever,
/// not once per launch.
class _QuietModeHint extends StatelessWidget {
  const _QuietModeHint({
    required this.onShowMe,
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onShowMe;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: Radii.paperSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your phone can go quiet for a session',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Set up one Shortcut once, and a single tap starts your session and '
            'turns on Do Not Disturb.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onDismiss, child: const Text('No thanks')),
              const SizedBox(width: Spacing.sm),
              FilledButton(onPressed: onShowMe, child: const Text('Show me')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Applies [edit] to the current settings, read fresh rather than closed over
/// so a stale build value doesn't undo a change made in between. Not awaited;
/// the write reports its own failures.
void _change(WidgetRef ref, GardenSettings Function(GardenSettings) edit) {
  final controller = ref.read(settingsControllerProvider.notifier);
  unawaited(controller.change(edit(ref.read(settingsProvider))));
}

String _minutes(int value) => '$value min';

String _sessions(int value) => '$value sessions';

/// One-tap lengths next to a slider. Picking one moves the slider; moving the
/// slider off it deselects it.
class _PresetChips<T extends Object> extends StatelessWidget {
  const _PresetChips({
    required this.presets,
    required this.describe,
    required this.keyOf,
    required this.selected,
    required this.onSelected,
  });

  final List<T> presets;

  final (String, Duration) Function(T) describe;

  final Key Function(T) keyOf;

  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final preset in presets)
          if (describe(preset) case (final label, final length))
            ChoiceChip(
              key: keyOf(preset),
              label: Text(
                '$label · ${length.inMinutes}',
                // Spell out the dot for screen readers.
                semanticsLabel: '$label, ${length.inMinutes} minutes',
              ),
              selected: preset == selected,
              // Tapping the selected chip doesn't turn it off.
              onSelected: (isSelected) {
                if (isSelected) onSelected(preset);
              },
            ),
      ],
    );
  }
}

/// A labelled slider in whole units. Commits once on release; the readout
/// follows the drag from local state, so a drag isn't sixty writes.
class _SettingSlider extends StatefulWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
    super.key,
  });

  final String label;

/// In this setting's own unit.
  final int value;

  final int min;
  final int max;

  final String Function(int) format;

/// Called once, with the value released on.
  final ValueChanged<int> onChanged;

  @override
  State<_SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<_SettingSlider> {
  /// Finger position during a drag; null otherwise.
  double? _dragging;

  int get _shown => (_dragging ?? widget.value.toDouble()).round();

  @override
  void didUpdateWidget(_SettingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Value changed (this slider committed, or a preset chip set it), so the
    // drag is over.
    if (oldWidget.value != widget.value) _dragging = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wrap, not Row: at large text sizes on a narrow phone the readout
        // drops to its own line instead of overflowing.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            Text(widget.label, style: theme.textTheme.titleMedium),
            Text(
              widget.format(_shown),
              // Tabular digits so the readout doesn't jitter while dragging.
              style: GardenTypography.timerDigitsSmall.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: _shown.toDouble().clamp(
                widget.min.toDouble(),
                widget.max.toDouble(),
              ),
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          // One division per unit so the thumb only rests on whole values.
          divisions: widget.max - widget.min,
          label: widget.format(_shown),
          semanticFormatterCallback: (value) =>
              '${widget.label}, ${widget.format(value.round())}',
          onChanged: (value) => setState(() => _dragging = value),
          onChangeEnd: (value) => widget.onChanged(value.round()),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: Spacing.xs,
            bottom: Spacing.sm,
          ),
          child: Headline(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        PaperCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.md,
              Spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0) const SizedBox(height: Spacing.lg),
                  child,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Small secondary text under a control.
class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: GardenColors.of(context).textSecondary),
    );
  }
}
