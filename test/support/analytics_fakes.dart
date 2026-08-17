import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

/// A log whose writes always throw. The app should report the error and carry
/// on.
final class UnwritableEventLog implements AnalyticsEventLog {
  @override
  Future<void> append(AnalyticsEvent event, {required DateTime at}) async {
    throw StateError('the log is not there');
  }

  @override
  Future<List<LoggedEvent>> recent({
    int limit = AnalyticsEventLog.maximumEvents,
  }) async =>
      const [];

  @override
  Future<DateTime?> lastRecordedAt(AnalyticsEventName name) async => null;
}

/// Captures reported Flutter errors so a test can assert on them.
List<FlutterErrorDetails> captureErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}
