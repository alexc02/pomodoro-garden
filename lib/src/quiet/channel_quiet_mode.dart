import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'quiet_mode.dart';

/// [QuietMode] over one method channel, answered by Kotlin on Android and by
/// Swift on iOS.
///
/// **There is no platform branch in this file, and that is the ticket's last
/// criterion made structural.** Both native sides answer the same channel, and
/// the difference between them arrives as an answer rather than as an `if`:
/// iOS's [access] is [QuietModeAccess.unavailable], so nothing ever asks it to
/// [begin]. An `if (Platform.isAndroid)` here would put half of each platform's
/// design in Dart and leave the other half native, which is how one requirement
/// becomes two features that have to be kept in step by hand.
///
/// A platform with no implementation registered — a widget test, a desktop
/// build — answers [MissingPluginException] to every call. That is caught like
/// any other failure, and it lands on the same answer iOS gives: this phone
/// cannot do it. Nothing about the running session depends on any of it.
final class ChannelQuietMode implements QuietMode {
  ChannelQuietMode({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_fromPlatform);
  }

  /// The channel both native implementations register against. Named for what
  /// crosses it rather than for either platform's mechanism.
  static const String channelName = 'pomodoro_garden/quiet_mode';

  /// Dart → platform.
  static const String accessMethod = 'access';
  static const String requestAccessMethod = 'requestAccess';
  static const String beginMethod = 'begin';
  static const String endMethod = 'end';

  /// Dart → platform, once at startup: "was the app launched by the App Intent
  /// a Shortcuts automation ran?" Consumes the answer, so a later resume does
  /// not start a second session for a request the app has already acted on.
  static const String takeLaunchRequestMethod = 'takeLaunchRequest';

  /// Platform → Dart, for an intent that runs while the app is already going.
  static const String sessionRequestedMethod = 'sessionRequested';

  /// What [begin] sends its deadline as: milliseconds since the epoch, UTC.
  ///
  /// Absolute, for the reason every instant that crosses to a platform in this
  /// app is: neither a device timezone nor a suspended app can move it, and the
  /// platform is expected to act on it with this app not running.
  static const String untilArgument = 'until';

  final MethodChannel _channel;

  final StreamController<void> _requests = StreamController<void>.broadcast();

  /// Whether the launch request has been asked for. Once, per run of the app.
  bool _launchRequestTaken = false;

  @override
  Future<QuietModeAccess> access() async {
    final answer = await _try(
      'asking what the phone will let this app silence',
      () => _channel.invokeMethod<String>(accessMethod),
    );

    // An unrecognised answer is a platform this build does not understand, and
    // the safe reading of that is the one that offers the user nothing rather
    // than a switch nothing is behind.
    return QuietModeAccess.values.firstWhere(
      (access) => access.name == answer,
      orElse: () => QuietModeAccess.unavailable,
    );
  }

  @override
  Future<void> requestAccess() async {
    await _try(
      'opening the notification policy access settings',
      () => _channel.invokeMethod<void>(requestAccessMethod),
    );
  }

  @override
  Future<void> begin({required DateTime until}) async {
    await _try(
      'silencing the phone for the session',
      () => _channel.invokeMethod<void>(beginMethod, <String, Object?>{
        untilArgument: until.toUtc().millisecondsSinceEpoch,
      }),
    );
  }

  @override
  Future<void> end() async {
    await _try(
      'letting the phone make noise again',
      () => _channel.invokeMethod<void>(endMethod),
    );
  }

  @override
  Stream<void> get sessionRequests {
    // Asked for at the first listen rather than in the constructor, so nothing
    // is consumed before there is anywhere for it to go. An intent that started
    // the app ran before Dart existed; this is the moment it can be delivered.
    if (!_launchRequestTaken) {
      _launchRequestTaken = true;
      unawaited(_deliverLaunchRequest());
    }
    return _requests.stream;
  }

  Future<void> _deliverLaunchRequest() async {
    final requested = await _try(
      'reading the session the app was launched to start',
      () => _channel.invokeMethod<bool>(takeLaunchRequestMethod),
    );
    if ((requested ?? false) && !_requests.isClosed) _requests.add(null);
  }

  Future<void> _fromPlatform(MethodCall call) async {
    if (call.method != sessionRequestedMethod) {
      throw MissingPluginException(
        'Quiet mode was called back with ${call.method}, which nothing in Dart '
        'answers.',
      );
    }
    if (!_requests.isClosed) _requests.add(null);
  }

  /// Runs [action], and reports rather than throws if the platform will not.
  ///
  /// The port promises this on every method. Quiet mode is a courtesy the phone
  /// does the user, never the thing that runs a session: a revoked permission,
  /// an OEM that will not take a zen rule, a build with no implementation
  /// registered — all of them leave the session anchored, recorded and
  /// announced exactly as they found it.
  Future<T?> _try<T>(String what, Future<T?> Function() action) async {
    try {
      return await action();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pomodoro_garden',
        context: ErrorDescription(what),
      ));
      return null;
    }
  }
}
