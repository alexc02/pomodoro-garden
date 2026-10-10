import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/garden_colors.dart';
import '../../export/export_providers.dart';
import '../../garden/theme_providers.dart';

/// REQ-035's export, and the two places the ticket asks for it.
///
/// **One handler, two doors.** The garden's own app bar is where somebody
/// looking at their garden wants it, and settings is where somebody who
/// remembered the feature later goes to look for it. Both call [exportGarden],
/// so there is no second opinion about what an export is or who gets a
/// watermark — the only difference between them is the shape of the control.

/// What the tests reach for.
abstract final class ExportKeys {
  /// The action in the garden's app bar.
  static const Key action = Key('export.action');

  /// The row in settings.
  static const Key setting = Key('export.setting');

  /// The spinner either of them turns into while an export is being made.
  static const Key progress = Key('export.progress');

  /// The message shown when it could not be done.
  static const Key failure = Key('export.failure');
}

/// Draws the garden as it is dressed right now and hands it to the platform.
///
/// **The colours are derived here, once, and the way `SeasonalGarden` derives
/// them**: the app's own garden colours with the current skin applied over
/// them. That is what makes an export from settings — where there is no garden
/// on screen and no skin over the subtree — the same picture as an export from
/// the garden tab. Applying a skin to colours that already carry one is
/// harmless, because a skin sets every colour it touches rather than blending
/// into it.
///
/// Reading the skin rather than watching a crossfade is deliberate: a user who
/// taps export a second into a change of season gets the season the garden is
/// arriving at, not the halfway blend it happens to be showing. The blend is a
/// transition, and nobody wants to keep a picture of one.
Future<void> exportGarden(BuildContext context, WidgetRef ref) async {
  final colours = ref.read(gardenSkinProvider).applyTo(GardenColors.of(context));
  // Taken before the await: the control that started this can be gone by the
  // time it finishes — the app bar action is on a tab the user may leave — and
  // a messenger is not something to look up through a dead context.
  final messenger = ScaffoldMessenger.of(context);

  await ref.read(gardenExportControllerProvider.notifier).export(
        colours: colours,
      );

  final outcome = ref.read(gardenExportControllerProvider);
  if (outcome is! ExportFailed) return;

  // A message rather than silence, because the user tapped a button. Said as a
  // snack bar and not as a line under the control, which is the app's usual
  // way, for one reason: this control exists in two places and one of them is
  // an app bar over a full-bleed garden with nowhere to put a sentence. A
  // failure that was explained in settings and swallowed on the garden tab
  // would be the worse inconsistency.
  messenger.showSnackBar(SnackBar(
    key: ExportKeys.failure,
    content: Text(
      outcome.becauseUnavailable
          ? 'This device had nowhere to send the image.'
          : 'Your garden could not be turned into an image just now.',
    ),
  ));
  ref.read(gardenExportControllerProvider.notifier).acknowledge();
}

/// Whether an export is being made right now — what both controls below spin
/// on.
bool _busy(Exporting state) => state is Drawing || state is Handing;

/// What a control says it is doing, for a reader that cannot see the spinner.
///
/// The two halves are named apart because they take their time for different
/// reasons, and a user waiting is owed the honest one: drawing is this app, and
/// waiting on a sheet is the phone.
String _label(Exporting state) => switch (state) {
      Drawing() => 'Drawing your garden',
      Handing() => 'Opening the share sheet',
      NotExporting() || ExportFailed() => 'Export your garden as an image',
    };

/// REQ-035 from the garden itself: the share action in the app bar.
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
          // Sized and padded to the metrics of the icon button it stands in
          // for, so the app bar does not jump as the export starts.
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

/// REQ-035 from settings: the same export, as a row.
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
      title: const Text('Export your garden'),
      // Said out loud here and not on the garden's app bar, because this is the
      // door with room for a sentence.
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
