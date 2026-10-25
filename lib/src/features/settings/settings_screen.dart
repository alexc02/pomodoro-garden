import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/page_header.dart';
import '../../design/paper_card.dart';
import '../../design/sky_band_backdrop.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
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
import '../garden/export_garden.dart';
import '../garden/theme_picker.dart';
import 'end_sound_picker.dart';
import 'event_log_screen.dart';
import 'reset_garden.dart';

/// The sliders, by name.
///
/// Three controls of the same shape sit on this screen, so "the second slider"
/// is not a thing a test should have to say. These are the handles it uses
/// instead.
abstract final class SettingsKeys {
  static const Key sessionLength = Key('settings.sessionLength');

  /// REQ-006's one-tap session lengths.
  static Key sessionPreset(SessionPreset preset) =>
      Key('settings.sessionPreset.${preset.name}');

  /// REQ-007's one-tap break lengths.
  static Key breakPreset(BreakPreset preset) =>
      Key('settings.breakPreset.${preset.name}');
  static const Key breakLength = Key('settings.breakLength');
  static const Key longBreakAfter = Key('settings.longBreakAfter');
  static const Key haptics = Key('settings.haptics');
  static const Key liveSurface = Key('settings.liveSurface');
  static const Key autoStartBreak = Key('settings.autoStartBreak');
  static const Key autoStartNextSession = Key('settings.autoStartNextSession');

  /// REQ-014's switch, which exists only where the platform can act on it.
  static const Key quietMode = Key('settings.quietMode');

  /// The one-time hint, and the row that outlives it — both only where the
  /// platform cannot. See [_QuietModeSection].
  static const Key quietModeHint = Key('settings.quietModeHint');
  static const Key quietModeRecipe = Key('settings.quietModeRecipe');

  /// What is left where a phone can neither silence itself nor be wired up to.
  static const Key quietModeUnsupported = Key('settings.quietModeUnsupported');

  /// REQ-034's theme picker — see [_GardenSection].
  static const Key gardenTheme = Key('settings.gardenTheme');

  /// REQ-019's season, forced. Debug builds only — see [_SeasonSection].
  static const Key season = Key('settings.season');

  /// REQ-021's two effects, previewed. Debug builds only — see
  /// [_MilestonePreviewSection].
  static const Key milestonePreview = Key('settings.milestonePreview');

  /// REQ-003's onboarding, put back. Debug builds only — see
  /// [_OnboardingSection].
  static const Key onboardingReset = Key('settings.onboardingReset');

  /// §7.1's events, as recorded on this device. Debug builds only — see
  /// [_EventLogSection].
  static const Key eventLog = Key('settings.eventLog');
}

/// Settings: the lengths the timer runs to, and — as later tickets add them —
/// sounds, notifications and quiet mode.
///
/// Every control here reads and writes one [GardenSettings] through
/// `settingsProvider`. A ticket adding a setting adds a field there, a row
/// here, and nothing else.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // No app bar, as the garden, timer and journal have none (PRD v2.3): a
    // header over a band of sky, and each group of settings a card of paper.
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
                // Last, and only in a debug build: it is not a setting, and the
                // list should not open on it.
                if (kDebugMode) ...[
                  const SizedBox(height: Spacing.lg),
                  const _SeasonSection(),
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

/// How long a focus session runs: the three presets, and the custom control
/// that can reach the same lengths and everything between them.
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

/// How long breaks run, how often one of them is a long one, and whether the
/// cycle runs itself.
class _BreaksSection extends ConsumerWidget {
  const _BreaksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return _Section(
      title: 'Breaks',
      children: [
        // REQ-007's presets, beside the slider the way REQ-006's are beside the
        // session's. They set the ordinary break; the long break follows it.
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
        // REQ-032's two halves, and they are two switches rather than one
        // because a great many people want the break handed to them and the
        // next session asked for. Turning both on is what makes the cycle run
        // unattended; the pair is not itself a setting.
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
        // The promise the pair makes, and its one limit. Nothing of this app
        // runs while it is closed — that is what keeps a backgrounded session
        // free — so the cycle picks up where it left off when the app is next
        // awake rather than having run on without it.
        const _Note(
          'With both on, the timer goes from focus to break and back by itself. '
          'Nothing starts while the app is closed; it picks up when you open it '
          'again.',
        ),
      ],
    );
  }
}

/// What a finished session sounds and feels like: REQ-031's end sound and
/// REQ-037's haptics.
///
/// The two belong together because they are one question to the user — how the
/// app answers when something finishes — and they are shaped differently for a
/// reason that is not an inconsistency: the sound is six choices because there
/// are six sounds worth telling apart, and the haptics are one switch because
/// a tap is a tap. **None** is how the sound is turned off, so there is no
/// second switch here.
class _FeedbackSection extends ConsumerWidget {
  const _FeedbackSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return _Section(
      title: 'Feedback',
      children: [
        const EndSoundPicker(),
        // The last sentence is not a hedge. The preview plays on the same
        // audio session the real chime does, which is the one the phone's
        // silent switch mutes — deliberately, so this app cannot chime in a
        // meeting. A note promising "tap one to hear it" full stop would be
        // wrong for exactly the user who had silenced their phone to focus.
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
          // The card is already padded, and the tile would add its own.
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

/// REQ-033's switch: whether a running session is shown outside the app.
///
/// One control, and its words are the same on both platforms even though what
/// it turns on is not — a Live Activity on iPhone, an ongoing notification on
/// Android. The user is being asked whether their phone may show their session
/// while they are not looking at the app, and neither answer to that is about a
/// Dynamic Island.
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
        // Said plainly because it is the thing a user turning this off would
        // reasonably fear, and REQ-033 makes it a promise: the session is
        // anchored to the clock and its end is announced by a notification the
        // system already holds. This switch is about a window onto a session,
        // never about the session.
        const _Note(
          'Turning this off doesn\'t stop a session. It still finishes, and '
          'still lets you know.',
        ),
      ],
    );
  }
}

/// REQ-014's quiet mode, in whichever of its two forms this phone can offer.
///
/// **The section branches on what the platform can do, never on which platform
/// it is.** [QuietModeAccess] is the whole of the difference: where an app can
/// silence a phone there is a switch that silences it, and where none can there
/// is the recipe for the Shortcut that does it instead. The word "Android"
/// appears nowhere in here, and neither does "iPhone" outside the copy that is
/// about a phone the user is holding.
///
/// **No toggle where there is nothing to toggle.** That is the ticket's
/// requirement and it is worth being plain about why: a switch labelled "Quiet
/// mode" that silenced nothing would be the app lying about a feature, and the
/// user would find out at the worst possible moment — a call in the middle of
/// the session they thought they had protected.
class _QuietModeSection extends ConsumerWidget {
  const _QuietModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing until the platform has answered. It is one channel call made at
    // launch, so this is the first frame at most; a section that guessed and
    // corrected itself would show a switch to somebody who cannot have one.
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

  /// The switch, where the phone will act on it.
  List<Widget> _automatic(
    BuildContext context,
    WidgetRef ref, {
    required QuietModeAccess access,
  }) {
    final settings = ref.watch(settingsProvider);
    final granted = access == QuietModeAccess.granted;
    // What the user asked for, and what is actually happening, are two things,
    // and the switch shows the second. A permission revoked in system settings
    // leaves quiet mode doing nothing, and a control still sitting at "on"
    // would be the app's word against the phone's.
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
          'Pomodoro Garden doesn\'t have permission to silence your phone, so '
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

  /// The recipe, where no app can silence the phone and one particular app
  /// pretending otherwise would be the worst answer available.
  List<Widget> _byHand(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(settingsProvider).quietModeHintDismissed;

    return [
      if (!dismissed)
        _QuietModeHint(
          key: SettingsKeys.quietModeHint,
          // Both answers put the nudge away for good, because both are the
          // user having dealt with it. Reading the recipe and declining to are
          // the same thing to a hint whose job was to be noticed once.
          onShowMe: () {
            _change(ref, (s) => s.withQuietModeHintDismissed());
            _showTheRecipe(context);
          },
          onDismiss: () => _change(ref, (s) => s.withQuietModeHintDismissed()),
        ),
      // Outlives the hint, so that putting the nudge away is not the same as
      // losing the instructions.
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

  /// Writes the setting, and — if the phone has not been asked yet — walks the
  /// user to the one place it can be granted.
  ///
  /// The setting is written either way, before anything is granted. A user who
  /// comes back from system settings without granting it has a switch that
  /// shows off and says why; a user who grants it has one that is simply on,
  /// with nothing further to tap.
  void _setQuietMode(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
    required bool granted,
  }) {
    _change(ref, (s) => s.withQuietMode(enabled: enabled));
    if (!enabled || granted) return;

    // Explained *before* they are sent, because where they are going is a
    // system settings list of every app on the phone, with no idea why it
    // opened. There is no runtime dialog for this permission — that is the
    // platform's design, not an omission here.
    unawaited(showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('One thing to switch on'),
        content: const Text(
          'Your phone has to give Pomodoro Garden permission first, and that '
          'happens in system settings.\n\nFind Pomodoro Garden in the list that '
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

  /// The Shortcuts recipe, in full.
  ///
  /// Written out rather than linked to, because a link is a page that can move
  /// and this is four steps. The App Intent named in step 3 is the app's half
  /// of it — see `QuietMode.sessionRequests`.
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
            '3. Add "Start a focus session" — it is under Pomodoro Garden.\n'
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

/// REQ-034's garden theme: the way to the picker, and what is currently on.
///
/// **A row rather than the picker itself.** The three themes need previewing at
/// a size a settings list has no room for — a swatch the width of a chip would
/// sell nothing and would be the one part of this feature the user judges it
/// on. So settings names the theme in force and opens the screen that shows
/// them.
///
/// **Not held back while a session runs.** This is a setting like any other and
/// a user is entitled to change how their garden looks whenever they like.
class _GardenSection extends ConsumerWidget {
  const _GardenSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The same value the picker reads, so the row and the screen behind it
    // cannot disagree.
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
        // REQ-035's second door. Here rather than in a section of its own
        // because an export *is* a thing you do to the garden, and the row
        // above already says which garden it would be a picture of.
        const ExportGardenTile(),
      ],
    );
  }
}

/// REQ-036's reset: the way to a fresh garden, behind two questions.
///
/// **The bottom of the shipping screen, and deliberately.** Everything above it
/// is something to change; this is the one thing here that destroys something,
/// and a destructive action reached past on the way to a slider is one somebody
/// will reach by accident. It is also the only row on this screen whose control
/// disappears — see below — and having that happen at the very bottom is what
/// stops it from moving anything the user was aiming at.
///
/// **Held back while a timer is in flight**, with the shape the rest of this
/// screen uses: the row stays where it is and stops being a door. The ticket
/// allows either refusing or cancelling the session first, and cancelling would
/// be destroying a second thing behind confirmations that were about the first.
/// See [gardenMayBeResetProvider].
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

/// The way to the two confirmations, or the reason there is not one right now.
class _ResetDoor extends ConsumerWidget {
  const _ResetDoor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(gardenMayBeResetProvider)) {
      // A finished session is held back too, but nothing in it is running and
      // there is nothing to cancel, so it gets its own way out.
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

    // Outlined rather than filled, and in the theme's error colour: this is the
    // one control on the screen that takes something away, and it should look
    // like the exit rather than like the thing to do next. The two dialogs are
    // where it commits to a colour — see `confirmGardenReset`.
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

  /// Asks both questions, clears only if both were answered yes, and says what
  /// happened.
  ///
  /// **The outcome is a snack bar rather than a line under the control**,
  /// unlike the restore above it and like the export's failure. The reason is
  /// what happens *after* the message: this tab is kept alive by the shell's
  /// `IndexedStack`, so a note bound to state would still be saying "your
  /// garden is empty" an hour and three sessions later, by which time it is not
  /// true. A snack bar is said once, to the person who just did the thing —
  /// which is also why [GardenResetController.clear] hands its outcome back
  /// rather than publishing it.
  ///
  /// The messenger and the controller are both taken before the first await, on
  /// the same terms `exportGarden` takes its messenger early: two dialogs is a
  /// long time for a screen to still be there, and neither is something to look
  /// up through a dead context. Nothing after the awaits touches [ref] at all.
  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(gardenResetControllerProvider.notifier);
    if (!await confirmGardenReset(context)) return;

    final said = switch (await controller.clear()) {
      ResetOutcome.cleared =>
        'Your garden\'s clear. Your next session plants the first thing in it.',
      ResetOutcome.failed => 'Your garden couldn\'t be cleared just now. '
          'Nothing\'s been removed.',
      // Said by the section rather than here: the row has already gone back to
      // its held-back note, which explains why in more words than a snack bar
      // over a timer has room for.
      ResetOutcome.refused => null,
    };
    if (said == null) return;

    messenger.showSnackBar(
      SnackBar(key: ResetGardenKeys.outcome, content: Text(said)),
    );
  }
}

/// REQ-019's four seasons, on demand.
///
/// **A debug affordance, not a setting.** The whole point of REQ-019 is that
/// the garden follows the world outside without being asked to, so a shipped
/// control that let a user pick December would be undoing the feature. What
/// this exists for is the reviewer: four seasons that otherwise take a year to
/// see, and a crossfade that otherwise happens four times a year at midnight.
/// It is compiled out of release builds by the `kDebugMode` guard at its only
/// call site, and it writes to nothing — [ForcedSeason] is held in memory and
/// forgotten on the next launch.
///
/// "Automatic" is a choice like the other four rather than a way to clear them,
/// because going back to the calendar is the case worth being able to check:
/// the crossfade out of a forced winter is the same crossfade a real March
/// would bring.
/// REQ-021's glow and shimmer, on demand.
///
/// **A debug affordance, not a setting**, on the same terms as
/// [_SeasonSection]: it writes nothing, and it is compiled out of release
/// builds by the `kDebugMode` guard at its only call site. Without it the two
/// effects ticket 36 built could only be seen after 500 and 1000 sessions.
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

/// REQ-003's onboarding, on demand.
///
/// **A debug affordance, not a setting**, on the same terms as
/// [_SeasonSection]: onboarding is seen once per install and there is nothing a
/// user gains by seeing it again, so the section is compiled out of release
/// builds by the `kDebugMode` guard at its only call site. What it exists for is
/// the reviewer and the tester, who would otherwise have to delete the app to
/// look at its first ten seconds twice.
///
/// It writes the flag as well as putting the flow back on screen, so what is
/// being checked is a real first launch rather than a screen borrowed for a
/// moment: relaunching lands on the welcome too, exactly as a fresh install
/// does. `README.md` says so where somebody looking for it would look.
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

/// PRD §7.1's events, as this device has them.
///
/// **A debug affordance, not a setting**, on the same terms as the two sections
/// above it. There is nothing here for a user: the events are not a feature,
/// they are the app's own record of itself, and §7.2's promise is that they stay
/// on the device — which is a promise best kept by a screen that can show
/// somebody they have. The section is compiled out of release builds by the
/// `kDebugMode` guard at its only call site.
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

/// The one-time nudge towards the recipe.
///
/// Dismissible and dismissed for good — the flag is stored, so this is once
/// ever rather than once a launch. A hint that came back would be the nagging
/// PRD §2 is written against, and a hint that never appeared at all would leave
/// the whole feature to a user who happened to scroll to the bottom of
/// settings.
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

/// Applies [edit] to the settings as they stand *now*.
///
/// Read fresh rather than closed over: the value a control was built from is
/// one frame old, and a control that wrote back what it was built with would
/// undo whatever changed in between.
///
/// Not awaited: the change is live in the app before [SettingsController.change]
/// returns, and the write that follows reports its own failures. There is
/// nothing for a control to do while it finishes, and nothing to hold the
/// screen still for.
void _change(WidgetRef ref, GardenSettings Function(GardenSettings) edit) {
  final controller = ref.read(settingsControllerProvider.notifier);
  unawaited(controller.change(edit(ref.read(settingsProvider))));
}

String _minutes(int value) => '$value min';

String _sessions(int value) => '$value sessions';

/// One-tap lengths alongside a slider: REQ-006's for the session, REQ-007's
/// for the break. Tapping one moves the slider, and moving the slider off one
/// deselects it, because both are the same setting.
class _PresetChips<T extends Object> extends StatelessWidget {
  const _PresetChips({
    required this.presets,
    required this.describe,
    required this.keyOf,
    required this.selected,
    required this.onSelected,
  });

  final List<T> presets;

  /// A preset's name and the length it sets.
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
                // The dot is a visual separator, not a word. Spelled out for
                // anyone hearing the chip rather than reading it.
                semanticsLabel: '$label, ${length.inMinutes} minutes',
              ),
              selected: preset == selected,
              // Tapping the chip that is already on is not a way to turn the
              // length off, so a deselecting tap does nothing.
              onSelected: (isSelected) {
                if (isSelected) onSelected(preset);
              },
            ),
      ],
    );
  }
}

/// One setting, as a labelled value and the slider that moves it.
///
/// Whole units only — minutes, or sessions — because that is the granularity
/// REQ-030 offers and a slider that could land between two of them would show a
/// value the user did not choose.
///
/// The slider is committed on release, not on every pixel of the drag: the
/// label follows the finger from local state, and one change is written when
/// the finger lifts. A write per frame of a drag would be sixty transactions to
/// store the one value the user meant.
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

  /// The stored value, in this setting's own unit.
  final int value;

  final int min;
  final int max;

  /// Renders a value with its unit, for the readout beside the label.
  final String Function(int) format;

  /// Called once, with the value the user released on.
  final ValueChanged<int> onChanged;

  @override
  State<_SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<_SettingSlider> {
  /// Where the finger is, while it is down. Null when the slider is showing the
  /// stored value.
  double? _dragging;

  int get _shown => (_dragging ?? widget.value.toDouble()).round();

  @override
  void didUpdateWidget(_SettingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The stored value moved — either because this slider committed, or because
    // a preset chip changed the same setting from the other control. Either
    // way the drag is over and the slider follows the value again.
    if (oldWidget.value != widget.value) _dragging = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A Wrap rather than a Row: at a large text size on a narrow phone the
        // label and its readout do not both fit on one line, and a Row would
        // answer that by overflowing. This puts the readout on its own line
        // instead, and is a plain label-left-value-right row whenever there is
        // room — which is every ordinary text size.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            Text(widget.label, style: theme.textTheme.titleMedium),
            Text(
              widget.format(_shown),
              // Tabular, so the readout does not shift under the finger as the
              // digits change.
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
          // One division per whole unit, so the thumb can only rest on a value
          // the readout can show exactly.
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

/// A titled group of settings on a card.
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
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
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

/// A quiet line under a control, explaining what it does — not a warning, and
/// not styled like one.
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
