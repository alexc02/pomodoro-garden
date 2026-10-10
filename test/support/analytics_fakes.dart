import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

/// A log that cannot be written to.
///
/// The failure the port promises to absorb: a write that throws must reach
/// [FlutterError.reportError] and go no further, so the session, the setting or
/// the plant that was being recorded carries on regardless.
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

/// Collects what would otherwise be a reported crash, so a test can assert on
/// it instead of failing on it.
List<FlutterErrorDetails> captureErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}
