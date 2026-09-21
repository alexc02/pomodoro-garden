import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/spacing.dart';
import '../../feedback/feedback_providers.dart';
import '../../settings/settings_providers.dart';

abstract final class EndSoundKeys {
  static Key chip(EndSound sound) => Key('endSound.${sound.name}');
}

/// End-of-session sound chips. In settings rather than on the timer, since it
/// can't be chosen in the moment the way ambience can.
///
/// Tapping a chip saves it and plays a preview. "None" is just another chip
/// (it previews as silence). See `GardenSettings.endSound`.
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
                // Re-tapping the selected chip plays it again rather than
                // doing nothing; handy when comparing.
                onSelected: (_) => _choose(ref, sound),
              ),
          ],
        ),
      ],
    );
  }

  /// Neither the write nor the preview is awaited; same reasoning as the
  /// settings screen.
  void _choose(WidgetRef ref, EndSound sound) {
    final controller = ref.read(settingsControllerProvider.notifier);
    unawaited(controller.change(ref.read(settingsProvider).withEndSound(sound)));
    unawaited(ref.read(endSoundPlayerProvider).play(sound));
  }
}
