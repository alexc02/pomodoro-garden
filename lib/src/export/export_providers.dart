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

/// REQ-035's export: what it is doing, and the one thing that can start it.

/// How the finished image reaches the platform.
///
/// Overridden in every widget test — the real one calls across a channel
/// nothing answers on the machine running the suite — and the fake is what
/// makes "the image that reached the sheet is the garden" a thing a test can
/// look at.
final gardenShareProvider = Provider<GardenShare>(
  (ref) => ChannelGardenShare(),
);

/// What an export is doing right now.
///
/// A state rather than a `bool busy`, because the two halves take their time
/// for different reasons and only one of them is the app's fault: [Drawing] is
/// a few million pixels being rastered and encoded, and [Handing] is the
/// platform putting a sheet up. A user watching a spinner is entitled to a
/// screen that knows which.
@immutable
sealed class Exporting {
  const Exporting();
}

/// Nothing is being exported, which is almost always.
final class NotExporting extends Exporting {
  const NotExporting();
}

/// The garden is being drawn into an image.
final class Drawing extends Exporting {
  const Drawing();
}

/// The image is made, and the platform is being asked to open its sheet.
final class Handing extends Exporting {
  const Handing();
}

/// It did not work, and the user is owed a sentence about it.
///
/// Held as a state rather than thrown out of the call, because the thing that
/// has to happen is a message on a screen — and the screen is watching this.
final class ExportFailed extends Exporting {
  const ExportFailed(this.becauseUnavailable);

  /// Whether the platform simply had nowhere to send it — as opposed to the
  /// render itself failing. Two different sentences: one is "this device cannot
  /// share", the other is "something went wrong making the picture".
  final bool becauseUnavailable;
}

/// Draws the garden and hands it to the platform. REQ-035.
///
/// **One kind of export, and nothing of the app's in it.** An earlier draft put
/// a watermark in the corner of a free user's image and sold a clean one; the
/// app is free, so every export is the garden and nothing else — see
/// `docs/adr/0021-…`.
final gardenExportControllerProvider =
    NotifierProvider<GardenExportController, Exporting>(
  GardenExportController.new,
);

class GardenExportController extends Notifier<Exporting> {
  @override
  Exporting build() => const NotExporting();

  /// Exports the garden as it is dressed in [colours].
  ///
  /// The colours are passed in rather than read here because there is no
  /// context below a provider to look a theme up through, and because the
  /// caller is the one that knows how the garden is dressed on screen — the
  /// skin is applied over the garden's subtree and nowhere else. See
  /// `export_garden.dart`, which is the only caller and derives them the same
  /// way `SeasonalGarden` does.
  Future<void> export({required GardenColors colours}) async {
    // One at a time. A second tap while the first export is still drawing would
    // bake a second atlas and raster a second few million pixels beside it,
    // which is the one way this feature could actually exhaust a phone.
    if (state is Drawing || state is Handing) return;
    state = const Drawing();

    try {
      final layout = await ref.read(gardenLayoutProvider.future);

      // Baked here and released below rather than borrowed from the garden
      // screen: the export can be started from settings, where there is no
      // garden on screen to have baked one, and a texture the view owns is a
      // texture the view may dispose mid-render.
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

      // Recorded when the sheet is actually up, which is what §7.1 wants to
      // count: a render that failed is not an export, and what the user then
      // does with the sheet is not something this app is told or asks.
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

  /// Puts a failure away, once the user has been told about it.
  void acknowledge() {
    if (state is ExportFailed) state = const NotExporting();
  }
}
