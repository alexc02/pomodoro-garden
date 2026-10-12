import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'live_session.dart';

/// [LiveSessionSurface] over a method channel. iOS (ActivityKit) and Android
/// (foreground service) answer the same methods with the same map, so there's
/// no platform branch here.
///
/// With nothing registered (tests, desktop) every call throws
/// [MissingPluginException], which gets reported and ignored.
final class ChannelLiveSessionSurface implements LiveSessionSurface {
  ChannelLiveSessionSurface({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_fromPlatform);
  }

  static const String channelName = 'pip_garden/live_session';

  /// Dart to platform.
  static const String showMethod = 'show';
  static const String hideMethod = 'hide';

  /// Dart to platform, once: was the app launched by a tap on the surface?
  /// Consumes the flag so a later resume doesn't act on it again.
  static const String takeLaunchTapMethod = 'takeLaunchTap';

  /// Platform to Dart, for a tap while the app is running.
  static const String openedMethod = 'opened';

  final MethodChannel _channel;

  final StreamController<void> _opened = StreamController<void>.broadcast();

  bool _launchTapTaken = false;

  @override
  Future<void> show(LiveSession session) =>
      _try('showing the live session surface', () async {
        await _channel.invokeMethod<void>(showMethod, <String, Object?>{
          'sessionId': session.sessionId,
          'paused': session.paused,
          // UTC epoch ms. The platforms count down to this themselves.
          'endsAt': session.endsAt.toUtc().millisecondsSinceEpoch,
          'remainingSeconds': session.remaining.inSeconds,
          'progress': session.progress,
          // Index picks the drawing (iOS); label is shown as text (both).
          'stageIndex': session.growing.stage.index,
          'stageLabel': session.growing.stage.label,
          'speciesLabel': session.growing.species.label,
        });
      });

  @override
  Future<void> hide() => _try('hiding the live session surface', () async {
        await _channel.invokeMethod<void>(hideMethod);
      });

  @override
  Stream<void> get opened {
    // Take the launch tap on first listen, not in the constructor, so it
    // isn't consumed before anyone is listening.
    if (!_launchTapTaken) {
      _launchTapTaken = true;
      unawaited(_deliverLaunchTap());
    }
    return _opened.stream;
  }

  Future<void> _deliverLaunchTap() =>
      _try('reading the launch tap on the live session surface', () async {
        final tapped =
            await _channel.invokeMethod<bool>(takeLaunchTapMethod) ?? false;
        if (tapped && !_opened.isClosed) _opened.add(null);
      });

  Future<void> _fromPlatform(MethodCall call) async {
    if (call.method != openedMethod) {
      throw MissingPluginException(
        'The live session surface was called back with ${call.method}, which '
        'nothing in Dart answers.',
      );
    }
    if (!_opened.isClosed) _opened.add(null);
  }

  /// Reports instead of throwing. The surface is display-only, so a failure
  /// never affects the session.
  Future<void> _try(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription(what),
      ));
    }
  }
}
