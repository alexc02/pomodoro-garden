import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../analytics/analytics_providers.dart';
import '../design/garden_colors.dart';
import '../garden/decor_providers.dart';
import '../garden/garden_atlas.dart';
import '../garden/garden_atlas_recipe.dart';
import '../garden/garden_providers.dart';
import '../garden/plant_providers.dart';
import 'channel_garden_share.dart';
import 'garden_exporter.dart';
import 'garden_share.dart';


/// Overridden in widget tests, both because the real channel has no
/// listener there and so tests can inspect the shared image.
final gardenShareProvider = Provider<GardenShare>(
  (ref) => ChannelGardenShare(),
);

/// Export progress. Separate drawing/handing states so the UI can tell
/// our render apart from the platform opening its sheet.
@immutable
sealed class Exporting {
  const Exporting();
}

final class NotExporting extends Exporting {
  const NotExporting();
}

final class Drawing extends Exporting {
  const Drawing();
}

/// Image is ready; waiting on the platform share sheet.
final class Handing extends Exporting {
  const Handing();
}

/// Kept as state (not thrown) so the screen can show a message.
final class ExportFailed extends Exporting {
  const ExportFailed(this.becauseUnavailable);

  /// True if the platform couldn't share at all, false if rendering failed.
  /// The UI shows a different message for each.
  final bool becauseUnavailable;
}

/// Renders the garden and opens the share sheet. No watermark or paid tier
/// (ADR 0005).
final gardenExportControllerProvider =
    NotifierProvider<GardenExportController, Exporting>(
  GardenExportController.new,
);

class GardenExportController extends Notifier<Exporting> {
  @override
  Exporting build() => const NotExporting();

  /// Takes [colours] from the caller (`export_garden.dart`) since a provider
  /// has no context to read the theme, and the skin only applies inside the
  /// garden subtree.
  Future<void> export({required GardenColors colours}) async {
    // Ignore repeat taps; two concurrent exports could run out of memory.
    if (state is Drawing || state is Handing) return;
    state = const Drawing();

    try {
      final layout = await ref.read(gardenLayoutProvider.future);

      // Bake our own atlas: export can start from settings with no garden on
      // screen, and the view could dispose its atlas mid-render.
      final atlas = GardenAtlas.bake(gardenAtlasRecipe(
        colours: colours,
        registry: ref.read(plantSpriteRegistryProvider),
        decorRegistry: ref.read(decorSpriteRegistryProvider),
      ));

      final GardenExport export;
      try {
        export = await GardenExporter.render(
          layout: layout,
          atlas: atlas,
          sky: colours.skyDay,
        );
      } finally {
        atlas.dispose();
      }

      state = const Handing();
      final outcome = await ref.read(gardenShareProvider).share(export);

      if (outcome == ShareOutcome.unavailable) {
        state = const ExportFailed(true);
        return;
      }

      // Only logged once the sheet is actually up.
      ref.read(analyticsProvider).record(const GardenExported());
      state = const NotExporting();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('exporting the garden as an image'),
      ));
      state = const ExportFailed(false);
    }
  }

  /// Clears a failure once the user has seen it.
  void acknowledge() {
    if (state is ExportFailed) state = const NotExporting();
  }
}
