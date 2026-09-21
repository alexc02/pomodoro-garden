import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/spacing.dart';
import '../../settings/settings_providers.dart';

abstract final class AmbienceKeys {
  static Key chip(AmbientSound sound) => Key('ambience.${sound.name}');
}

/// Ambient sound chips, on the timer screen so the sound can be changed
/// mid-session. Writes to `GardenSettings`, so the choice is also the default
/// for the next session. `AmbienceKeeper` does the playing.
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
            // Unlike the preset chips, re-tapping the selected chip isn't
            // ignored; a dead control would be the only one on the screen.
            onSelected: (_) => _choose(ref, sound),
          ),
      ],
    );
  }

  /// Not awaited; read fresh, same as the settings screen.
  void _choose(WidgetRef ref, AmbientSound sound) {
    final controller = ref.read(settingsControllerProvider.notifier);
    unawaited(
      controller.change(ref.read(settingsProvider).withAmbientSound(sound)),
    );
  }
}

/// Stock Material icons; these aren't plant art, so the sprite-only rule
/// (`test/garden/sprites_are_the_only_art_test.dart`) doesn't apply.
IconData _iconFor(AmbientSound sound) => switch (sound) {
      AmbientSound.silence => Icons.volume_off_outlined,
      AmbientSound.rain => Icons.water_drop_outlined,
      AmbientSound.forest => Icons.forest_outlined,
      AmbientSound.ocean => Icons.waves_outlined,
      AmbientSound.cafe => Icons.local_cafe_outlined,
      AmbientSound.whiteNoise => Icons.graphic_eq_outlined,
    };
