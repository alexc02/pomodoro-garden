import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'live_session.dart';

/// [LiveSessionSurface] over one method channel, answered by Swift on iOS and
/// by Kotlin on Android.
///
/// **There is no platform branch in this file, and that is the ticket's last
/// criterion made structural.** Both native sides answer the same three
/// methods against the same map, and what they do with it — start an
/// ActivityKit activity, or start a foreground service — is theirs. The
/// alternative, an `if (Platform.isIOS)` here, would put half of each
/// platform's design in Dart and leave the other half native, which is how a
/// surface ends up looking different on the two phones for reasons nobody
/// meant.
///
/// A platform with no implementation registered — a widget test, a desktop
/// build, an integration test host — answers [MissingPluginException] to every
/// call, which is caught and reported like any other failure. Nothing about the
/// running session depends on the answer.
final class ChannelLiveSessionSurface implements LiveSessionSurface {
  ChannelLiveSessionSurface({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_fromPlatform);
  }

  /// The channel both native implementations register against. Named for what
  /// crosses it rather than for either platform's mechanism.
  static const String channelName = 'pip_garden/live_session';

  /// Dart → platform.
  static const String showMethod = 'show';
  static const String hideMethod = 'hide';

  /// Dart → platform, once at startup: "was the app launched by a tap on the
  /// surface?" Consumes the answer, so a later resume does not re-open the
  /// timer for a tap the app has already acted on.
  static const String takeLaunchTapMethod = 'takeLaunchTap';

  /// Platform → Dart, for a tap that arrives while the app is already running.
  static const String openedMethod = 'opened';

  final MethodChannel _channel;

  final StreamController<void> _opened = StreamController<void>.broadcast();

  /// Whether the launch tap has been asked for. Once, per run of the app.
  bool _launchTapTaken = false;

  @override
  Future<void> show(LiveSession session) =>
      _try('showing the live session surface', () async {
        await _channel.invokeMethod<void>(showMethod, <String, Object?>{
          'sessionId': session.sessionId,
          'paused': session.paused,
          // Milliseconds since the epoch, UTC. The one field the platforms
          // count against on their own, and an absolute instant so that neither
          // a device timezone nor a suspended app can move it — the same
          // reasoning that keeps the completion notification in `tz.UTC`.
          'endsAt': session.endsAt.toUtc().millisecondsSinceEpoch,
          'remainingSeconds': session.remaining.inSeconds,
          'progress': session.progress,
          // The stage twice over: the index for a surface that picks a drawing
          // by it, the label for one that writes it out. iOS does both; Android
          // has one small icon and writes the label beside the species.
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
    // Asked for at the first listen rather than in the constructor, so nothing
    // is consumed before there is anywhere for it to go. A tap that launched
    // the app has been waiting on the platform side since before Dart existed;
    // this is the moment it can be delivered.
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

  /// Runs [action], and reports rather than throws if the platform will not.
  ///
  /// The port promises this on every method. A live surface is a window onto a
  /// session, never the thing that runs one: a device that refuses to start an
  /// activity, an OEM that will not take a foreground service, a build with no
  /// implementation registered — all of them leave the session anchored,
  /// recorded and announced exactly as they found it, so none of them is worth
  /// surfacing to somebody trying to focus.
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
