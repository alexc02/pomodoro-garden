import 'package:pip_garden/src/export/garden_exporter.dart';
import 'package:pip_garden/src/export/garden_share.dart';

/// A share sheet that keeps the exports it's handed instead of opening.
final class FakeGardenShare implements GardenShare {
  FakeGardenShare({this.outcome = ShareOutcome.shared});

  /// Set to simulate a device with nowhere to send an image.
  ShareOutcome outcome;

  /// Every export handed over, oldest first.
  final List<GardenExport> shared = [];

  GardenExport get last => shared.last;

  @override
  Future<ShareOutcome> share(GardenExport export) async {
    shared.add(export);
    return outcome;
  }
}
