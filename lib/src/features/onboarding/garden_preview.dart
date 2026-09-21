import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';
import '../garden/garden_view.dart';

/// A sample garden for the welcome step, since a new user's own is empty. Same
/// layout rules, painter and sprites as the real one.
///
/// Wrapped in [IgnorePointer] (these plants have no sessions, so no cards) and
/// never stored.
class GardenPreview extends StatelessWidget {
  const GardenPreview({super.key});

  /// Short enough to keep the copy and buttons on screen at large text sizes.
  static const double height = 200;

  /// 18 plants in 20 plots. 24 sessions unlocks exactly 20, so the layout
  /// follows the normal unlock rule.
  static final GardenLayout layout = GardenLayout.of(
    plants: _plants(),
    completedSessions: 24,
  );

  /// Hand-picked for looks: small plants near the middle, trees on the outer
  /// plots where they have room.
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

  /// Indices in planting order left as bare soil.
  static const Set<int> _bare = {5, 12};

  static List<Plant> _plants() {
    // Plants need a date; nothing shows it.
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
        // Sky around the garden, as on the garden tab.
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
