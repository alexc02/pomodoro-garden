import 'package:pip_garden/src/export/garden_exporter.dart';
import 'package:pip_garden/src/export/garden_share.dart';

/// A share sheet that remembers what it was handed instead of opening.
///
/// The seam REQ-035 is actually asserted at: the real one calls across a
/// channel nothing answers on the machine running the suite, and what a test
/// wants to know is what the *image* looked like — whether it carried a
/// watermark, how big it was, that it is a PNG. All of that is in the export
/// this collects.
final class FakeGardenShare implements GardenShare {
  FakeGardenShare({this.outcome = ShareOutcome.shared});

  /// What the platform will say. Settable so a test can be a device with
  /// nowhere to send an image.
  ShareOutcome outcome;

  /// Every export handed over, oldest first.
  final List<GardenExport> shared = [];

  /// The last one, which is what a test that made one export means.
  GardenExport get last => shared.last;

  @override
  Future<ShareOutcome> share(GardenExport export) async {
    shared.add(export);
    return outcome;
  }
}
