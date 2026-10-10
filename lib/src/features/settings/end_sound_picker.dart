import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/spacing.dart';
import '../../feedback/feedback_providers.dart';
import '../../settings/settings_providers.dart';

/// The chips, by name — the handles a test reaches for rather than "the third
/// chip in the Feedback section".
abstract final class EndSoundKeys {
  static Key chip(EndSound sound) => Key('endSound.${sound.name}');
}

/// REQ-031's six end-of-session sounds, in settings.
///
/// **Here rather than on the timer, and that is the opposite of the bed's
/// answer for the opposite reason.** An ambient sound is the one setting whose
/// answer changes while the thing it applies to is happening, so its picker sits
/// beside the countdown. This one is decided at the moment a session *ends*,
/// which is far too late to choose — so there is nothing a control on the timer
/// screen could be doing there but taking up room.
///
/// **Picking one plays it.** A list of names nobody can hear is a list of names:
/// the difference between a singing bowl and a soft bell is the sound, and no
/// amount of labelling substitutes for four seconds of it. So a tap writes the
/// setting *and* asks the player for the sound, which is the only place in the
/// app where anything but a finished session makes one.
///
/// **None is a chip like the other five**, not a switch beside them. It writes
/// like the others and previews like the others, by making no sound — which is
/// exactly what choosing it promises. See `GardenSettings.endSound`.
class EndSoundPicker extends ConsumerWidget {
  const EndSoundPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(settingsProvider).endSound;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'End sound',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final sound in EndSound.values)
              ChoiceChip(
                key: EndSoundKeys.chip(sound),
                label: Text(sound.label),
                selected: sound == chosen,
                // A deselecting tap re-chooses the same sound rather than being
                // ignored, exactly as the ambience chips do: there is nothing to
                // turn the sound *off* to except None, which is a chip of its
                // own, so a tap that did nothing would be a dead control. It
                // also makes tapping the selected chip a way to hear it again,
                // which is what somebody comparing two of them will do.
                onSelected: (_) => _choose(ref, sound),
              ),
          ],
        ),
      ],
    );
  }

  /// Writes the choice, and plays it.
  ///
  /// Neither is awaited, for the reason the settings screen does not await its
  /// own writes: the value is live before this returns, the write reports its
  /// own failures, and the player swallows anything the speaker does. Read
  /// fresh rather than closed over, so a sound picked in the same frame as
  /// another setting changed cannot undo it.
  void _choose(WidgetRef ref, EndSound sound) {
    final controller = ref.read(settingsControllerProvider.notifier);
    unawaited(controller.change(ref.read(settingsProvider).withEndSound(sound)));
    unawaited(ref.read(endSoundPlayerProvider).play(sound));
  }
}
