import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/spacing.dart';
import '../../settings/settings_providers.dart';

/// The chips, by name — the handles a test reaches for rather than "the fourth
/// chip on the timer screen".
abstract final class AmbienceKeys {
  static Key chip(AmbientSound sound) => Key('ambience.${sound.name}');
}

/// REQ-012's six beds, on the screen the session is running on.
///
/// **Here rather than in settings, and that is the ticket's requirement.** A
/// bed is the one setting whose answer changes while the thing it applies to is
/// happening: the user finds the café too busy eleven minutes in, and the fix
/// has to be one tap away from the countdown rather than two screens away. The
/// value still lives in `GardenSettings` like every other setting, so the bed
/// they land on is the one their next session starts with — REQ-012's "persists
/// as the default" is not a second piece of state, it is where this control
/// writes.
///
/// **Nothing here touches a player.** Picking a bed writes the setting;
/// `AmbienceKeeper` is what notices and plays it. That is what keeps "the
/// session ended while the picker was open" from being a case anybody has to
/// think about — there is one thing driving the audio, and it is watching the
/// session as well as the setting.
///
/// **All six are offered.** An earlier draft marked three of them premium; the
/// app is free, so the chips are `AmbientSound.values` and there is no line
/// under them explaining what a sparkle meant. See `docs/adr/0021-…`.
class AmbiencePicker extends ConsumerWidget {
  const AmbiencePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(settingsProvider).ambientSound;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final sound in AmbientSound.values)
          ChoiceChip(
            key: AmbienceKeys.chip(sound),
            avatar: Icon(_iconFor(sound), size: IconSizes.inline),
            label: Text(sound.label),
            selected: sound == chosen,
            // Unlike the preset chips, a deselecting tap is not ignored — it
            // re-chooses the same bed. There is nothing to turn a bed *off* to
            // except Silence, which is a chip of its own, so a tap that did
            // nothing would be the only dead control on the screen.
            onSelected: (_) => _choose(ref, sound),
          ),
      ],
    );
  }

  /// Writes the choice, and nothing else.
  ///
  /// Not awaited, for the reason the settings screen does not await its own:
  /// the value is live before this returns and the write reports its own
  /// failures. Read fresh rather than closed over, so a bed picked in the same
  /// frame as another setting changed cannot undo it.
  void _choose(WidgetRef ref, AmbientSound sound) {
    final controller = ref.read(settingsControllerProvider.notifier);
    unawaited(
      controller.change(ref.read(settingsProvider).withAmbientSound(sound)),
    );
  }
}



/// A picture for each bed. Not plant art — see
/// `test/garden/sprites_are_the_only_art_test.dart` for the rule these are
/// outside of — and not an asset either: six icons the framework already ships
/// are the right weight for a control this size.
IconData _iconFor(AmbientSound sound) => switch (sound) {
      AmbientSound.silence => Icons.volume_off_outlined,
      AmbientSound.rain => Icons.water_drop_outlined,
      AmbientSound.forest => Icons.forest_outlined,
      AmbientSound.ocean => Icons.waves_outlined,
      AmbientSound.cafe => Icons.local_cafe_outlined,
      AmbientSound.whiteNoise => Icons.graphic_eq_outlined,
    };
