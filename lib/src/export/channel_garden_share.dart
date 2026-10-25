import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'garden_exporter.dart';
import 'garden_share.dart';

/// [GardenShare] over one method channel, answered by Kotlin on Android and by
/// Swift on iOS.
///
/// **No platform branch in this file**, on the same reasoning `ChannelQuietMode`
/// gives: both native sides answer the same channel with the same two
/// arguments, and the difference between a `UIActivityViewController` and an
/// `Intent.createChooser` stays on the side of the fence that has to care. An
/// `if (Platform.isAndroid)` here would put half of each platform's design in
/// Dart and leave the other half native.
///
/// **The bytes cross the channel, not a path.** The alternative — writing the
/// PNG to a temporary file in Dart and sending its path — would put the app's
/// cache directory, the file's lifetime and Android's `FileProvider` authority
/// into three places instead of one. Sending the image itself leaves the
/// platform to put it where its own share mechanism can read it, which on
/// Android means a directory the provider is configured for and on iOS means
/// anywhere at all. It costs one copy of a few megabytes, once, on a tap the
/// user is already waiting on a progress indicator for.
final class ChannelGardenShare implements GardenShare {
  ChannelGardenShare({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  /// The channel both native implementations register against.
  static const String channelName = 'pip_garden/garden_share';

  /// Dart → platform: here is an image, open the sheet on it.
  static const String shareMethod = 'share';

  /// The PNG itself.
  static const String imageArgument = 'image';

  /// What to call it. A suggestion: the platform is free to rename around a
  /// collision, and iOS largely ignores it in favour of its own.
  static const String filenameArgument = 'filename';

  final MethodChannel _channel;

  @override
  Future<ShareOutcome> share(GardenExport export) async {
    try {
      await _channel.invokeMethod<void>(shareMethod, <String, Object?>{
        // `Uint8List` crosses the standard codec as a typed data buffer rather
        // than as a list of boxed integers, which is the difference between one
        // memcpy and several million allocations.
        imageArgument: export.png,
        filenameArgument: export.filename,
      });
      return ShareOutcome.shared;
    } catch (error, stack) {
      // Reported rather than thrown, and then said out loud by the caller: the
      // user tapped a button, so unlike quiet mode this is not something to
      // swallow. What must not happen is an exception reaching a widget.
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
