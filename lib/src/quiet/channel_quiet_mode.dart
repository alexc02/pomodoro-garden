import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'quiet_mode.dart';

/// [QuietMode] over a method channel answered by Kotlin and Swift. No platform
/// branch here; the difference shows up in what [access] returns.
///
/// With nothing registered (tests, desktop) every call throws
/// [MissingPluginException], which is reported and treated as unavailable.
final class ChannelQuietMode implements QuietMode {
  ChannelQuietMode({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_fromPlatform);
  }

  static const String channelName = 'pip_garden/quiet_mode';

  /// Dart to platform.
  static const String accessMethod = 'access';
  static const String requestAccessMethod = 'requestAccess';
  static const String beginMethod = 'begin';
  static const String endMethod = 'end';

  /// Dart to platform, once: was the app launched by the App Intent? Consumes
  /// the flag so a resume doesn't start a second session.
  static const String takeLaunchRequestMethod = 'takeLaunchRequest';

  /// Platform to Dart, for an intent run while the app is up.
  static const String sessionRequestedMethod = 'sessionRequested';

  /// [begin]'s deadline, as UTC epoch ms.
  static const String untilArgument = 'until';

  final MethodChannel _channel;

  final StreamController<void> _requests = StreamController<void>.broadcast();

  bool _launchRequestTaken = false;

  @override
  Future<QuietModeAccess> access() async {
    final answer = await _try(
      'asking what the phone will let this app silence',
      () => _channel.invokeMethod<String>(accessMethod),
    );

    // Unknown answers count as unavailable.
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
    // Take the launch request on first listen, not in the constructor, so it
    // isn't consumed before anyone is listening.
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

  /// Reports instead of throwing, and returns null on failure.
  Future<T?> _try<T>(String what, Future<T?> Function() action) async {
    try {
      return await action();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription(what),
      ));
      return null;
    }
  }
}
