import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'garden_exporter.dart';
import 'garden_share.dart';

/// [GardenShare] over a method channel (Kotlin on Android, Swift on iOS).
///
/// Sends the PNG bytes rather than a file path, so each platform decides
/// where to put the file (Android needs a `FileProvider` directory).
final class ChannelGardenShare implements GardenShare {
  ChannelGardenShare({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'pip_garden/garden_share';

  static const String shareMethod = 'share';

  static const String imageArgument = 'image';

  /// Only a suggestion; iOS mostly ignores it.
  static const String filenameArgument = 'filename';

  final MethodChannel _channel;

  @override
  Future<ShareOutcome> share(GardenExport export) async {
    try {
      await _channel.invokeMethod<void>(shareMethod, <String, Object?>{
        // Uint8List goes over the codec as one buffer, not boxed ints.
        imageArgument: export.png,
        filenameArgument: export.filename,
      });
      return ShareOutcome.shared;
    } catch (error, stack) {
      // Report and return unavailable; the caller shows a message. Never let it
      // reach a widget.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('opening the share sheet on a garden export'),
      ));
      return ShareOutcome.unavailable;
    }
  }
}
