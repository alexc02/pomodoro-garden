import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../garden/garden_view.dart';

/// A garden that has been kept, shown to somebody whose own is bare soil.
///
/// The one piece of onboarding that is not literally the app: a first-run user
/// has nothing planted, and a welcome screen showing them their real garden
/// would be showing them an empty field and calling it the reward. So this is a
/// garden of eighteen plants — every plant type, laid out by the same placement
/// rule and drawn by the same painter over the same sprites as the real one.
///
/// **Not interactive, and not stored.** Wrapped in an [IgnorePointer] so it is
/// a picture rather than a toy: the plants in it belong to no session, and a
/// card opened on one would be the app inventing an afternoon the user never
/// spent. Nothing here touches the database, so the garden they open a minute
/// later is empty, as it should be.
class GardenPreview extends StatelessWidget {
  const GardenPreview({super.key});

  /// How tall the preview stands. Enough for a garden to have depth in, and
  /// short enough to leave the welcome's words and its buttons on screen at a
  /// large text size.
  static const double height = 200;

  /// The garden being previewed, built once for the run of the app.
  ///
  /// Eighteen plants in twenty plots: full enough to look like somewhere
  /// somebody has been working, with the two bare plots that say there is room
  /// for tomorrow's. The count of sessions is the one that unlocks exactly
  /// those twenty, so the layout obeys REQ-018 rather than sidestepping it.
  static final GardenLayout layout = GardenLayout.of(
    plants: _plants(),
    completedSessions: 24,
  );

  /// The species the preview is planted with, in the order they are laid out —
  /// wildflowers and herbs first, near the middle, with the trees reaching the
  /// outer plots where their canopies have room.
  ///
  /// Written out rather than chosen from a session id, because there is no
  /// session: this is a picture of a garden, and what it is arranged for is how
  /// it looks.
  static const List<PlantSpecies> _planting = [
    PlantSpecies.poppy,
    PlantSpecies.basil,
    PlantSpecies.tulip,
    PlantSpecies.cornflower,
    PlantSpecies.mint,
    PlantSpecies.daisy,
    PlantSpecies.lavender,
    PlantSpecies.buttercup,
    PlantSpecies.sunflower,
    PlantSpecies.rosemary,
    PlantSpecies.hydrangea,
    PlantSpecies.cherryBlossom,
    PlantSpecies.boxwood,
    PlantSpecies.poppy,
    PlantSpecies.maple,
    PlantSpecies.oak,
    PlantSpecies.willow,
    PlantSpecies.pine,
  ];

  /// The two plots left bare, as places in the planting order.
  static const Set<int> _bare = {5, 12};

  static List<Plant> _plants() {
    // A date, because a plant has one. Nothing in the preview shows it — the
    // picture is the whole of what this garden is for.
    final planted = DateTime.utc(2026);
    final plots = GardenPlots.inPlacementOrder.iterator;
    final plants = <Plant>[];

    for (var index = 0; index < _planting.length + _bare.length; index++) {
      plots.moveNext();
      if (_bare.contains(index)) continue;

      final species = _planting[plants.length];
      plants.add(Plant(
        id: 'preview-$index',
        sessionId: null,
        type: species.type,
        species: species,
        stage: GrowthStage.mature,
        plantedAt: planted,
        sessionDuration: species.type.shortestSession,
        plot: plots.current,
      ));
    }

    return plants;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Radii.mdAll,
      child: ColoredBox(
        // The sky behind it, the same way the garden tab paints one: the
        // preview is smaller than the garden it holds, and the space around a
        // garden is sky rather than the page.
        color: GardenColors.of(context).skyDay,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: IgnorePointer(child: GardenView(layout: layout)),
        ),
      ),
    );
  }
}
