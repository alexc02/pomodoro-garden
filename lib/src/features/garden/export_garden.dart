import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/garden_colors.dart';
import '../../export/export_providers.dart';
import '../../garden/theme_providers.dart';

abstract final class ExportKeys {
  /// Garden app bar action.
  static const Key action = Key('export.action');

  /// Settings row.
  static const Key setting = Key('export.setting');

  /// Spinner shown by either control while exporting.
  static const Key progress = Key('export.progress');

  static const Key failure = Key('export.failure');
}

/// Renders the garden in its current skin and hands it to the share sheet.
/// Used by both the app bar action and the settings row.
///
/// Colours are derived the same way `SeasonalGarden` does it, so an export
/// from settings (no skinned subtree) matches the garden tab. Uses the target
/// skin, not a mid-crossfade blend.
Future<void> exportGarden(BuildContext context, WidgetRef ref) async {
  final colours = ref.read(gardenSkinProvider).applyTo(GardenColors.of(context));
  // Grab before the await; the app bar action's tab may be gone by then.
  final messenger = ScaffoldMessenger.of(context);

  await ref.read(gardenExportControllerProvider.notifier).export(
        colours: colours,
      );

  final outcome = ref.read(gardenExportControllerProvider);
  if (outcome is! ExportFailed) return;

  // Snack bar rather than an inline note, since the app bar version has
  // nowhere to put one.
  messenger.showSnackBar(SnackBar(
    key: ExportKeys.failure,
    content: Text(
      outcome.becauseUnavailable
          ? 'This phone has nowhere to send the picture.'
          : 'Couldn\'t make a picture of your garden just now. Try again in a '
              'moment.',
    ),
  ));
  ref.read(gardenExportControllerProvider.notifier).acknowledge();
}

bool _busy(Exporting state) => state is Drawing || state is Handing;

/// Spinner label for screen readers. Drawing is us; handing off is waiting on
/// the phone's share sheet.
String _label(Exporting state) => switch (state) {
      Drawing() => 'Drawing your garden',
      Handing() => 'Opening the share sheet',
      NotExporting() || ExportFailed() => 'Share a picture of your garden',
    };

/// Share action in the garden's app bar.
class ExportGardenAction extends ConsumerWidget {
  const ExportGardenAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gardenExportControllerProvider);

    if (_busy(state)) {
      return Semantics(
        label: _label(state),
        liveRegion: true,
        child: const Padding(
          // Same size as the icon button so the app bar doesn't jump.
          padding: EdgeInsets.all(16),
          child: SizedBox(
            key: ExportKeys.progress,
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return IconButton(
      key: ExportKeys.action,
      icon: const Icon(Icons.ios_share),
      tooltip: _label(state),
      onPressed: () => unawaited(exportGarden(context, ref)),
    );
  }
}

/// The same export as a settings row.
class ExportGardenTile extends ConsumerWidget {
  const ExportGardenTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gardenExportControllerProvider);
    final busy = _busy(state);

    return ListTile(
      key: ExportKeys.setting,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.ios_share),
      title: const Text('Share your garden'),
      subtitle: const Text('A picture of the whole garden, at full size.'),
      trailing: busy
          ? const SizedBox(
              key: ExportKeys.progress,
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      enabled: !busy,
      onTap: busy ? null : () => unawaited(exportGarden(context, ref)),
    );
  }
}
